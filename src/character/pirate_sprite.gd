class_name PirateSprite
extends Sprite3D
## Un pirate à l'écran : les couches de son apparence (tools/art/blender/make_pirate.py) sont recolorées puis
## empilées en une feuille par animation (colonne = image, ligne = direction), et ce sprite joue la bonne
## image selon le déplacement. Toujours de face à la caméra (billboard), pieds sur le point du noeud.

const FPS := {"idle": 3.0, "walk": 9.0, "carry_idle": 3.0, "carry_walk": 9.0, "helm": 1.0, "climb": 5.0, "jump": 1.0}
const PIXELS_PER_METER := 24.0
const SHEET_DIR := "res://assets/art/characters/pirate/"

static var _cache: Dictionary = {}     ## clé (look + animation) -> Texture2D
static var _building: Dictionary = {}  ## clé -> true pendant la composition
## Couleurs exactes de tous les pirates à l'écran, pour que le filtre « palette » ne les déforme pas.
static var palette_colors: Array[Color] = []
static var palette_version := 0
const PALETTE_MAX := 512

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
				var col := Color(roundf(float(t) * 255.0) / 255.0 * tint.r, roundf(float(t) * 255.0) / 255.0 * tint.g,
						roundf(float(t) * 255.0) / 255.0 * tint.b)
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
			rect.modulate = Color.html(color_spec if color_spec.begins_with("#") else p_look["colors"][color_spec])
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
