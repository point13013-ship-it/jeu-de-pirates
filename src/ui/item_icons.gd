class_name ItemIcons
extends RefCounted
## Les icônes des objets du sac (12/11/2026) : de petits dessins en pixel art (32 x 32, affichés sans lissage), faits en code
## comme le reste des images du jeu. Planche, boulets, or, balles, cartouches, armes, baies, trésor, radeau, cabane…
## `icon(kind, id)` renvoie toujours une image (un parchemin roulé si l'objet est inconnu).

const N := 32
static var _cache: Dictionary = {}

const OUT := Color("1a100a")
const IRON := Color("3b3d46")
const IRON_L := Color("6d717d")
const STEEL := Color("c9d2dc")
const WOOD := Color("8a5a2b")
const WOOD_L := Color("b98552")
const WOOD_D := Color("5a3820")
const GOLD := Color("f1c040")
const GOLD_D := Color("b07d1e")
const BRASS := Color("d9a441")
const PAPER := Color("ead9b0")


static func icon(kind: String, id: String) -> Texture2D:
	var key := kind + ":" + id
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"weapon", "wskin":
			_weapon(img, id)
			if kind == "wskin":
				_brush(img)
		"berry":
			_berry(img, id)
		"craft":
			if id == "raft":
				_raft(img)
			else:
				_cabin(img)
		"treasure":
			_chest(img)
		_:
			match id:
				"gold": _coins(img)
				"balls", "ball": _balls(img)
				"planks", "plank": _planks(img)
				"bullets", "bullet": _bullets(img)
				"shells", "shell": _shells(img)
				"flint": _flint(img)
				"butt": _butt(img)
				"treasure": _chest(img)
				_: _scroll(img)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


# ------------------------------------------------------------------ 13/11 : le silex et l'emplacement « Orifice »

## Un silex : un éclat de pierre grise, taillé en pointe, avec ses facettes.
static func _flint(img: Image) -> void:
	var dark := Color("4a4f5c")
	var mid := Color("7d8494")
	var light := Color("b9c0cc")
	for y in range(5, 28):
		var k := float(y - 5) / 22.0
		var half := int(round(lerpf(1.0, 9.0, sin(k * PI * 0.62))))
		var cx := 16 + int(round((k - 0.5) * 6.0))
		for x in range(cx - half, cx + half + 1):
			var edge := x == cx - half or x == cx + half or y == 5 or y == 27
			var c := light if x < cx - half / 3 else (mid if x < cx + half / 2 else dark)
			if (x + y * 2) % 7 == 0 and not edge:
				c = c.darkened(0.18)
			img.set_pixel(clampi(x, 0, N - 1), y, OUT if edge else c)
	_line(img, Vector2(15, 7), Vector2(13, 24), 1.0, Color("dfe5ee"))


## L'emplacement vide : une paire de fesses.
static func _butt(img: Image) -> void:
	var skin := Color("e8ae84")
	_disc(img, 10.5, 16.5, 9.5, skin)
	_disc(img, 21.5, 16.5, 9.5, skin)
	_rect(img, 15, 9, 16, 25, OUT)   # la raie
	_rect(img, 16, 10, 16, 24, Color("a8694a"))


# ------------------------------------------------------------------ outils de dessin

static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, N - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, N - 1) + 1):
			img.set_pixel(x, y, c)


static func _disc(img: Image, cx: float, cy: float, r: float, c: Color, shade: bool = true) -> void:
	for y in N:
		for x in N:
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d <= r:
				var col := c
				if shade:   # lumière en haut à gauche, ombre en bas à droite, contour sombre
					var k := (x + 0.5 - cx + y + 0.5 - cy) / (r * 2.0)
					col = c.lightened(clampf(-k, 0.0, 0.5) * 0.6).darkened(clampf(k, 0.0, 0.5) * 0.7)
				if d > r - 1.0:
					col = OUT
				img.set_pixel(x, y, col)


static func _line(img: Image, a: Vector2, b: Vector2, w: float, c: Color) -> void:
	var steps := int(a.distance_to(b) * 2.0) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(steps))
		for y in range(int(p.y - w), int(p.y + w) + 1):
			for x in range(int(p.x - w), int(p.x + w) + 1):
				if x >= 0 and y >= 0 and x < N and y < N and Vector2(x + 0.5, y + 0.5).distance_to(p) <= w:
					img.set_pixel(x, y, c)


## Un trait avec contour (on dessine le contour plus large, puis la couleur par-dessus).
static func _stroke(img: Image, a: Vector2, b: Vector2, w: float, c: Color) -> void:
	_line(img, a, b, w + 1.0, OUT)
	_line(img, a, b, w, c)


# ------------------------------------------------------------------ les objets

static func _planks(img: Image) -> void:
	for k in 3:
		var y := 9 + k * 6
		_rect(img, 4 + k, y - 1, 28 - k, y + 4, OUT)
		_rect(img, 5 + k, y, 27 - k, y + 3, WOOD if k % 2 == 0 else WOOD_L)
		_rect(img, 5 + k, y, 27 - k, y, WOOD_L.lightened(0.2))
		img.set_pixel(8 + k, y + 2, WOOD_D)
		img.set_pixel(24 - k, y + 2, WOOD_D)


static func _balls(img: Image) -> void:
	_disc(img, 11, 21, 6.5, IRON)
	_disc(img, 21, 21, 6.5, IRON)
	_disc(img, 16, 12, 6.5, IRON)
	for p: Vector2 in [Vector2(9, 18), Vector2(19, 18), Vector2(14, 9)]:
		img.set_pixel(int(p.x), int(p.y), IRON_L.lightened(0.4))


static func _coins(img: Image) -> void:
	for k in 4:
		var y := 24 - k * 4
		_rect(img, 8, y - 2, 23, y + 2, OUT)
		_rect(img, 9, y - 1, 22, y + 1, GOLD if k % 2 == 0 else GOLD_D.lightened(0.2))
	_disc(img, 20, 10, 6.0, GOLD)
	_rect(img, 19, 7, 20, 13, GOLD_D)


static func _bullets(img: Image) -> void:
	_rect(img, 7, 10, 24, 26, OUT)   # une bourse de cuir
	_rect(img, 8, 11, 23, 25, Color("7a5230"))
	_rect(img, 8, 11, 23, 12, Color("9a6a40"))
	_line(img, Vector2(10, 9), Vector2(22, 9), 1.0, Color("4a2e18"))
	for p: Vector2 in [Vector2(13, 19), Vector2(18, 20), Vector2(15.5, 15.5)]:
		_disc(img, p.x, p.y, 2.6, IRON_L)


static func _shells(img: Image) -> void:
	for k in 3:
		var x := 9 + k * 6
		_rect(img, x - 1, 8, x + 4, 26, OUT)
		_rect(img, x, 9, x + 3, 21, Color("b8432f"))
		_rect(img, x, 22, x + 3, 25, BRASS)
		_rect(img, x, 9, x, 21, Color("d8634f"))


static func _chest(img: Image) -> void:
	_rect(img, 5, 12, 26, 26, OUT)
	_rect(img, 6, 13, 25, 25, WOOD)
	_rect(img, 6, 13, 25, 16, WOOD_L)
	_rect(img, 6, 17, 25, 18, GOLD_D)
	_rect(img, 14, 16, 17, 21, GOLD)
	_rect(img, 9, 8, 22, 12, OUT)
	_rect(img, 10, 9, 21, 11, GOLD)   # l'or qui dépasse


static func _scroll(img: Image) -> void:
	_rect(img, 8, 6, 23, 26, OUT)
	_rect(img, 9, 7, 22, 25, PAPER)
	for y in [11, 15, 19]:
		_rect(img, 11, y, 20, y, Color("8a7350"))


static func _berry(img: Image, id: String) -> void:
	var h := float(abs(id.hash()) % 360) / 360.0
	var c := Color.from_hsv(h, 0.75, 0.85)
	_disc(img, 12, 19, 6.0, c)
	_disc(img, 20, 20, 5.5, c.darkened(0.1))
	_disc(img, 16, 13, 5.5, c.lightened(0.1))
	_stroke(img, Vector2(16, 8), Vector2(19, 4), 0.8, Color("3f6e2a"))
	_rect(img, 18, 4, 22, 6, Color("5f9a3a"))


static func _raft(img: Image) -> void:
	for k in 5:
		_rect(img, 5 + k * 5, 18, 8 + k * 5, 27, OUT)
		_rect(img, 6 + k * 5, 19, 7 + k * 5, 26, WOOD_L if k % 2 == 0 else WOOD)
	_stroke(img, Vector2(16, 18), Vector2(16, 4), 0.8, WOOD_D)
	for y in range(5, 16):   # la voile
		var w := int((y - 4) * 0.8)
		_rect(img, 17, y, 17 + w, y, PAPER)


static func _cabin(img: Image) -> void:
	_rect(img, 7, 15, 25, 27, OUT)
	_rect(img, 8, 16, 24, 26, WOOD)
	for y in [18, 21, 24]:
		_rect(img, 8, y, 24, y, WOOD_D)
	_rect(img, 14, 20, 18, 26, WOOD_D)   # la porte
	for k in 9:   # le toit
		_rect(img, 5 + k, 15 - k, 27 - k, 15 - k, Color("b8432f") if k < 8 else OUT)


static func _brush(img: Image) -> void:
	_stroke(img, Vector2(24, 4), Vector2(29, 9), 1.0, WOOD_L)
	_rect(img, 22, 9, 26, 12, Color("d65db1"))


static func _weapon(img: Image, id: String) -> void:
	match id:
		"sabre":
			_stroke(img, Vector2(8, 25), Vector2(25, 6), 1.6, STEEL)
			_line(img, Vector2(9, 23), Vector2(24, 7), 0.5, Color.WHITE)
			_stroke(img, Vector2(5, 22), Vector2(11, 28), 1.4, BRASS)   # la garde
			_stroke(img, Vector2(6, 27), Vector2(3, 30), 1.4, WOOD_D)    # la poignée
		"pistolet":
			_stroke(img, Vector2(6, 13), Vector2(25, 13), 2.0, IRON)
			_stroke(img, Vector2(8, 15), Vector2(5, 25), 2.6, WOOD)
			_rect(img, 14, 16, 16, 19, BRASS)
		"tromblon":
			_stroke(img, Vector2(4, 16), Vector2(22, 14), 2.0, IRON)
			_disc(img, 25, 13.5, 3.6, BRASS)                            # la gueule évasée
			_stroke(img, Vector2(7, 17), Vector2(3, 26), 2.8, WOOD)
		"fusil":
			_stroke(img, Vector2(2, 19), Vector2(29, 11), 1.4, IRON)
			_stroke(img, Vector2(3, 21), Vector2(16, 17), 2.4, WOOD)
			_rect(img, 13, 18, 15, 20, BRASS)
		_:
			_scroll(img)
