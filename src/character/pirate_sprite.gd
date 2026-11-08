class_name PirateSprite
extends Sprite3D
## Un pirate à l'écran : les couches de son apparence (tools/art/blender/make_pirate.py) sont recolorées puis
## empilées en une feuille par animation (colonne = image, ligne = direction), et ce sprite joue la bonne
## image selon le déplacement. Toujours de face à la caméra (billboard), pieds sur le point du noeud.

const FPS := {"idle": 3.0, "walk": 9.0, "carry_idle": 3.0, "carry_walk": 9.0, "helm": 1.0, "climb": 5.0, "jump": 1.0}
const PIXELS_PER_METER := 36.0
const SHEET_DIR := "res://assets/art/characters/pirate/"

static var _cache: Dictionary = {}     ## clé (look + animation) -> Texture2D
static var _building: Dictionary = {}  ## clé -> true pendant la composition
## Couleurs exactes de tous les pirates à l'écran, pour que le filtre « palette » ne les déforme pas.
static var palette_colors: Array[Color] = []
static var palette_version := 0
const PALETTE_MAX := 512

## Ombrage « peint » : les feuilles de sprites sont en niveaux de gris (le ton d'ombre de chaque pixel), et la couleur d'une
## pièce en est tirée ici : les ombres tirent vers le violet froid, les lumières vers le chaud (comme dans Eastward), au lieu
## d'un simple assombrissement. La même formule est dans SHADE_SHADER et dans tools/art/pixel_build.py (aperçus).
const SHADOW_TINT := Color(0.10, 0.06, 0.28)
const LIGHT_TINT := Color(0.07, 0.045, 0.0)
const SHADE_SHADER := """
shader_type canvas_item;
uniform vec3 tint;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = tex.r;
	float s = 1.0 - t;
	vec3 c = tint * t * 1.12 * (1.0 - s * 0.35) + vec3(0.10, 0.06, 0.28) * s * 0.30
			+ vec3(0.07, 0.045, 0.0) * max(0.0, t - 0.88) / 0.12;
	COLOR = vec4(clamp(c, 0.0, 1.0), tex.a);
}
"""
static var _shade_shader: Shader
static var _shade_materials: Dictionary = {}   ## teinte -> ShaderMaterial

var look: Dictionary = {}
var anim := "idle"
var direction := 0
var _time := 0.0
var _forced_frame := -1
var _textures: Dictionary = {}   ## animation -> Texture2D


func _init() -> void:
	pixel_size = 1.0 / PIXELS_PER_METER
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	vframes = 8
	var feet: Array = PirateLook.catalog().get("feet", [24, 54])
	var frame_size: Array = PirateLook.catalog().get("frame", [48, 64])
	offset = Vector2(0.0, float(feet[1]) - float(frame_size[1]) / 2.0)   # les pieds tombent sur l'origine du noeud


## Direction (0 = vers la caméra, puis tous les 45° vers la droite de l'écran) d'un vecteur d'écran
## (x vers la droite, y vers le bas).
static func direction_of(v: Vector2) -> int:
	return posmod(roundi(atan2(v.x, v.y) / (PI / 4.0)), 8)


func set_look(new_look: Dictionary) -> void:
	look = PirateLook.sanitize(new_look)
	_textures.clear()
	var key := PirateLook.key(look)
	for a: String in FPS:
		_request(a, key)


## Appelé à chaque image : `screen_move` = déplacement d'écran de cette image (zéro si immobile).
## `air` : 0 au sol, 3 accroupi avant le saut, 1 en l'air, 2 à la réception. `climbing` : sur une échelle,
## face à `face_dir`.
func drive(delta: float, screen_move: Vector2, carrying: bool, at_helm: bool, helm_dir: Vector2,
		air: int = 0, climbing: bool = false, face_dir: Vector2 = Vector2.ZERO) -> void:
	var next := anim
	_forced_frame = -1
	if air > 0:
		next = "jump"
		_forced_frame = {3: 0, 1: 1, 2: 2}[air]
		if screen_move.length() > 0.0005:
			direction = direction_of(screen_move)
	elif climbing:
		next = "climb"
		direction = direction_of(face_dir)
	elif at_helm:
		next = "helm"
		direction = direction_of(helm_dir)
	elif screen_move.length() > 0.0005:
		direction = direction_of(screen_move)
		next = "carry_walk" if carrying else "walk"
	else:
		next = "carry_idle" if carrying else "idle"
	if next != anim:
		if not (next.ends_with("walk") and anim.ends_with("walk")):
			_time = 0.0
		anim = next
	_time += delta * float(FPS[anim])
	_apply()


func _request(a: String, key: String) -> void:
	var tex: Texture2D = await texture_for(look, a)
	if tex == null or not is_instance_valid(self) or PirateLook.key(look) != key:
		return
	_textures[a] = tex
	_apply()


func _apply() -> void:
	var used := anim if _textures.has(anim) else "idle"
	var tex: Texture2D = _textures.get(used)
	if tex == null:
		visible = false
		return
	visible = true
	var frames: int = int(PirateLook.catalog()["anims"][used])
	if hframes != frames:
		hframes = frames
	if texture != tex:
		texture = tex
	frame = direction * frames + (_forced_frame if _forced_frame >= 0 else int(_time) % frames)
	_update_compass()


## La feuille d'une animation pour un look : calculée une fois puis gardée.
static func texture_for(p_look: Dictionary, a: String) -> Texture2D:
	if not PirateLook.catalog().get("anims", {}).has(a):
		return null
	var key := PirateLook.key(p_look) + "|" + a
	var tree := Engine.get_main_loop() as SceneTree
	if _cache.has(key):
		return _cache[key]
	if _building.has(key):
		while not _cache.has(key):
			await tree.process_frame
		return _cache[key]
	_building[key] = true
	register_colors(PirateLook.sanitize(p_look))
	var tex: Texture2D = await _compose(PirateLook.sanitize(p_look), a)
	_cache[key] = tex
	_building.erase(key)
	return tex


## La couleur d'un pixel de ton `t` (gris de la feuille, 0..1) pour une pièce de teinte `tint`.
static func shade(tint: Color, t: float) -> Color:
	var s := 1.0 - t
	var c := Color(tint.r, tint.g, tint.b) * t * 1.12 * (1.0 - s * 0.35) + SHADOW_TINT * s * 0.30 			+ LIGHT_TINT * (maxf(0.0, t - 0.88) / 0.12)
	return Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0), 1.0)


static func _shade_material(tint: Color) -> ShaderMaterial:
	var key := tint.to_html(false)
	if not _shade_materials.has(key):
		if _shade_shader == null:
			_shade_shader = Shader.new()
			_shade_shader.code = SHADE_SHADER
		var m := ShaderMaterial.new()
		m.shader = _shade_shader
		m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		_shade_materials[key] = m
	return _shade_materials[key]


## Ajoute à la palette « pirates » les couleurs qu'un look produit : chaque teinte × chacun des tons de gris.
static func register_colors(p_look: Dictionary) -> void:
	var cat := PirateLook.catalog()
	var tones: Array = cat.get("tones", [1.0])
	var added := false
	for c: String in cat["order"]:
		var variant: String = p_look["parts"].get(c, "none")
		for lay: Dictionary in cat["parts"][c]["layers"].get(variant, []):
			var spec: String = lay["color"]
			var tint := Color.html(spec if spec.begins_with("#") else p_look["colors"][spec])
			for t in tones:
				var col := shade(tint, roundf(float(t) * 255.0) / 255.0)
				col = Color.from_rgba8(col.r8, col.g8, col.b8)
				if palette_colors.size() < PALETTE_MAX and not palette_colors.has(col):
					palette_colors.append(col)
					added = true
	if added:
		palette_version += 1


## La palette des pirates sous forme de texture (une ligne de pixels) pour le filtre.
static func palette_texture() -> Texture2D:
	var img := Image.create(PALETTE_MAX, 1, false, Image.FORMAT_RGB8)
	for i in palette_colors.size():
		img.set_pixel(i, 0, palette_colors[i])
	return ImageTexture.create_from_image(img)


static func _compose(p_look: Dictionary, a: String) -> Texture2D:
	var cat := PirateLook.catalog()
	var frame_size: Array = cat["frame"]
	var frames: int = int(cat["anims"][a])
	var vp := SubViewport.new()
	vp.size = Vector2i(frames * int(frame_size[0]), 8 * int(frame_size[1]))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	for c: String in cat["order"]:
		var variant: String = p_look["parts"].get(c, "none")
		if variant == "none":
			continue
		for lay: Dictionary in cat["parts"][c]["layers"].get(variant, []):
			var path: String = SHEET_DIR + a + "/" + str(lay["id"]) + ".png"
			if not ResourceLoader.exists(path):
				continue
			var color_spec: String = lay["color"]
			var rect := TextureRect.new()
			rect.texture = load(path)
			rect.stretch_mode = TextureRect.STRETCH_KEEP
			rect.material = _shade_material(Color.html(color_spec if color_spec.begins_with("#") else p_look["colors"][color_spec]))
			vp.add_child(rect)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child.call_deferred(vp)
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if OS.has_environment("PIRATE_DEBUG"):
		img.save_png(OS.get_environment("PIRATE_DEBUG") + "/sheet_" + a + ".png")
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ la boussole en main

## Une petite boussole tenue à la main : l'aiguille rouge montre le nord (le haut de l'écran, comme sur la carte des mers),
## et un point doré montre le cap à suivre (quête ou île choisie) quand il y en a un. Posée à la hanche, côté de la main
## droite selon la direction du pirate ; masquée quand les mains sont prises (tonneau, barre, échelle, saut).
const COMPASS_W := 13
const COMPASS_H := 10
const COMPASS_HAND_Y := 23.0    ## px au-dessus des pieds
## par direction (0 = vers la caméra, puis vers la droite de l'écran) : [décalage x en px, devant le corps ?]
const COMPASS_SIDE := [[-9.0, true], [-8.0, true], [-3.0, true], [6.0, false], [9.0, false], [8.0, false], [3.0, false], [-6.0, true]]
const COMPASS_ELEVATION := 40.0     ## degrés : inclinaison de la caméra
const C_BRASS := Color(0.78, 0.58, 0.18)
const C_BRASS_D := Color(0.5, 0.34, 0.1)
const C_FACE := Color(0.95, 0.9, 0.72)
const C_NORTH := Color(0.82, 0.12, 0.1)
const C_SOUTH := Color(0.98, 0.98, 0.96)
const C_GOAL := Color(0.2, 0.62, 0.95)

## Direction (vecteur monde x/z) du cap à suivre, ou zéro : réglée par le jeu pour mon pirate.
var compass_goal := Vector2.ZERO
var compass_enabled := true
var _compass: Sprite3D
var _compass_key := Vector3i(-99, -99, -99)


func _update_compass() -> void:
	var show_it := compass_enabled and anim in ["idle", "walk"] and visible
	if not show_it:
		if _compass != null:
			_compass.visible = false
		return
	if _compass == null:
		_compass = Sprite3D.new()
		_compass.pixel_size = 1.0 / PIXELS_PER_METER
		_compass.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_compass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_compass.shaded = false
		_compass.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_compass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_compass)
		_register_compass_colors()
	_compass.visible = true
	# place : décalage d'écran (x droite, y haut) converti en axes du monde, un peu devant ou derrière le corps
	var side: Array = COMPASS_SIDE[direction]
	var e := deg_to_rad(COMPASS_ELEVATION)
	var up := Vector3(0.0, cos(e), -sin(e))        # le haut de l'écran
	var toward := Vector3(0.0, sin(e), cos(e))     # vers la caméra
	# le décalage est calculé dans le monde (la caméra est fixe) puis converti dans le repère du pirate, qui peut être
	# tourné (pont du bateau) : sans cela la boussole tombe à côté de la main
	var world_offset := Vector3(float(side[0]) / PIXELS_PER_METER, 0.0, 0.0) + up * (COMPASS_HAND_Y / PIXELS_PER_METER) \
			+ toward * (0.06 if bool(side[1]) else -0.06)
	_compass.position = global_transform.basis.orthonormalized().inverse() * world_offset
	# l'aiguille flotte un peu autour du nord ; la texture n'est refaite que quand un pixel change
	var phase := float(get_instance_id() % 17)
	var wobble := sin(Time.get_ticks_msec() / 1000.0 * 2.3 + phase) * 0.12 + sin(Time.get_ticks_msec() / 1000.0 * 5.1 + phase) * 0.05
	var needle_q := roundi(wobble * 6.0)
	var goal_q := -1 if compass_goal.length() < 0.01 else posmod(roundi(atan2(compass_goal.x, -compass_goal.y) / (TAU / 16.0)), 16)
	var key := Vector3i(needle_q, goal_q, 0)
	if key != _compass_key:
		_compass_key = key
		_compass.texture = _compass_texture(float(needle_q) / 6.0, goal_q)


static func _register_compass_colors() -> void:
	var added := false
	for c: Color in [C_BRASS, C_BRASS_D, C_FACE, C_NORTH, C_SOUTH, C_GOAL]:
		var col := Color.from_rgba8(c.r8, c.g8, c.b8)
		if palette_colors.size() < PALETTE_MAX and not palette_colors.has(col):
			palette_colors.append(col)
			added = true
	if added:
		palette_version += 1


## La boussole vue de dessus à 40° : un anneau de laiton aplati, un cadran crème, l'aiguille (rouge au nord, blanche au
## sud) et, sur l'anneau, un point bleu dans la direction du cap (`goal_q` : 0 à 15 par pas de 22,5°, -1 : pas de cap).
static func _compass_texture(needle_angle: float, goal_q: int) -> Texture2D:
	var img := Image.create(COMPASS_W, COMPASS_H, false, Image.FORMAT_RGBA8)
	var c := Vector2(COMPASS_W * 0.5 - 0.5, COMPASS_H * 0.5 - 0.5)
	var rx := COMPASS_W * 0.5 - 0.3
	var ry := COMPASS_H * 0.5 - 0.3
	for y in COMPASS_H:
		for x in COMPASS_W:
			var d := Vector2((x - c.x) / rx, (y - c.y) / ry).length()
			if d <= 1.0:
				img.set_pixel(x, y, C_BRASS if d > 0.72 else C_FACE)
			elif d <= 1.2 and y >= int(c.y):
				img.set_pixel(x, y, C_BRASS_D)   # le bord, sous la boussole
	# aiguille : du centre vers le nord (haut), tournée de `needle_angle` ; la pointe sud en face
	var dir := Vector2(sin(needle_angle), -cos(needle_angle))
	for t: float in [0.2, 0.45, 0.7]:
		var p := c + Vector2(dir.x * rx, dir.y * ry) * t * 0.9
		img.set_pixel(clampi(roundi(p.x), 0, COMPASS_W - 1), clampi(roundi(p.y), 0, COMPASS_H - 1), C_NORTH)
	for t: float in [0.2, 0.45]:
		var p := c - Vector2(dir.x * rx, dir.y * ry) * t * 0.9
		img.set_pixel(clampi(roundi(p.x), 0, COMPASS_W - 1), clampi(roundi(p.y), 0, COMPASS_H - 1), C_SOUTH)
	# point du cap sur l'anneau
	if goal_q >= 0:
		var a := TAU * float(goal_q) / 16.0
		var g := c + Vector2(sin(a) * rx * 0.86, -cos(a) * ry * 0.86)
		var gx := clampi(roundi(g.x), 0, COMPASS_W - 1)
		var gy := clampi(roundi(g.y), 0, COMPASS_H - 1)
		img.set_pixel(gx, gy, C_GOAL)
	return ImageTexture.create_from_image(img)
