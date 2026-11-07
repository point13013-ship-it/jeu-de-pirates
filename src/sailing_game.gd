extends Control
## Banc d'essai jouable de la navigation façon Sea of Thieves : on marche librement sur le pont
## et dans la cabine, on prend la barre, on hisse les voiles, on jette l'ancre, on charge et tire
## les canons. Rendu : 3D basse résolution + filtre pixel art (palette du port).
##
## Touches : ZQSD / flèches = marcher (ou gouverner à la barre), E = agir, A/D de la barre = bâbord/tribord,
## R = action secondaire (affaler les voiles).
## Arguments de test (après « -- ») : --ship= --yaw= --player=x,y --walkto=x,y --sail=n --rudder=v
## --anchor=1 --helm=1 --fire=1 --shot=chemin --shot-after-secs= --quit-after-secs= --log=1

const PIXELS_PER_METER := 24.0
const VIEW_SIZE := Vector2i(640, 360)
const ELEVATION_DEG := 40.0
const SEA_Y := -1.45
const WALK_SPEED := 3.6
const INTERACT_RANGE := 1.5
const STATS_PATH := "res://data/ship_stats.json"

enum Mode { WALK, HELM }
enum Loc { SHIP, LAND, CLIMB, NEST }   ## où est le pirate : sur le pont, à terre, sur une échelle, dans le nid de pie
const JUMP_SPEED := 5.0                ## m/s
const GRAVITY := 15.0                  ## m/s²
const CLIMB_SPEED := 2.6               ## m/s le long du mât
const NEST_RADIUS := Vector2(0.38, 0.54)  ## unités du modèle : distance mini / maxi au mât dans le nid
const LADDER_REACH := 3.2              ## m : distance maxi entre l'échelle de coque et le quai

var _args: Dictionary = {}
var _ship: ShipModel
var _sim := ShipSim.new()
var _world: Node3D
var _cam: Camera3D
var _sea: MeshInstance3D
var _sprite: PirateSprite
var _my_look: Dictionary = {}       ## mon apparence (éditeur de pirate)
var _remote_looks: Dictionary = {}  ## id du pair -> apparence reçue
var _prev_ppos := Vector2.INF
var _editor: CharacterEditor
var _loc := Loc.SHIP
var _land := Land.new()
var _lpos := Vector2.ZERO           ## position à terre (monde, x/z)
var _pz := 0.0                      ## hauteur au-dessus du sol ou du pont (saut, échelle, nid)
var _vz := 0.0
var _jump_wind := 0.0               ## s restantes d'accroupissement avant le saut
var _land_t := 0.0                  ## s restantes de réception après un saut
var _climb: Dictionary = {}         ## échelle en cours : {kind: mast|hull, t, ...}
var _notice := ""
var _notice_t := 0.0
var _prev_loc := Loc.SHIP
var _prev_lpos := Vector2.ZERO
var _prev_land_climb := false
var _ball_icon: MeshInstance3D
var _ppos := Vector2.ZERO
var _mode := Mode.WALK
var _carrying := false
var _interactables: Array = []
var _cannon_loaded: Array = []
var _cannon_icons: Array = []
var _projectiles: Array = []
var _cam_focus := Vector3.ZERO
var _hud: Label
var _prompt: Label
var _time := 0.0
var _walkto := Vector2.INF
var _log_timer := 0.0
var _container: SubViewportContainer
var _viewport: SubViewport
var _post_vp: SubViewport
var _post_rect: TextureRect
var _post_mat: ShaderMaterial
var _palette_version := -1
var _factor := 2
var _water_mat: ShaderMaterial
var _waves: Array[Vector4] = []
var _sea_cfg: Dictionary = {}
var _blob: MeshInstance3D
var _sun: DirectionalLight3D
var _frames_left := 0
var _world_fixed: Node3D
var _world_origin := Vector3.ZERO  ## position monde (calée) du bateau : le monde défile sous lui
var _sea_t := 0.0
var _cam_offset := Vector3.ZERO
var _net: SailingNet
var _remotes: Dictionary = {}       ## id du pair -> {sprite, blob, ball, pos, target}
var _helm_owner := 0                ## id du joueur à la barre (0 = personne)
var _menu: Node
var _main_menu: MainMenu
var _status_label: Label
var _time_offset := 0.0             ## client : décalage pour suivre le temps de la houle de l'hôte
var _net_target: Dictionary = {}    ## client : dernier état du bateau reçu de l'hôte
var _rudder_sent := 0.0
var _port: Node3D
var _port_meta: Dictionary = {}


const SEA_PATH := "res://data/sea.json"
const SEA_MESH_SIZE := 90.0       ## m : la surface suit la caméra
const SEA_MESH_STEP := 0.25       ## m entre deux sommets de la surface


func _ready() -> void:
	_args = _parse_args()
	# Synchronisation verticale : une image par rafraîchissement de l'écran. Sans elle, le jeu tournait
	# à ~1 450 images/s et l'écran affichait des morceaux de plusieurs images à la fois (déchirures
	# horizontales qui font « vibrer » tout ce qui défile).
	if not _args.has("no-vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		# certains pilotes (réglage NVIDIA « synchronisation verticale : désactivée ») ignorent la demande :
		# on limite alors nous-mêmes à la fréquence de l'écran
		var hz := DisplayServer.screen_get_refresh_rate()
		Engine.max_fps = int(roundf(hz)) if hz > 0.0 else 60
	if _args.has("log"):
		print("[affichage] pilote=%s vsync=%d écran=%.0f Hz" % [RenderingServer.get_current_rendering_driver_name(), DisplayServer.window_get_vsync_mode(), DisplayServer.screen_get_refresh_rate()])
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_view()
	_build_hud()
	_net = SailingNet.new()
	_net.name = "Net"
	_net.game = self
	add_child(_net)
	_net.status.connect(_set_status)
	_net.welcomed.connect(_setup_ship)
	var ship_name := str(_args.get("ship", "brigantin"))
	if _args.has("host"):
		_start_host(ship_name)
	elif _args.has("join"):
		_start_join(str(_args["join"]))
	elif _args.has("ship") or _args.has("solo"):
		_setup_ship(ship_name)
	else:
		_build_menu()
		if _args.has("editor"):
			_open_editor()
		if _args.has("shot"):   # test : capture d'écran du menu (ou de l'éditeur), puis on quitte
			get_tree().create_timer(float(_args.get("shot-after-secs", "3"))).timeout.connect(func() -> void:
				get_viewport().get_texture().get_image().save_png(str(_args["shot"]))
				get_tree().quit())


## Charge le bateau et place le joueur : en solo, à l'hébergement, ou à l'accueil de l'hôte.
func _setup_ship(ship_name: String) -> void:
	if _ship != null:
		return
	if _menu != null:
		_menu.queue_free()
		_menu = null
		_main_menu = null
	_ship = ShipModel.new()
	if not _ship.load_ship(ship_name):
		push_error("Bateau introuvable : %s" % ship_name)
		_ship = null
		return
	_world.add_child(_ship)
	_sim.configure(_load_stats(ship_name))
	_sim.yaw = deg_to_rad(float(_args.get("yaw", "0")))
	if not _args.has("no-port"):
		_build_port()
	_build_blob()
	_build_player()
	_build_interactables()
	_apply_test_args()
	_float_ship()
	var rel0 := _player_world() - _ship.position
	_cam_offset = Vector3(rel0.x, 0.0, rel0.z)


func _start_host(ship_name: String) -> void:
	var err := _net.host(ship_name, not _args.has("no-upnp"))
	if err != OK:
		_set_status("Impossible d'héberger (erreur %d) : le port %d est peut-être déjà utilisé" % [err, SailingNet.PORT])
		return
	_setup_ship(ship_name)


func _start_join(address: String) -> void:
	var err := _net.join(address)
	if err != OK:
		_set_status("Impossible de rejoindre %s (erreur %d)" % [address, err])


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
	print("[réseau] ", text)


## Menu de départ : le vrai menu (src/ui/main_menu.gd), posé sur la mer. Au tout premier lancement, on commence
## par créer son pirate.
func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_menu = layer
	_main_menu = MainMenu.new(_local_look())
	layer.add_child(_main_menu)
	_main_menu.play_solo.connect(func(ship_name: String) -> void: _setup_ship(ship_name))
	_main_menu.host_game.connect(func(ship_name: String) -> void: _start_host(ship_name))
	_main_menu.join_game.connect(func(code: String) -> void: _start_join(code))
	_main_menu.edit_pirate.connect(_open_editor)
	_main_menu.quit_game.connect(func() -> void: get_tree().quit())
	if not FileAccess.file_exists(PirateLook.SAVE_PATH) and not _args.has("editor"):
		_open_editor.call_deferred()


## Ouvre l'éditeur d'apparence par-dessus le menu ; la nouvelle apparence est sauvegardée.
func _open_editor() -> void:
	if _editor != null:
		return
	_editor = CharacterEditor.new(_local_look())
	_menu.hide()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	layer.add_child(_editor)
	_editor.closed.connect(func(result: Dictionary) -> void:
		if not result.is_empty():
			_my_look = result
			if _main_menu != null:
				_main_menu.set_look(result)
		layer.queue_free()
		_editor = null
		_menu.show())


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else true
	return out


func _load_stats(ship_name: String) -> Dictionary:
	var f := FileAccess.open(STATS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and (parsed as Dictionary).has(ship_name):
		return (parsed as Dictionary)[ship_name]
	return {}


# ------------------------------------------------------------------ construction de la vue


## Choisit un agrandissement ENTIER proche de « 360 lignes de pixels à l'écran », puis donne au
## rendu exactement la taille de la fenêtre divisée par ce facteur : l'image remplit toute la
## fenêtre, sans bandes noires, et chaque pixel du jeu fait le même nombre de pixels d'écran.
func _layout_view() -> void:
	if _viewport == null:
		return
	var win := size
	var factor := maxi(1, roundi(win.y / float(VIEW_SIZE.y)))
	# une marge d'un pixel de jeu de chaque côté : l'image peut être décalée d'une fraction de
	# pixel (caméra au sous-pixel, voir _update_camera) sans laisser de bord vide
	var view := Vector2i(ceili(win.x / factor), ceili(win.y / factor)) + Vector2i(2, 2)
	_factor = factor
	_viewport.size = view
	_post_vp.size = view
	_post_rect.size = Vector2(view)
	_container.size = Vector2(view)
	_container.scale = Vector2(factor, factor)
	_container.position = Vector2(-factor, -factor)
	if _cam != null:
		_cam.size = float(view.y) / PIXELS_PER_METER


## Chaîne d'image : la 3D est rendue dans _viewport (taille du jeu, ex. 640x360) ; le filtre pixel
## art (palette + contours) est appliqué dans _post_vp, À LA MÊME TAILLE ; puis _container agrandit
## le résultat par un facteur ENTIER (x2, x3...). Le filtre ne travaille donc que sur les pixels du
## jeu, pas sur ceux de l'écran : 9 fois moins de calcul en 1080p.
func _build_view() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# suréchantillonnage possible (--ss=2) : bords plus doux, mais mesuré plus scintillant en mouvement
	# (les couleurs intermédiaires des bords basculent d'un ton de palette à l'autre) : désactivé par défaut
	_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_viewport.scaling_3d_scale = float(_args.get("ss", "1.0"))
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)

	_container = SubViewportContainer.new()
	_container.stretch = false
	_container.size = Vector2(VIEW_SIZE)
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_container)
	_post_vp = SubViewport.new()
	_post_vp.size = VIEW_SIZE
	_post_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_post_vp)
	_post_rect = TextureRect.new()
	_post_rect.texture = _viewport.get_texture()
	_post_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_post_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_post_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_post_rect.size = Vector2(VIEW_SIZE)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/pixel_look.gdshader")
	_post_mat = mat
	_post_rect.material = mat
	if _args.has("no-palette"):
		mat.set_shader_parameter("use_palette", false)
	_post_vp.add_child(_post_rect)
	resized.connect(_layout_view)
	_layout_view.call_deferred()

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.10, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var day := str(_args.get("light", "jour")) == "jour"
	env.ambient_light_color = Color(0.62, 0.66, 0.78) if day else Color(0.42, 0.40, 0.68)
	env.ambient_light_energy = 1.05 if day else 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_world.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -40, 0)
	sun.light_color = Color(1.0, 0.93, 0.80) if day else Color(1.0, 0.72, 0.52)
	sun.light_energy = 1.55 if day else 1.7
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.4
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	_world.add_child(sun)
	_sun = sun

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = float(VIEW_SIZE.y) / PIXELS_PER_METER
	_cam.near = 0.1
	_cam.far = 250.0
	_cam.rotation_degrees = Vector3(-ELEVATION_DEG, 0, 0)
	_world.add_child(_cam)

	# surface de la mer : un maillage fin (un sommet tous les 25 cm) que la houle soulève
	_sea = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SEA_MESH_SIZE, SEA_MESH_SIZE)
	var segments := int(SEA_MESH_SIZE / SEA_MESH_STEP) - 1
	plane.subdivide_width = segments
	plane.subdivide_depth = segments
	_sea.mesh = plane
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/water.gdshader")
	_sea.material_override = _water_mat
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sea.extra_cull_margin = 4.0
	_world_fixed = Node3D.new()
	_world.add_child(_world_fixed)
	_world_fixed.add_child(_sea)
	_load_sea()
	if _args.has("debug-water"):
		_water_mat.set_shader_parameter("debug_view", int(str(_args["debug-water"])) if str(_args["debug-water"]).is_valid_int() else 1)
	if _args.has("shadow-blur"):
		_sun.shadow_blur = float(_args["shadow-blur"])
	if _args.has("noshadow"):
		_sun.shadow_enabled = false
	if _args.has("nomsaa"):
		_viewport.msaa_3d = Viewport.MSAA_DISABLED


## Lit la houle (data/sea.json) : les mêmes vagues servent à l'eau et à la flottaison du bateau.
func _load_sea() -> void:
	var f := FileAccess.open(SEA_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_sea_cfg = parsed
	_waves.clear()
	for w: Array in _sea_cfg.get("waves", []):
		_waves.append(Vector4(float(w[0]), float(w[1]), float(w[2]), float(w[3])))
	while _waves.size() < 4:
		_waves.append(Vector4.ZERO)
	_water_mat.set_shader_parameter("waves", _waves)


## Hauteur de la houle (m, autour du niveau de la mer) au point (x, z) du monde.
func _wave_height(p: Vector2) -> float:
	var h := 0.0
	for w: Vector4 in _waves:
		h += w.x * sin(p.x * w.y + p.y * w.z + _sea_t * w.w)
	return h


func _save_frame() -> void:
	if _frames_left <= 0:
		if RenderingServer.frame_post_draw.is_connected(_save_frame):
			RenderingServer.frame_post_draw.disconnect(_save_frame)
		return
	var n := int(_args["frames"]) - _frames_left
	var dir := str(_args.get("frames-dir", "qa/frames"))
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/f_%03d.png" % [dir, n])
	_frames_left -= 1


## Diagnostic : hauteurs réelles de la coque et de la mer.
func _print_bounds() -> void:
	var lo := INF
	var hi := -INF
	var stack: Array[Node] = [_ship]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and String(n.name).begins_with("hull"):
			var mi := n as MeshInstance3D
			var aabb: AABB = mi.global_transform * mi.get_aabb()
			lo = minf(lo, aabb.position.y)
			hi = maxf(hi, aabb.end.y)
		stack.append_array(n.get_children())
	print("[hauteurs] coque de %.2f à %.2f m ; bateau y=%.2f ; mer y=%.2f" % [lo, hi, _ship.global_position.y, _sea.global_position.y])


## Charge la ville portuaire à l'origine du monde et amarre le bateau le long du ponton principal,
## étrave vers le large (sud). Les sols sont repeints par shaders/ground.gdshader.
func _build_port() -> void:
	var scene := load("res://assets/models/port/port.glb") as PackedScene
	var f := FileAccess.open("res://assets/models/port/port_meta.json", FileAccess.READ)
	if scene == null or f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_port_meta = parsed if parsed is Dictionary else {}
	_land.load_meta(_port_meta)
	_port = scene.instantiate() as Node3D
	_world_fixed.add_child(_port)
	var kinds := {"ground_cobble": 0, "ground_planks": 1, "ground_sand": 2, "ground_grass": 3}
	# matières peintes : le nom du matériau Blender dit quel motif utiliser (enduit, tuiles, bois, pierre)
	var surface_kinds := {"pl_": 0, "roof_": 1, "wood": 2, "stone": 3}
	var ground_shader := load("res://shaders/ground.gdshader") as Shader
	var surface_shader := load("res://shaders/surface.gdshader") as Shader
	var stack: Array[Node] = [_port]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		var is_ground := false
		for key: String in kinds:
			if String(n.name).contains(key):
				var m := ShaderMaterial.new()
				m.shader = ground_shader
				m.set_shader_parameter("kind", kinds[key])
				mi.material_override = m
				is_ground = true
		if is_ground or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			for prefix: String in surface_kinds:
				if src.resource_name.begins_with(prefix):
					var sm := ShaderMaterial.new()
					sm.shader = surface_shader
					sm.set_shader_parameter("kind", surface_kinds[prefix])
					sm.set_shader_parameter("base", src.albedo_color)
					mi.set_surface_override_material(s, sm)
					break
	# amarrage : coque contre le flanc est du ponton, étrave au sud (+z dans le jeu)
	if not _args.has("player") and not _args.has("yaw"):
		var dock: Dictionary = _port_meta.get("dock", {})
		var half_beam := _ship.beam * ShipModel.SCALE * 0.5
		var x := float(dock.get("pier_x1", 18.0)) + half_beam + 0.5
		var z := -float(dock.get("y", -14.0))
		_sim.yaw = -PI / 2.0
		# le centre de la coque est décalé du pivot du bateau (beaupré compris) : on le compense
		_sim.position = Vector2(x, z) - Vector2(cos(_sim.yaw), -sin(_sim.yaw)) * (_ship.shift * ShipModel.SCALE)


## Ombre ronde sous le pirate.
func _build_blob() -> void:
	_blob = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.01
	_blob.mesh = disc
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0.02, 0.01, 0.06, 0.42)
	_blob.material_override = bm
	_blob.scale = Vector3(1.0, 1.0, 0.7)
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ship.add_child(_blob)


## Place le bateau sur la houle (pilonnement, tangage, roulis) et transmet à l'eau la position du
## bateau pour son sillage.
func _float_ship() -> void:
	# La houle avance en continu (des paliers faisaient « sauter » toute la mer plusieurs fois par
	# seconde, visible à 144 images/s). Le même temps sert à l'eau et à la flottaison ; un client
	# se cale sur le temps de l'hôte pour que tout le monde voie les mêmes vagues.
	_sea_t = _time + _time_offset
	var yaw_basis := Basis(Vector3.UP, _sim.yaw)
	var fwd3 := yaw_basis * Vector3.RIGHT
	var left3 := yaw_basis * Vector3.FORWARD
	# position monde continue (plus de sauts d'un pixel) : la mer glisse sous le bateau en douceur
	var flat := Vector3(_sim.position.x, 0.0, _sim.position.y)
	var center := flat + fwd3 * (_ship.shift * ShipModel.SCALE)
	var hl := _ship.length * ShipModel.SCALE * 0.4
	var hb := _ship.beam * ShipModel.SCALE * 0.45
	var c2 := Vector2(center.x, center.z)
	var f2 := Vector2(fwd3.x, fwd3.z)
	var l2 := Vector2(left3.x, left3.z)
	var h_bow := _wave_height(c2 + f2 * hl)
	var h_stern := _wave_height(c2 - f2 * hl)
	var h_port := _wave_height(c2 + l2 * hb)
	var h_star := _wave_height(c2 - l2 * hb)
	var heave := (h_bow + h_stern + h_port + h_star) * 0.25 * float(_sea_cfg.get("buoyancy_follow", 0.85))
	var pitch := atan2(h_bow - h_stern, hl * 2.0) * float(_sea_cfg.get("pitch_follow", 0.7))
	var roll := atan2(h_port - h_star, hb * 2.0) * float(_sea_cfg.get("roll_follow", 0.7))
	roll -= _sim.rudder * 0.035 * clampf(_sim.speed / maxf(_sim.max_speed, 0.1), 0.0, 1.0)
	_ship.position = Vector3(0.0, heave, 0.0)
	_world_origin = flat
	_world_fixed.position = Vector3(-flat.x, 0.0, -flat.z)
	_water_mat.set_shader_parameter("world_offset", Vector2(flat.x, flat.z))
	_water_mat.set_shader_parameter("sun_dir", _sun.global_transform.basis.z.normalized())
	_water_mat.set_shader_parameter("view_dir", _cam.global_transform.basis.z.normalized())
	_ship.rotation = Vector3(roll, _sim.yaw, pitch)
	_water_mat.set_shader_parameter("sea_time", _sea_t)
	_water_mat.set_shader_parameter("ship_center", c2)
	_water_mat.set_shader_parameter("ship_fwd", f2)
	_water_mat.set_shader_parameter("ship_speed", clampf(_sim.speed / maxf(_sim.max_speed, 0.1), 0.0, 1.0))
	_water_mat.set_shader_parameter("hull_len", _ship.length * ShipModel.SCALE)
	_water_mat.set_shader_parameter("hull_beam", _ship.beam * ShipModel.SCALE)
	# ombre du pont : le soleil la projette sur l'eau, décalée selon sa direction et la hauteur du pont
	var light_dir := -_sun.global_transform.basis.z
	var deck_above_water := heave - SEA_Y
	if light_dir.y < -0.05:
		var off := Vector2(light_dir.x, light_dir.z) * (deck_above_water / -light_dir.y)
		_water_mat.set_shader_parameter("shadow_offset", off)


func _build_player() -> void:
	_sprite = PirateSprite.new()
	_sprite.set_look(_local_look())
	_ship.add_child(_sprite)
	_ball_icon = _make_ball(0.14, Color(0.12, 0.12, 0.16))
	_ball_icon.visible = false
	_sprite.add_child(_ball_icon)
	_ball_icon.position = Vector3(0.0, 2.2, 0.0)
	# point de départ : devant la porte de la cabine, décalé selon la place du joueur dans l'équipage
	var cabin := _ship.cabin
	var door_x := float(cabin.get("door_x", 0.0))
	var spots: Array[Vector2] = [Vector2(door_x + 0.9, 0.7), Vector2(door_x + 0.9, -0.2),
			Vector2(door_x + 1.6, 1.2), Vector2(door_x + 1.7, 0.2)]
	var slot := _crew_ids().find(_my_id())
	_ppos = spots[0]
	for k in spots.size():
		var cand: Vector2 = spots[(maxi(slot, 0) + k) % spots.size()]
		if _ship.is_walkable(cand):
			_ppos = cand
			break
	if _args.has("player") or _args.has("spawn"):
		var parts := str(_args.get("player", _args.get("spawn"))).split(",")
		_ppos = Vector2(float(parts[0]), float(parts[1]))
	# lanterne de la cabine
	if cabin.has("light"):
		var l: Array = cabin["light"]
		var omni := OmniLight3D.new()
		omni.light_color = Color(1.0, 0.7, 0.4)
		omni.light_energy = 1.6
		omni.omni_range = 4.5
		omni.position = Vector3((float(l[0]) + _ship.shift) * ShipModel.SCALE, float(l[1]) * ShipModel.SCALE, -float(l[2]) * ShipModel.SCALE)
		_ship.add_child(omni)


func _make_ball(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mi.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	return mi


func _build_interactables() -> void:
	var meta := _ship.meta
	var helm: Array = meta.get("helm", [0.0, 0.0])
	_interactables.append({"kind": "helm", "pos": Vector2(float(helm[0]), float(helm[1]))})
	for m: Array in meta.get("masts", []):
		_interactables.append({"kind": "mast", "pos": Vector2(float(m[0]), 0.0)})
	for i in _ship.ladders.size():
		var l: Array = _ship.ladders[i]
		_interactables.append({"kind": "ladder", "pos": Vector2(float(l[0]), float(l[1])), "index": i})
	if not _ship.mast_ladder.is_empty():
		_interactables.append({"kind": "mastladder", "pos": Vector2(float(_ship.mast_ladder[0]), float(_ship.mast_ladder[1]))})
	var anchor: Array = meta.get("anchor", [0.0, 0.0])
	_interactables.append({"kind": "anchor", "pos": Vector2(float(anchor[0]), float(anchor[1]))})
	var ammo: Array = meta.get("ammo", [0.0, 0.0])
	_interactables.append({"kind": "ammo", "pos": Vector2(float(ammo[0]), float(ammo[1]))})
	for i in _ship.cannons.size():
		var c: Array = _ship.cannons[i]
		_interactables.append({"kind": "cannon", "pos": Vector2(float(c[0]), float(c[1])), "index": i})
		_cannon_loaded.append(false)
		var icon := _make_ball(0.12, Color(1.0, 0.6, 0.2))
		var mat := icon.material_override as StandardMaterial3D
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		icon.visible = false
		icon.position = Vector3((float(c[0]) + _ship.shift) * ShipModel.SCALE, float(c[3]) * ShipModel.SCALE + 0.7, -float(c[1]) * ShipModel.SCALE)
		_ship.add_child(icon)
		_cannon_icons.append(icon)


func _build_hud() -> void:
	_hud = Label.new()
	_hud.position = Vector2(12, 8)
	_hud.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_hud.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_hud.add_theme_constant_override("outline_size", 6)
	_hud.add_theme_font_size_override("font_size", 16)
	add_child(_hud)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position = Vector2(0, -44)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_font_size_override("font_size", 18)
	add_child(_prompt)
	# état du réseau (adresse à donner aux amis, connexion…), en haut à droite
	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_status_label.position = Vector2(-12, 34)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_status_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_status_label.add_theme_constant_override("outline_size", 6)
	_status_label.add_theme_font_size_override("font_size", 15)
	add_child(_status_label)


func _apply_test_args() -> void:
	if _args.has("sail"):
		_sim.sail_level = int(_args["sail"])
		_sim.sail_open = float(_sim.sail_level) / ShipSim.SAIL_LEVELS
	if _args.has("rudder"):
		_sim.rudder_target = float(_args["rudder"])
		_sim.rudder = _sim.rudder_target
	if _args.has("anchor"):
		_sim.anchored = true
	if _args.has("speed"):
		_sim.speed = float(_args["speed"])
	if _args.has("walkto"):
		var parts := str(_args["walkto"]).split(",")
		_walkto = Vector2(float(parts[0]), float(parts[1]))
	if _args.has("helm"):
		_request("helm_take", 0)
		_enter_helm()
	if _args.has("shippos"):
		var sp := str(_args["shippos"]).split(",")
		_sim.position = Vector2(float(sp[0]), float(sp[1]))
	if _args.has("land"):
		var lp := str(_args["land"]).split(",")
		_lpos = Vector2(float(lp[0]), float(lp[1]))
		_loc = Loc.LAND
	if _args.has("press"):
		# test : --press=E@2,SPACE@3.5 appuie sur ces touches aux secondes indiquées
		var codes := {"E": KEY_E, "R": KEY_R, "SPACE": KEY_SPACE}
		for item in str(_args["press"]).split(","):
			var kv := item.split("@")
			var code: Key = codes.get(kv[0], KEY_E)
			get_tree().create_timer(float(kv[1])).timeout.connect(func() -> void:
				var ev := InputEventKey.new()
				ev.physical_keycode = code
				ev.pressed = true
				_unhandled_input(ev))
	if _args.has("send"):
		# test réseau : --send=sail:1,anchor:0 envoyé 2 s après l'arrivée à bord
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			for item in str(_args["send"]).split(","):
				var kv := item.split(":")
				_request(kv[0], int(kv[1]) if kv.size() > 1 else 0))
	if _args.has("fire"):
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			for i in _ship.cannons.size():
				_cannon_loaded[i] = true
				_request("fire", i))
	if _args.has("shot"):
		get_tree().create_timer(float(_args.get("shot-after-secs", "3"))).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(str(_args["shot"])))
	if _args.has("shot2"):
		get_tree().create_timer(float(_args.get("shot-after-secs", "3")) + 0.05).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(str(_args["shot2"])))
	if _args.has("bounds"):
		get_tree().create_timer(1.0).timeout.connect(_print_bounds)
	if _args.has("frames"):
		# enregistre N images consécutives (diagnostic des vibrations), dans --frames-dir
		get_tree().create_timer(float(_args.get("shot-after-secs", "3"))).timeout.connect(func() -> void:
			_frames_left = int(_args["frames"])
			RenderingServer.frame_post_draw.connect(_save_frame))
	if _args.has("quit-after-secs"):
		get_tree().create_timer(float(_args["quit-after-secs"])).timeout.connect(get_tree().quit)


# ------------------------------------------------------------------ boucle


func _process(delta_raw: float) -> void:
	var delta := minf(delta_raw, 0.05)
	if _ship == null:
		return
	_time += delta
	_update_player(delta)
	var prev_sim_pos := _sim.position
	var prev_sim_yaw := _sim.yaw
	_sim.step(delta)
	_collide_ship_with_land(prev_sim_pos, prev_sim_yaw)
	if _net.active and not _net.is_host:
		_correct_from_host(delta)
	_float_ship()
	_ship.set_sail_open(_sim.sail_open)
	_place_pirate()
	_ship.update_cutaway(_loc == Loc.SHIP and _ship.inside_cabin(_ppos))
	var up_mast: bool = _loc == Loc.NEST or (_loc == Loc.CLIMB and _climb.get("kind") == "mast")
	_sprite.no_depth_test = up_mast   # en haut du mât, ni le mât ni le nid ne cachent le pirate
	_ship.hide_sails_above(float(_ship.mast_ladder[3]) - 0.3 if up_mast and not _ship.mast_ladder.is_empty() else 1000.0)
	_update_remotes(delta)
	for i in _cannon_icons.size():
		_cannon_icons[i].visible = _cannon_loaded[i]
	if _mode == Mode.HELM and _helm_owner != 0 and _helm_owner != _my_id():
		_mode = Mode.WALK  # quelqu'un d'autre a pris la barre avant nous
	_update_projectiles(delta)
	_update_camera(delta)
	_animate_pirates(delta)
	_sync_pirate_palette()
	_snap_sprite()
	_update_hud()
	_net.tick(delta)
	if _args.has("log"):
		_log_timer += delta
		if _log_timer >= 1.0:
			_log_timer = 0.0
			print("[pirate] lieu=%d ppos=%s lpos=%s pz=%.2f sprite=%s cam=%s vis=%s" % [_loc, _ppos, _lpos, _pz, _sprite.global_position, _cam.position, _sprite.visible])
			print("[etat] fps=%d t=%.1f pos=(%.1f, %.1f) cap=%.0f° vitesse=%.2f voiles=%.2f barre=%.2f joueur=(%.2f, %.2f) cabine=%s équipage=%d barre=%d" % [
				Engine.get_frames_per_second(), _time, _sim.position.x, _sim.position.y, rad_to_deg(_sim.yaw), _sim.speed, _sim.sail_open,
				_sim.rudder, _ppos.x, _ppos.y, str(_ship.inside_cabin(_ppos)), _remotes.size() + 1, _helm_owner])


func _axis(neg: Array, pos: Array) -> float:
	var v := 0.0
	for k: Key in pos:
		if Input.is_physical_key_pressed(k):
			v += 1.0
			break
	for k: Key in neg:
		if Input.is_physical_key_pressed(k):
			v -= 1.0
			break
	return v


func _update_player(delta: float) -> void:
	_update_jump(delta)
	var move := Vector2(_axis([KEY_A, KEY_LEFT], [KEY_D, KEY_RIGHT]), _axis([KEY_W, KEY_UP], [KEY_S, KEY_DOWN]))
	if _loc == Loc.CLIMB:
		_update_climb(delta)
		return
	if _loc == Loc.NEST:
		_update_nest(move, delta)
		return
	if _loc == Loc.SHIP and _mode == Mode.HELM:
		if move.x != _rudder_sent:
			_rudder_sent = move.x
			_request("rudder", int(move.x * 100.0))
		return
	if _jump_wind > 0.0:
		return   # accroupi avant de sauter
	if _loc == Loc.LAND:
		if move != Vector2.ZERO:
			_lpos = _land.move_with_slide(_lpos, move.normalized() * WALK_SPEED * delta)
		return
	var step_units := WALK_SPEED / ShipModel.SCALE * delta
	if _walkto != Vector2.INF:
		var d := _walkto - _ppos
		if d.length() > 0.04:
			_ppos = _ship.move_with_slide(_ppos, d.normalized() * minf(step_units, d.length()))
		return
	if move == Vector2.ZERO:
		return
	_ppos = _ship.move_with_slide(_ppos, _ship_dir(move) * step_units)


## Direction d'écran (x vers la droite, y vers le bas) -> direction dans le repère du modèle du bateau.
func _ship_dir(move: Vector2) -> Vector2:
	var world_dir := Vector3(move.x, 0.0, move.y).normalized()
	var local := _ship.global_transform.basis.inverse() * world_dir
	return Vector2(local.x, -local.z).normalized()


## Direction du repère du modèle (dx, dy) -> direction d'écran.
func _screen_of_ship(d: Vector2) -> Vector2:
	var w := _ship.global_transform.basis * Vector3(d.x, 0.0, -d.y)
	return Vector2(w.x, w.z)


## Position monde (x/z) d'un point du pont.
func _ship_to_world(bp: Vector2) -> Vector2:
	var local := Vector3((bp.x + _ship.shift) * ShipModel.SCALE, 0.0, -bp.y * ShipModel.SCALE)
	var w := Basis(Vector3.UP, _sim.yaw) * local
	return _sim.position + Vector2(w.x, w.z)


## Point de la scène (repère du jeu) pour un point du pont à la hauteur h au-dessus du pont.
func _ship_point(bp: Vector2, h: float) -> Vector3:
	return _ship.to_global(_ship.to_local3(bp, h))


## Point de la scène pour une position à terre (monde x/z) à la hauteur h au-dessus du sol.
func _land_point(w: Vector2, h: float) -> Vector3:
	return Vector3(w.x - _world_origin.x, h, w.y - _world_origin.z)


## Saut : un temps d'accroupissement, puis une parabole. Possible à terre comme sur le pont.
func _update_jump(delta: float) -> void:
	_land_t = maxf(_land_t - delta, 0.0)
	if _notice_t > 0.0:
		_notice_t -= delta
	if _jump_wind > 0.0:
		_jump_wind -= delta
		if _jump_wind <= 0.0:
			_vz = JUMP_SPEED
	if _loc != Loc.SHIP and _loc != Loc.LAND:
		_vz = 0.0   # sur une échelle ou dans le nid : pas de gravité, la hauteur est dictée par la montée
		return
	if _vz != 0.0 or _pz > 0.0:
		_pz += _vz * delta
		_vz -= GRAVITY * delta
		if _pz <= 0.0 and _vz < 0.0:
			_pz = 0.0
			_vz = 0.0
			_land_t = 0.14


func _try_jump() -> void:
	if (_loc == Loc.SHIP or _loc == Loc.LAND) and _mode == Mode.WALK and _pz == 0.0 and _vz == 0.0 and _jump_wind <= 0.0:
		_jump_wind = 0.09


func _say(text: String, seconds: float = 2.5) -> void:
	_notice = text
	_notice_t = seconds


## Hauteur du plancher du nid de pie au-dessus du pont (m).
func _nest_height() -> float:
	if _ship.nests.is_empty() or _ship.mast_ladder.is_empty():
		return 0.0
	var nx := float(_ship.mast_ladder[0]) + 0.62
	return (float(_ship.mast_ladder[3]) + 0.06) * ShipModel.SCALE - _ship.deck_height(nx)


## Le nid de pie du mât qui porte l'échelle.
func _mast_nest() -> Array:
	for n: Array in _ship.nests:
		if absf(float(n[0]) - (float(_ship.mast_ladder[0]) + 0.62)) < 0.05:
			return n
	return []


## Monte (up) ou descend l'échelle du mât le plus haut.
func _start_mast_climb(up: bool) -> void:
	if _ship.mast_ladder.is_empty():
		return
	_loc = Loc.CLIMB
	_climb = {"kind": "mast", "t": 0.0 if up else 1.0, "up": up}
	_ppos = Vector2(float(_ship.mast_ladder[0]) + 0.3, float(_ship.mast_ladder[1]))
	_mode = Mode.WALK


func _update_climb(delta: float) -> void:
	if _climb.get("kind") == "mast":
		var top := maxf(_nest_height(), 0.5)
		var t: float = _climb["t"] + (1.0 if _climb["up"] else -1.0) * CLIMB_SPEED * delta / top
		_climb["t"] = clampf(t, 0.0, 1.0)
		_pz = top * float(_climb["t"])
		if t >= 1.0:
			_loc = Loc.NEST
			_pz = top
			var nest := _mast_nest()
			if not nest.is_empty():
				_ppos = Vector2(float(nest[0]), float(nest[1]) + NEST_RADIUS.y * 0.9)
		elif t <= 0.0:
			_loc = Loc.SHIP
			_pz = 0.0
			_ppos = _ship.nearest_walkable(Vector2(float(_ship.mast_ladder[0]) - 0.1, 0.0))
		return
	# échelle de coque : on passe par-dessus le plat-bord, en un petit arc, du pont au quai (ou l'inverse)
	var dur: float = _climb["dur"]
	_climb["t"] = minf(float(_climb["t"]) + delta / dur, 1.0)
	var t2: float = _climb["t"]
	_lpos = (_climb["from"] as Vector2).lerp(_climb["to"], t2)
	_pz = sin(PI * t2) * 0.55
	if t2 >= 1.0:
		_pz = 0.0
		if _climb["board"]:
			_loc = Loc.SHIP
			_ppos = _climb["deck"]
		else:
			_loc = Loc.LAND
			_lpos = _climb["to"]
		_climb = {}


func _update_nest(move: Vector2, delta: float) -> void:
	var nest := _mast_nest()
	if nest.is_empty():
		return
	var c := Vector2(float(nest[0]), float(nest[1]))
	var p := _ppos
	if move != Vector2.ZERO:
		p += _ship_dir(move) * (WALK_SPEED * 0.55 / ShipModel.SCALE * delta)
	var d := p - c
	var dist := clampf(d.length(), NEST_RADIUS.x, NEST_RADIUS.y)
	_ppos = c + (d.normalized() if d.length() > 0.001 else Vector2(-1, 0)) * dist


## Descend par l'échelle de coque `i` : de l'autre côté du plat-bord il y a le quai.
func _try_disembark(i: int) -> void:
	var l: Array = _ship.ladders[i]
	var side := float(l[2])
	var outside := _ship_to_world(Vector2(float(l[0]), float(l[3]) + side * 0.9))
	var target := _land.nearest_walkable(outside, LADDER_REACH)
	if not _land.is_walkable(target) or target.distance_to(outside) > LADDER_REACH:
		_say("Pas de quai à portée de l'échelle")
		return
	if absf(_sim.speed) > 1.5:
		_say("Le bateau va trop vite")
		return
	_loc = Loc.CLIMB
	_climb = {"kind": "hull", "t": 0.0, "dur": 1.1, "from": _ship_to_world(_ppos), "to": target, "board": false}
	_lpos = _climb["from"]
	_mode = Mode.WALK


func _nearest_ship_ladder_from_land() -> int:
	var best := -1
	var best_d := LADDER_REACH
	for i in _ship.ladders.size():
		var l: Array = _ship.ladders[i]
		var out := _ship_to_world(Vector2(float(l[0]), float(l[3]) + float(l[2]) * 0.9))
		var d := _lpos.distance_to(out)
		if d < best_d:
			best_d = d
			best = i
	return best


func _try_board() -> void:
	var i := _nearest_ship_ladder_from_land()
	if i < 0:
		_say("Aucune échelle à portée")
		return
	if absf(_sim.speed) > 1.5:
		_say("Le bateau va trop vite")
		return
	var l: Array = _ship.ladders[i]
	var deck := _ship.nearest_walkable(Vector2(float(l[0]), float(l[1])))
	_loc = Loc.CLIMB
	_climb = {"kind": "hull", "t": 0.0, "dur": 1.1, "from": _lpos, "to": _ship_to_world(deck), "board": true, "deck": deck}
	_mode = Mode.WALK


## Le bateau s'arrête contre la terre : on essaie de glisser, sinon on revient en arrière.
func _collide_ship_with_land(prev_pos: Vector2, prev_yaw: float) -> void:
	if _land.walk_rects.is_empty() or _ship == null:
		return
	if not Land.hits_land(_ship.hull_points_world(_sim.position, _sim.yaw)):
		return
	var np := _sim.position
	var yaw := _sim.yaw
	var options: Array = [Vector2(np.x, prev_pos.y), Vector2(prev_pos.x, np.y), prev_pos]
	for o: Vector2 in options:
		if not Land.hits_land(_ship.hull_points_world(o, yaw)):
			_sim.position = o
			_sim.speed *= 0.5
			return
	_sim.position = prev_pos
	_sim.yaw = prev_yaw
	_sim.speed = 0.0


## Place mon pirate et son ombre dans la scène selon l'endroit où il se trouve.
func _place_pirate() -> void:
	var gp: Vector3
	var ground: Vector3
	var shadow := true
	match _loc:
		Loc.LAND:
			gp = _land_point(_lpos, 0.02 + _pz)
			ground = _land_point(_lpos, 0.04)
		Loc.CLIMB:
			if _climb.get("kind") == "mast":
				gp = _ship_point(_ppos, 0.02 + _pz)
				ground = gp
				shadow = false
			else:
				gp = _land_point(_lpos, 0.02 + _pz)
				ground = _land_point(_lpos, 0.04)
		Loc.NEST:
			gp = _ship_point(_ppos, 0.02 + _pz)
			ground = _ship_point(_ppos, 0.06 + _pz)
		_:
			gp = _ship_point(_ppos, 0.02 + _pz)
			ground = _ship_point(_ppos, 0.04)
	_sprite.global_position = gp
	_blob.global_position = ground
	_blob.visible = shadow
	var air := _pz if (_loc == Loc.SHIP or _loc == Loc.LAND) else 0.0
	var k := maxf(0.55, 1.0 - air * 0.35)
	_blob.scale = Vector3(k, 1.0, 0.7 * k)


## Cale les sprites (le mien et ceux de l'équipage) sur la grille de pixels de l'écran : sinon
## leurs pixels « vibrent » quand ils bougent.
func _snap_sprite() -> void:
	_snap_node(_sprite)
	for id in _remotes:
		_snap_node(_remotes[id]["sprite"])


func _snap_node(node: Node3D) -> void:
	var basis := _cam.global_transform.basis
	var right := basis.x
	var up := basis.y
	var g := node.global_position
	var d := g - _cam.global_position
	var dr := d.dot(right)
	var du := d.dot(up)
	g += right * (roundf(dr * PIXELS_PER_METER) / PIXELS_PER_METER - dr)
	g += up * (roundf(du * PIXELS_PER_METER) / PIXELS_PER_METER - du)
	node.global_position = g


# ------------------------------------------------------------------ réseau : interface avec SailingNet


func local_player_state() -> Dictionary:
	var on_land: bool = _loc == Loc.LAND or (_loc == Loc.CLIMB and _climb.get("kind") == "hull")
	var code := 1 if on_land else (2 if _loc == Loc.CLIMB else (3 if _loc == Loc.NEST else 0))
	return {"pos": _lpos if on_land else _ppos, "carrying": _carrying, "loc": code, "pz": _pz}


## Hôte : état du bateau diffusé aux clients.
func ship_state() -> Array:
	var mask := 0
	for i in _cannon_loaded.size():
		if _cannon_loaded[i]:
			mask |= 1 << i
	return [_sim.position.x, _sim.position.y, _sim.yaw, _sim.speed, _sim.rudder, _sim.rudder_target,
			_sim.sail_level, _sim.sail_open, 1 if _sim.anchored else 0, mask, _helm_owner, _time]


## Client : reçoit l'état du bateau de l'hôte. La position et le cap servent de cible (recalage en
## douceur dans _correct_from_host) ; le reste est appliqué tel quel.
func apply_ship_state(s: Array) -> void:
	if _ship == null or s.size() < 12:
		return
	_net_target = {"pos": Vector2(float(s[0]), float(s[1])), "yaw": float(s[2]), "age": 0.0}
	_sim.speed = float(s[3])
	_sim.rudder = float(s[4])
	_sim.rudder_target = float(s[5])
	_sim.sail_level = int(s[6])
	_sim.sail_open = float(s[7])
	_sim.anchored = int(s[8]) == 1
	var mask := int(s[9])
	for i in _cannon_loaded.size():
		_cannon_loaded[i] = ((mask >> i) & 1) == 1
	_helm_owner = int(s[10])
	var offset := float(s[11]) - _time
	_time_offset = offset if absf(offset - _time_offset) > 1.0 else lerpf(_time_offset, offset, 0.1)


## Client : rapproche en douceur le bateau prédit localement de l'état de l'hôte (extrapolé depuis
## sa réception). Un grand écart (plusieurs mètres) est corrigé d'un coup.
func _correct_from_host(delta: float) -> void:
	if _net_target.is_empty():
		return
	_net_target["age"] = float(_net_target["age"]) + delta
	var yaw: float = _net_target["yaw"]
	var target: Vector2 = _net_target["pos"] + Vector2(cos(yaw), -sin(yaw)) * _sim.speed * float(_net_target["age"])
	if _sim.position.distance_to(target) > 6.0:
		_sim.position = target
		_sim.yaw = yaw
		return
	var k := 1.0 - exp(-delta * 6.0)
	_sim.position = _sim.position.lerp(target, k)
	_sim.yaw = lerp_angle(_sim.yaw, yaw, k)


func apply_remote_player(id: int, pos: Vector2, carrying: bool, loc: int, pz: float) -> void:
	if _ship == null:
		return
	if not _remotes.has(id):
		_add_remote(id, pos)
	var r: Dictionary = _remotes[id]
	if int(r["loc"]) != loc:
		r["loc"] = loc
		r["pos"] = pos
		r["prev"] = pos
	r["target"] = pos
	r["pz"] = pz
	(r["ball"] as MeshInstance3D).visible = carrying


func _add_remote(id: int, pos: Vector2) -> void:
	var sprite := PirateSprite.new()
	sprite.set_look(_remote_looks.get(id, PirateLook.random_look(id)))
	_ship.add_child(sprite)
	var ball := _make_ball(0.14, Color(0.12, 0.12, 0.16))
	ball.visible = false
	sprite.add_child(ball)
	ball.position = Vector3(0.0, 2.2, 0.0)
	var blob := _blob.duplicate() as MeshInstance3D
	_ship.add_child(blob)
	_remotes[id] = {"sprite": sprite, "blob": blob, "ball": ball, "pos": pos, "target": pos, "prev": pos, "loc": 0, "pz": 0.0}


func _update_remotes(delta: float) -> void:
	var k := 1.0 - exp(-delta * 12.0)
	for id in _remotes:
		var r: Dictionary = _remotes[id]
		var p: Vector2 = (r["pos"] as Vector2).lerp(r["target"], k)
		r["pos"] = p
		var pz: float = r["pz"]
		var sprite := r["sprite"] as Node3D
		var blob := r["blob"] as MeshInstance3D
		if int(r["loc"]) == 1:
			sprite.global_position = _land_point(p, 0.02 + pz)
			blob.global_position = _land_point(p, 0.04)
		else:
			var up := pz if int(r["loc"]) == 3 else 0.0
			sprite.global_position = _ship_point(p, 0.02 + pz)
			blob.global_position = _ship_point(p, 0.04 + up)
		blob.visible = int(r["loc"]) != 2


## Mon apparence : celle de l'éditeur (sauvegardée), sinon celle par défaut.
func _local_look() -> Dictionary:
	if _my_look.is_empty():
		_my_look = PirateLook.load_saved()
	return _my_look


## Mon apparence, à envoyer aux autres joueurs.
func local_look_json() -> String:
	return PirateLook.key(_local_look())


## Reçoit l'apparence d'un autre joueur.
func apply_remote_look(id: int, json: String) -> void:
	var parsed: Variant = JSON.parse_string(json)
	if not (parsed is Dictionary):
		return
	var look := PirateLook.sanitize(parsed)
	_remote_looks[id] = look
	if _remotes.has(id):
		(_remotes[id]["sprite"] as PirateSprite).set_look(look)


## Donne au filtre « palette » les couleurs des pirates (elles changent quand l'apparence change).
func _sync_pirate_palette() -> void:
	if _post_mat == null or _palette_version == PirateSprite.palette_version:
		return
	_palette_version = PirateSprite.palette_version
	_post_mat.set_shader_parameter("char_palette", PirateSprite.palette_texture())
	_post_mat.set_shader_parameter("char_count", PirateSprite.palette_colors.size())


func _animate_pirates(delta: float) -> void:
	if _prev_ppos == Vector2.INF:
		_prev_ppos = _ppos
	var on_land: bool = _loc == Loc.LAND or (_loc == Loc.CLIMB and _climb.get("kind") == "hull")
	var was_land: bool = _prev_loc == Loc.LAND or (_prev_loc == Loc.CLIMB and _prev_land_climb)
	var move := Vector2.ZERO
	if on_land and was_land:
		move = _lpos - _prev_lpos
	elif not on_land and not was_land:
		move = _screen_of_ship(_ppos - _prev_ppos)
	var helm_dir := _screen_of_ship(Vector2(1.0, 0.0))
	var air := 0
	if _jump_wind > 0.0:
		air = 3
	elif _pz > 0.03 and (_loc == Loc.SHIP or _loc == Loc.LAND):
		air = 1
	elif _land_t > 0.0:
		air = 2
	var climbing: bool = _loc == Loc.CLIMB and _climb.get("kind") == "mast"
	_sprite.drive(delta, move, _carrying, _loc == Loc.SHIP and _mode == Mode.HELM, helm_dir, air, climbing, helm_dir)
	_prev_ppos = _ppos
	_prev_lpos = _lpos
	_prev_loc = _loc
	_prev_land_climb = on_land and _loc == Loc.CLIMB
	for id in _remotes:
		var r: Dictionary = _remotes[id]
		var p: Vector2 = r["pos"]
		var loc: int = r["loc"]
		var d := p - (r["prev"] as Vector2)
		var m := d if loc == 1 else _screen_of_ship(d)
		var rair := 1 if (float(r["pz"]) > 0.05 and (loc == 0 or loc == 1)) else 0
		(r["sprite"] as PirateSprite).drive(delta, m, (r["ball"] as MeshInstance3D).visible,
				loc == 0 and _helm_owner == id, helm_dir, rair, loc == 2, helm_dir)
		r["prev"] = p


## Un joueur est parti : son pirate disparaît, et la barre se libère s'il la tenait.
func on_peer_left(id: int) -> void:
	if _remotes.has(id):
		for key in ["sprite", "blob"]:
			(_remotes[id][key] as Node).queue_free()
		_remotes.erase(id)
	if _helm_owner == id:
		_helm_owner = 0
		_sim.rudder_target = 0.0


## L'hôte est parti : on continue seul sur le bateau.
func on_host_left() -> void:
	for id in _remotes.keys():
		on_peer_left(id)
	_helm_owner = _my_id() if _mode == Mode.HELM else 0
	_net_target = {}


func on_peers_changed() -> void:
	pass


func _player_world() -> Vector3:
	if _loc == Loc.LAND or (_loc == Loc.CLIMB and _climb.get("kind") == "hull"):
		return _land_point(_lpos, 0.9)
	return _ship_point(_ppos, 0.9)


func _update_camera(delta: float) -> void:
	# La caméra suit le bateau (fixe à l'origine) plus le décalage du pirate sur le pont, en douceur.
	# Caméra au sous-pixel : la 3D est rendue avec une caméra calée sur la grille de pixels (donc pas
	# de scintillement), puis l'image finale est décalée de la fraction de pixel restante, à
	# l'échelle de l'écran. Les déplacements paraissent continus au lieu d'avancer par sauts de
	# 2 ou 3 pixels d'écran.
	var rel := _player_world() - _ship.position
	# en haut du mât (échelle, nid de pie), la caméra monte avec le pirate ; pour un saut elle ne bouge pas
	var cam_h := _pz if (_loc == Loc.NEST or (_loc == Loc.CLIMB and _climb.get("kind") == "mast")) else 0.0
	_cam_offset = _cam_offset.lerp(Vector3(rel.x, cam_h, rel.z), 1.0 - exp(-delta * 6.0))
	var el := deg_to_rad(ELEVATION_DEG)
	var focus_exact := Vector3(_ship.position.x, 1.2, _ship.position.z) + _cam_offset
	if _args.has("cam-world"):  # diagnostic : regarder un point précis du monde (ex. la ville)
		var parts := str(_args["cam-world"]).split(",")
		focus_exact = Vector3(float(parts[0]) - _world_origin.x, 1.2, float(parts[1]) - _world_origin.z)
	var focus := _snap_ground(focus_exact)
	_cam_focus = focus
	_cam.position = focus + Vector3(0, sin(el), cos(el)) * 60.0
	var frac_px := Vector2((focus_exact.x - focus.x) * PIXELS_PER_METER,
			(focus_exact.z - focus.z) * sin(el) * PIXELS_PER_METER)
	_container.position = Vector2(-_factor, -_factor) - frac_px * float(_factor)
	_sea.position = Vector3(snappedf(_world_origin.x + focus.x, 1.0), SEA_Y, snappedf(_world_origin.z + focus.z, 1.0))


## Cale une position au sol sur la grille de pixels de l'écran (x : 1 px ; z : 1 px vertical).
func _snap_ground(v: Vector3) -> Vector3:
	var grid_x := 1.0 / PIXELS_PER_METER
	var grid_z := 1.0 / (PIXELS_PER_METER * sin(deg_to_rad(ELEVATION_DEG)))
	return Vector3(snappedf(v.x, grid_x), v.y, snappedf(v.z, grid_z))


# ------------------------------------------------------------------ interactions


func _nearest_interactable() -> Dictionary:
	var best: Dictionary = {}
	var best_d := INTERACT_RANGE
	for it: Dictionary in _interactables:
		var d := _ppos.distance_to(it["pos"] as Vector2)
		if d < best_d:
			best_d = d
			best = it
	return best


func _unhandled_input(event: InputEvent) -> void:
	if _ship == null or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_E:
		_interact(false)
	elif key.physical_keycode == KEY_R:
		_interact(true)
	elif key.physical_keycode == KEY_SPACE:
		_try_jump()


func _interact(secondary: bool) -> void:
	if _loc == Loc.CLIMB:
		return
	if _loc == Loc.NEST:
		if not secondary:
			_start_mast_climb(false)
		return
	if _loc == Loc.LAND:
		if not secondary:
			_try_board()
		return
	if _mode == Mode.HELM:
		if not secondary:
			_leave_helm()
		return
	var it := _nearest_interactable()
	if it.is_empty():
		return
	match it["kind"]:
		"ladder":
			if not secondary:
				_try_disembark(int(it["index"]))
		"mastladder":
			if not secondary:
				_start_mast_climb(true)
		"helm":
			if not secondary and (_helm_owner == 0 or _helm_owner == _my_id()):
				_request("helm_take", 0)
				_enter_helm()
		"mast":
			_request("sail", -1 if secondary else 1)
		"anchor":
			if not secondary:
				_request("anchor", 0)
		"ammo":
			if not secondary and not _carrying:
				_carrying = true
				_ball_icon.visible = true
		"cannon":
			var i: int = it["index"]
			if _cannon_loaded[i]:
				if not secondary:
					_request("fire", i)
			elif _carrying and not secondary:
				_request("load", i)
				_cannon_loaded[i] = true  # affichage immédiat ; l'hôte confirme dans son état
				_carrying = false
				_ball_icon.visible = false


## Envoie une action d'équipage : appliquée directement en solo ou chez l'hôte, demandée à
## l'hôte pour un client.
func _request(kind: String, value: int) -> void:
	if _net.active and not _net.is_host:
		_net.send_request(kind, value)
	else:
		apply_request(_my_id(), kind, value)


## Hôte (ou solo) : vérifie et applique une action d'un membre d'équipage. L'hôte fait autorité.
func apply_request(peer: int, kind: String, value: int) -> void:
	if _ship == null:
		return
	match kind:
		"helm_take":
			if _helm_owner == 0 or _helm_owner == peer:
				_helm_owner = peer
		"helm_leave":
			if _helm_owner == peer:
				_helm_owner = 0
				_sim.rudder_target = 0.0
		"rudder":
			if _helm_owner == peer:
				_sim.rudder_target = clampf(value / 100.0, -1.0, 1.0)
		"sail":
			_sim.sail_level = clampi(_sim.sail_level + signi(value), 0, ShipSim.SAIL_LEVELS)
		"anchor":
			_sim.anchored = not _sim.anchored
		"load":
			if value >= 0 and value < _cannon_loaded.size():
				_cannon_loaded[value] = true
		"fire":
			if value >= 0 and value < _cannon_loaded.size() and _cannon_loaded[value]:
				_cannon_loaded[value] = false
				if _net.active:
					_net.broadcast_fire(value)
				else:
					fire_visual(value)


func _my_id() -> int:
	return multiplayer.get_unique_id() if _net != null and _net.active else 1


## Tous les joueurs (moi compris), triés : la place dans cette liste donne la couleur du pirate.
func _crew_ids() -> Array:
	var ids: Array = [_my_id()]
	if _net != null and _net.active and multiplayer.multiplayer_peer != null:
		for p in multiplayer.get_peers():
			ids.append(p)
	ids.sort()
	return ids


func _enter_helm() -> void:
	var helm: Array = _ship.meta.get("helm", [0.0, 0.0])
	_mode = Mode.HELM
	_ppos = Vector2(float(helm[0]) - 0.55, float(helm[1]))
	_walkto = Vector2.INF


func _leave_helm() -> void:
	_mode = Mode.WALK
	_rudder_sent = 0.0
	_ppos = _ship.nearest_walkable(_ppos)   # derrière la roue on est coincé dans l'obstacle : on se dégage
	_request("helm_leave", 0)


## Fait partir le boulet du canon `i` (éclair, boulet, éclaboussure). Appelé chez tout le monde.
func fire_visual(i: int) -> void:
	if _ship == null or i < 0 or i >= _ship.cannons.size():
		return
	_cannon_loaded[i] = false
	var c: Array = _ship.cannons[i]
	var side := float(c[2])
	var out_local := Vector3(0.0, 0.0, -side)
	var pos_local := Vector3((float(c[0]) + _ship.shift) * ShipModel.SCALE, float(c[3]) * ShipModel.SCALE, -float(c[1]) * ShipModel.SCALE)
	var muzzle := _ship.to_global(pos_local + out_local * 0.9)
	var dir := (_ship.global_transform.basis * out_local).normalized()
	var fwd := _sim.forward()
	var vel := dir * 28.0 + Vector3.UP * 5.0 + Vector3(fwd.x, 0.0, fwd.y) * _sim.speed
	var ball := _make_ball(0.16, Color(0.10, 0.10, 0.14))
	_world_fixed.add_child(ball)
	ball.global_position = muzzle
	_projectiles.append({"node": ball, "vel": vel, "age": 0.0})
	# éclair de bouche
	var flash := _make_ball(0.32, Color(1.0, 0.7, 0.3))
	(flash.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_world.add_child(flash)
	flash.global_position = muzzle
	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector3.ZERO, 0.18)
	tw.tween_callback(flash.queue_free)


func _update_projectiles(delta: float) -> void:
	for i in range(_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _projectiles[i]
		var node: MeshInstance3D = p["node"]
		var vel: Vector3 = p["vel"]
		vel.y -= 16.0 * delta
		p["vel"] = vel
		p["age"] = float(p["age"]) + delta
		node.position += vel * delta
		if node.position.y < SEA_Y or float(p["age"]) > 8.0:
			_splash(Vector3(node.position.x, SEA_Y + 0.05, node.position.z))
			node.queue_free()
			_projectiles.remove_at(i)


func _splash(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 0.05
	ring.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.92, 0.95, 1.0, 0.9)
	ring.material_override = m
	_world_fixed.add_child(ring)
	ring.position = at
	ring.scale = Vector3(0.3, 1.0, 0.3)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 0.7)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(ring.queue_free)


# ------------------------------------------------------------------ interface


func _update_hud() -> void:
	var a := _sim.wind_alignment()
	var wind := "vent arrière" if a > 0.55 else ("vent de travers" if a > -0.25 else ("vent debout" if a < -0.75 else "vent de face"))
	_hud.text = "Vitesse %.1f nœuds   Voiles %d/%d   Ancre : %s   Barre %+.1f   %s (rendement %d %%)" % [
		_sim.speed * 1.944, _sim.sail_level, ShipSim.SAIL_LEVELS, "jetée" if _sim.anchored else "levée",
		_sim.rudder, wind, int(_sim.wind_factor() * 100.0)]
	if _net.active:
		_hud.text += "\nÉquipage : %d / %d%s" % [_remotes.size() + 1, SailingNet.MAX_PLAYERS,
				"   (barre tenue par un ami)" if _helm_owner != 0 and _helm_owner != _my_id() else ""]
	if _notice_t > 0.0:
		_prompt.text = _notice
		return
	if _loc == Loc.NEST:
		_prompt.text = "Dans le nid de pie — E : redescendre"
		return
	if _loc == Loc.CLIMB:
		_prompt.text = ""
		return
	if _loc == Loc.LAND:
		_prompt.text = "E : monter à bord   Espace : sauter" if _nearest_ship_ladder_from_land() >= 0 else "Espace : sauter"
		return
	if _mode == Mode.HELM:
		_prompt.text = "À la barre : gauche/droite pour virer — E : lâcher la barre"
		return
	var it := _nearest_interactable()
	if it.is_empty():
		_prompt.text = ""
		return
	match it["kind"]:
		"ladder":
			_prompt.text = "E : descendre sur le quai (échelle)"
		"mastladder":
			_prompt.text = "E : grimper au nid de pie"
		"helm":
			_prompt.text = "E : prendre la barre"
		"mast":
			_prompt.text = "E : hisser   R : affaler   (voiles %d/%d)" % [_sim.sail_level, ShipSim.SAIL_LEVELS]
		"anchor":
			_prompt.text = "E : lever l'ancre" if _sim.anchored else "E : jeter l'ancre"
		"ammo":
			_prompt.text = "Tu portes déjà un boulet" if _carrying else "E : prendre un boulet"
		"cannon":
			var i: int = it["index"]
			if _cannon_loaded[i]:
				_prompt.text = "E : tirer"
			elif _carrying:
				_prompt.text = "E : charger le canon"
			else:
				_prompt.text = "Il faut un boulet (tonneau sur le pont)"
