extends Control
## Banc d'essai du rendu « 3D basse résolution façon pixel art » :
## un navire en 3D à l'échelle des personnages, deux pirates en sprites sur le pont,
## une mer, et le filtre pixel_look (palette du port, tramage, contours).
## Arguments (après « -- ») : --ship=sloop|brigantin|galion --angle=deg --shot=chemin
## --shot-after-secs=s --quit-after-secs=s

const PIXELS_PER_METER := 18.0
const VIEW_SIZE := Vector2i(480, 270)
const ELEVATION_DEG := 52.0
const SHIP_SCALE := 1.5
const SEA_Y := -1.9
const CREW := {
	# nom du fichier -> position en fraction de la longueur (x) et de la largeur (y) du bateau,
	# dans le repère d'origine du modèle (avant recentrage et échelle)
	"pirate_red": Vector2(0.17, -0.20),
	"pirate_blue": Vector2(-0.10, 0.22),
}

var _ship_root: Node3D
var _auto_turn := true


func _ready() -> void:
	var args := _parse_args()
	var ship_name: String = str(args.get("ship", "galion"))
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = 2
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/pixel_look.gdshader")
	container.material = mat
	add_child(container)

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	container.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.10, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.40, 0.68)
	env.ambient_light_energy = 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -40, 0)
	sun.light_color = Color(1.0, 0.72, 0.52)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.5
	sun.directional_shadow_max_distance = 70.0
	world.add_child(sun)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(VIEW_SIZE.y) / PIXELS_PER_METER
	cam.near = 0.1
	cam.far = 200.0
	var el := deg_to_rad(ELEVATION_DEG)
	var target := Vector3(0, 1.2, 0)
	cam.position = target + Vector3(0, sin(el), cos(el)) * 60.0
	cam.rotation_degrees = Vector3(-ELEVATION_DEG, 0, 0)
	world.add_child(cam)

	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	sea.mesh = plane
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	sea.material_override = water
	sea.position.y = SEA_Y
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(sea)

	_ship_root = Node3D.new()
	world.add_child(_ship_root)
	var meta := _load_meta(ship_name)
	var model: Node3D = (load("res://assets/models/ship/%s.glb" % ship_name) as PackedScene).instantiate()
	model.scale = Vector3.ONE * SHIP_SCALE
	_ship_root.add_child(model)
	model.visible = not args.has("nomodel")

	var length: float = meta.get("length", 16.0)
	var shift: float = meta.get("shift", 0.0)
	var beam: float = meta.get("beam", 5.0)
	for crew_name: String in CREW:
		var frac: Vector2 = CREW[crew_name]
		var spot := Vector2(frac.x * length, frac.y * beam)
		var u := clampf((spot.x + length / 2.0 - shift * 0.0) / length, 0.0, 1.0)
		# hauteur du pont à cet endroit (même formule que le modèle)
		var deck := (0.62 * pow(u, 2.2) + 0.34 * pow(1.0 - u, 2.5)) * (length / 13.0)
		var sprite := Sprite3D.new()
		var tex: Texture2D = load("res://assets/art/characters/%s.png" % crew_name)
		sprite.texture = tex
		sprite.pixel_size = 1.0 / PIXELS_PER_METER
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.offset = Vector2(0, tex.get_height() / 2.0)
		sprite.position = Vector3((spot.x + shift) * SHIP_SCALE, deck * SHIP_SCALE + 0.05, -spot.y * SHIP_SCALE)
		_ship_root.add_child(sprite)

	if args.has("angle"):
		_auto_turn = false
		_ship_root.rotation_degrees.y = -float(args["angle"])
	if args.has("shot"):
		get_tree().create_timer(float(args.get("shot-after-secs", "2"))).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(str(args["shot"])))
	if args.has("quit-after-secs"):
		get_tree().create_timer(float(args["quit-after-secs"])).timeout.connect(get_tree().quit)


func _process(delta: float) -> void:
	if _auto_turn:
		_ship_root.rotation.y -= delta * 0.4
	_ship_root.position.y = sin(Time.get_ticks_msec() / 900.0) * 0.06


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else true
	return out


func _load_meta(ship_name: String) -> Dictionary:
	var f := FileAccess.open("res://assets/models/ship/%s_meta.json" % ship_name, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
