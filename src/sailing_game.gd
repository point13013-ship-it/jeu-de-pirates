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
const ELEVATION_DEG := 52.0
const SEA_Y := -1.45
const WALK_SPEED := 3.6
const INTERACT_RANGE := 1.5
const STATS_PATH := "res://data/ship_stats.json"

enum Mode { WALK, HELM }

var _args: Dictionary = {}
var _ship: ShipModel
var _sim := ShipSim.new()
var _world: Node3D
var _cam: Camera3D
var _sea: MeshInstance3D
var _sprite: Sprite3D
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
	var ship_name := str(_args.get("ship", "brigantin"))
	_ship = ShipModel.new()
	if not _ship.load_ship(ship_name):
		push_error("Bateau introuvable : %s" % ship_name)
		return
	_world.add_child(_ship)
	_sim.configure(_load_stats(ship_name))
	_sim.yaw = deg_to_rad(float(_args.get("yaw", "0")))
	_build_blob()
	_build_player()
	_build_interactables()
	_build_hud()
	_apply_test_args()
	_float_ship()
	var rel0 := _player_world() - _ship.position
	_cam_offset = Vector3(rel0.x, 0.0, rel0.z)


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
	_post_rect.material = mat
	_post_vp.add_child(_post_rect)
	resized.connect(_layout_view)
	_layout_view.call_deferred()

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.10, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.40, 0.68)
	env.ambient_light_energy = 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_world.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -40, 0)
	sun.light_color = Color(1.0, 0.72, 0.52)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.5
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
	# seconde, visible à 144 images/s). Le même temps sert à l'eau et à la flottaison.
	_sea_t = _time
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
	_sprite = Sprite3D.new()
	var tex := load("res://assets/art/characters/pirate_red.png") as Texture2D
	_sprite.texture = tex
	_sprite.pixel_size = 1.0 / PIXELS_PER_METER
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.offset = Vector2(0, tex.get_height() / 2.0)
	_ship.add_child(_sprite)
	_ball_icon = _make_ball(0.14, Color(0.12, 0.12, 0.16))
	_ball_icon.visible = false
	_sprite.add_child(_ball_icon)
	_ball_icon.position = Vector3(0.0, 2.2, 0.0)
	# point de départ : devant la porte de la cabine
	var cabin := _ship.cabin
	_ppos = Vector2(float(cabin.get("door_x", 0.0)) + 0.9, 0.7)
	if _args.has("player"):
		var parts := str(_args["player"]).split(",")
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
		_enter_helm()
	if _args.has("fire"):
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			for i in _ship.cannons.size():
				_cannon_loaded[i] = true
				_fire(i))
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
	_sim.step(delta)
	_float_ship()
	_ship.set_sail_open(_sim.sail_open)
	_sprite.position = _ship.to_local3(_ppos, 0.02)
	_blob.position = _ship.to_local3(_ppos, 0.04)
	_ship.update_cutaway(_ship.inside_cabin(_ppos))
	_update_projectiles(delta)
	_update_camera(delta)
	_snap_sprite()
	_update_hud()
	if _args.has("log"):
		_log_timer += delta
		if _log_timer >= 1.0:
			_log_timer = 0.0
			print("[etat] fps=%d t=%.1f pos=(%.1f, %.1f) cap=%.0f° vitesse=%.2f voiles=%.2f barre=%.2f joueur=(%.2f, %.2f) cabine=%s" % [
				Engine.get_frames_per_second(), _time, _sim.position.x, _sim.position.y, rad_to_deg(_sim.yaw), _sim.speed, _sim.sail_open,
				_sim.rudder, _ppos.x, _ppos.y, str(_ship.inside_cabin(_ppos))])


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
	var move := Vector2(_axis([KEY_A, KEY_LEFT], [KEY_D, KEY_RIGHT]), _axis([KEY_W, KEY_UP], [KEY_S, KEY_DOWN]))
	if _mode == Mode.HELM:
		_sim.rudder_target = move.x
		return
	var step_units := WALK_SPEED / ShipModel.SCALE * delta
	if _walkto != Vector2.INF:
		var d := _walkto - _ppos
		if d.length() > 0.04:
			_ppos = _ship.move_with_slide(_ppos, d.normalized() * minf(step_units, d.length()))
		return
	if move == Vector2.ZERO:
		return
	if move.x != 0.0:
		_sprite.flip_h = move.x < 0.0
	# direction d'écran (x vers la droite, y vers le bas) -> repère local du bateau -> repère du modèle
	var world_dir := Vector3(move.x, 0.0, move.y).normalized()
	var local := _ship.global_transform.basis.inverse() * world_dir
	var dir := Vector2(local.x, -local.z).normalized()
	_ppos = _ship.move_with_slide(_ppos, dir * step_units)


## Cale le sprite sur la grille de pixels de l'écran : sinon ses pixels « vibrent » quand il bouge.
func _snap_sprite() -> void:
	var basis := _cam.global_transform.basis
	var right := basis.x
	var up := basis.y
	var g := _sprite.global_position
	var d := g - _cam.global_position
	var dr := d.dot(right)
	var du := d.dot(up)
	g += right * (roundf(dr * PIXELS_PER_METER) / PIXELS_PER_METER - dr)
	g += up * (roundf(du * PIXELS_PER_METER) / PIXELS_PER_METER - du)
	_sprite.global_position = g


func _player_world() -> Vector3:
	return _ship.to_global(_ship.to_local3(_ppos, 0.9))


func _update_camera(delta: float) -> void:
	# La caméra suit le bateau (fixe à l'origine) plus le décalage du pirate sur le pont, en douceur.
	# Caméra au sous-pixel : la 3D est rendue avec une caméra calée sur la grille de pixels (donc pas
	# de scintillement), puis l'image finale est décalée de la fraction de pixel restante, à
	# l'échelle de l'écran. Les déplacements paraissent continus au lieu d'avancer par sauts de
	# 2 ou 3 pixels d'écran.
	var rel := _player_world() - _ship.position
	_cam_offset = _cam_offset.lerp(Vector3(rel.x, 0.0, rel.z), 1.0 - exp(-delta * 6.0))
	var el := deg_to_rad(ELEVATION_DEG)
	var focus_exact := Vector3(_ship.position.x, 1.2, _ship.position.z) + _cam_offset
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


func _interact(secondary: bool) -> void:
	if _mode == Mode.HELM:
		if not secondary:
			_mode = Mode.WALK
			_sim.rudder_target = 0.0
		return
	var it := _nearest_interactable()
	if it.is_empty():
		return
	match it["kind"]:
		"helm":
			if not secondary:
				_enter_helm()
		"mast":
			_sim.sail_level = clampi(_sim.sail_level + (-1 if secondary else 1), 0, ShipSim.SAIL_LEVELS)
		"anchor":
			if not secondary:
				_sim.anchored = not _sim.anchored
		"ammo":
			if not secondary and not _carrying:
				_carrying = true
				_ball_icon.visible = true
		"cannon":
			var i: int = it["index"]
			if _cannon_loaded[i]:
				if not secondary:
					_fire(i)
			elif _carrying and not secondary:
				_cannon_loaded[i] = true
				_cannon_icons[i].visible = true
				_carrying = false
				_ball_icon.visible = false


func _enter_helm() -> void:
	var helm: Array = _ship.meta.get("helm", [0.0, 0.0])
	_mode = Mode.HELM
	_ppos = Vector2(float(helm[0]) - 0.55, float(helm[1]))
	_walkto = Vector2.INF


func _fire(i: int) -> void:
	_cannon_loaded[i] = false
	_cannon_icons[i].visible = false
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
	if _mode == Mode.HELM:
		_prompt.text = "À la barre : gauche/droite pour virer — E : lâcher la barre"
		return
	var it := _nearest_interactable()
	if it.is_empty():
		_prompt.text = ""
		return
	match it["kind"]:
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
