class_name WeaponArt
extends RefCounted
## L'arme en main du pirate, dessinée en pixel art par le code (aucune image à fabriquer) : pour une arme et un skin
## (WeaponSkins), `sheets` rend deux feuilles de 64x72 par image et par direction, comme celles du pirate : « front » (par-dessus
## le pirate) et « back » (derrière lui, quand il tourne le dos). PirateSprite les empile avec les couches du corps.
##
## La main qui tient l'arme vient de data/hand_anchors.json (tools/art/export_hand_anchors.py : même squelette que le corps).
## Le dessin se fait toujours côté droit ; les directions tournées vers la gauche sont retournées à la fin.
## Chaque arme est une liste de formes (segments épais, disques, points) rangées par emplacement : métal, bois, accent, lueur ;
## les ombres, lumières et un mince liseré sombre sont ajoutés ensuite, et la lueur pulse d'une image à l'autre.

const W := 64
const H := 72
const DIR_VIEW := ["S", "SE", "E", "NE", "N", "NE", "E", "SE"]
const DIR_FLIP := [false, false, false, false, false, true, true, true]
const METAL := 1
const WOOD := 2
const ACCENT := 3
const GLOW := 4
const FL_A := 5      ## éclat de bouche : accent / lueur / blanc (jamais ombrés)
const FL_G := 6
const FL_W := 7
const RIM := Color(0.09, 0.06, 0.12, 0.95)

## Éclats de bouche : a = accent, g = lueur, w = blanc.
const FLASH := {
	"spark": ["...g...", ".g.g.g.", "..gwg..", "gggwggg", "..gwg..", ".g.g.g.", "...g..."],
	"star": ["....a....", "....g....", "..a.g.a..", "...gwg...", "aggwwwgga", "...gwg...", "..a.g.a..", "....g....", "....a...."],
	"ring": ["..aaaaa..", ".aa...aa.", "a.......a", "a...g...a", "a..gwg..a", "a...g...a", "a.......a", ".aa...aa.", "..aaaaa.."],
	"flower": ["..aa.aa..", ".aaaaaaa.", "aaaagaaaa", ".aagwgaa.", "aaaagaaaa", ".aaaaaaa.", "..aa.aa.."],
	"bolt": ["......ww.", ".....wgw.", "....wgw..", "...wgw...", ".wwwgwww.", "....wgw..", ".....wg..", "....wg...", "...ww...."],
	"coin": [".ggggg.", "gaaaaag", "gawaaag", "gaaaaag", "gaaaaag", "gaaaaag", ".ggggg."],
	"ink": ["..aa.a..", ".aaaaaa.", "aaagaaaa", ".aaaaaa.", "..aaa.a.", ".a..aa..", "...a...."],
	"ice": ["...w...", "..waw..", ".waaaw.", "waagaaw", ".waaaw.", "..waw..", "...w..."],
	"note": ["....aaa.", "....a.aa", "....a..a", "....a...", "..aaa...", ".aaaa...", "..aa...."],
	"ember": ["g...a..g", ".a..g...", "...w..a.", "g..a...g", ".a...g..", "...g..a.", "a...w..."],
	"petal": ["..aa....", "...aa..a", ".a....aa", "aa..w...", ".......a", "..a..aa.", "...aa..."],
}

static var _anchors: Dictionary = {}
static var _cache: Dictionary = {}


static func anchors() -> Dictionary:
	if _anchors.is_empty():
		var f := FileAccess.open("res://data/hand_anchors.json", FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_anchors = (parsed as Dictionary).get("anims", {}) if parsed is Dictionary else {}
	return _anchors


## Faut-il dessiner l'arme dans cette animation ? (Pas quand les mains sont prises : tonneau, barre, échelle, pouvoir.)
static func holds(anim: String) -> bool:
	return anim == "idle" or anim == "walk" or anim == "jump" or anim.begins_with("shoot_") or anim.begins_with("slash_")


## Les deux feuilles d'une animation : {"front": Image, "back": Image} (vides : null). Gardées en mémoire.
static func sheets(weapon: String, skin: String, anim: String) -> Dictionary:
	if not holds(anim) or not Weapons.exists(weapon):
		return {}
	if anim.begins_with("shoot_") and anim.substr(6) != weapon:
		return {}
	if anim.begins_with("slash_") and anim.substr(6) != weapon:
		return {}
	var key := "%s|%s|%s" % [weapon, skin, anim]
	if _cache.has(key):
		return _cache[key]
	var frames := int(PirateLook.catalog()["anims"][anim])
	var def := WeaponSkins.def_of(weapon, skin)
	var front := Image.create(frames * W, 8 * H, false, Image.FORMAT_RGBA8)
	var back := Image.create(frames * W, 8 * H, false, Image.FORMAT_RGBA8)
	var any_back := false
	var table: Array = anchors().get(anim, [])
	for d in 8:
		for f in frames:
			var a: Array = (table[d] as Array)[mini(f, (table[d] as Array).size() - 1)] if d < table.size() else [32.0, 52.0]
			var anchor := Vector2(float(a[0]), float(a[1]))
			var flip: bool = DIR_FLIP[d]
			if flip:
				anchor.x = float(W) - anchor.x
			var pose := _pose(weapon, anim, DIR_VIEW[d], f, str(def.get("motion", "kick")), str(def.get("flash", "none")))
			var cell := _draw_cell(weapon, def, anchor, pose, f)
			if flip:
				cell.flip_x()
			var dest: Image = back if bool(pose["back"]) else front
			if bool(pose["back"]):
				any_back = true
			dest.blit_rect(cell, Rect2i(0, 0, W, H), Vector2i(f * W, d * H))
	var out := {"front": front, "back": back if any_back else null}
	_cache[key] = out
	return out


## Toutes les couleurs qu'un skin peut produire, pour la palette « pirates » du filtre d'image (voir PirateSprite.register_weapon).
static func colors_of(weapon: String, skin: String) -> Array[Color]:
	var out: Array[Color] = []
	var pal: Dictionary = WeaponSkins.def_of(weapon, skin).get("palette", {})
	for slot: String in pal:
		var c := Color.html(str(pal[slot]))
		out.append(c)
		if slot != "glow":
			out.append(c.lightened(0.3))
			out.append(c.darkened(0.38))
	out.append(RIM)
	return out


# ------------------------------------------------------------------ pose

## Comment l'arme est tenue à cette image : angle (degrés, y vers le bas), raccourci (de face ou de dos elle pointe vers/loin de la
## caméra), derrière le corps ?, recul le long du canon, éclat de bouche, traînée du sabre.
static func _pose(weapon: String, anim: String, view: String, f: int, motion: String, flash: String) -> Dictionary:
	var p := {"ang": 0.0, "fore": 1.0, "back": false, "recoil": 0.0, "flash": false, "trail": false, "arc_from": 0.0}
	var sabre := weapon == "sabre"
	if anim.begins_with("shoot_"):
		match view:
			"E":
				p["ang"] = 0.0
			"SE":
				p["ang"] = 17.7
			"NE":
				p["ang"] = -16.7
			"S":
				p["ang"] = 90.0
				p["fore"] = 0.5
			"N":
				p["ang"] = -82.0
				p["fore"] = 0.6
		if f == 1:
			p["flash"] = flash != "none"
		match motion:
			"kick":
				p["ang"] = float(p["ang"]) - [0.0, 30.0, 8.0][f]
				p["recoil"] = [0.0, 1.5, 0.5][f]
			"slide":
				p["recoil"] = [0.0, 3.0, 1.2][f]
			"twirl":
				p["ang"] = float(p["ang"]) + [0.0, -22.0, 215.0][f]
				p["recoil"] = [0.0, 1.0, 0.0][f]
			"pump":
				p["ang"] = float(p["ang"]) - [0.0, 12.0, 0.0][f]
				p["recoil"] = [0.0, 2.0, 3.5][f]
	elif anim.begins_with("slash_"):
		var angs: Array = {"E": [-70.7, 6.8, 45.0], "SE": [-70.7, 6.8, 45.0], "NE": [-70.7, 6.8, 45.0],
				"S": [-84.0, 90.0, 55.0], "N": [-84.0, -72.0, 55.0]}[view]
		p["ang"] = float(angs[f])
		if view == "S" and f == 1:
			p["fore"] = 0.25
		p["trail"] = f == 1 and view != "S"
		p["arc_from"] = float(angs[0])
	else:   # idle, walk, jump : l'arme pend à la main, prête
		if sabre:
			match view:
				"E":
					p["ang"] = -55.0
				"SE":
					p["ang"] = -60.0
					p["fore"] = 0.95
				"NE":
					p["ang"] = -50.0
				"S":
					p["ang"] = -82.0
					p["fore"] = 0.8
				"N":
					p["ang"] = -86.0
					p["fore"] = 0.85
					p["back"] = true
		else:
			match view:
				"E":
					p["ang"] = 38.0
				"SE":
					p["ang"] = 55.0
					p["fore"] = 0.8
				"NE":
					p["ang"] = 28.0
					p["fore"] = 0.9
				"S":
					p["ang"] = 84.0
					p["fore"] = 0.5
				"N":
					p["ang"] = 98.0
					p["fore"] = 0.55
					p["back"] = true
	return p


# ------------------------------------------------------------------ formes

class Canvas:
	var slots := PackedByteArray()
	var x0 := 999
	var y0 := 999
	var x1 := -1
	var y1 := -1

	func _init() -> void:
		slots.resize(WeaponArt.W * WeaponArt.H)

	func put(x: int, y: int, s: int) -> void:
		if x < 0 or y < 0 or x >= WeaponArt.W or y >= WeaponArt.H:
			return
		slots[y * WeaponArt.W + x] = s
		x0 = mini(x0, x)
		y0 = mini(y0, y)
		x1 = maxi(x1, x)
		y1 = maxi(y1, y)

	func get_slot(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= WeaponArt.W or y >= WeaponArt.H:
			return 0
		return slots[y * WeaponArt.W + x]

	func stamp(cx: float, cy: float, r: float, s: int) -> void:
		var ir := int(ceil(r)) + 1
		for yy in range(int(floor(cy)) - ir, int(floor(cy)) + ir + 1):
			for xx in range(int(floor(cx)) - ir, int(floor(cx)) + ir + 1):
				var dx := float(xx) + 0.5 - cx
				var dy := float(yy) + 0.5 - cy
				if dx * dx + dy * dy <= r * r + 0.2:
					put(xx, yy, s)

	func line(a: Vector2, b: Vector2, t0: float, t1: float, s: int) -> void:
		var n := int(ceil(a.distance_to(b) * 2.0)) + 1
		for i in n + 1:
			var k := float(i) / float(n)
			var p := a.lerp(b, k)
			stamp(p.x, p.y, maxf(lerpf(t0, t1, k) * 0.5, 0.55), s)


class Xf:
	var origin := Vector2.ZERO
	var c := 1.0
	var s := 0.0
	var fore := 1.0

	func pt(u: float, v: float) -> Vector2:
		var uu := u * fore
		return origin + Vector2(uu * c - v * s, uu * s + v * c)


static func _draw_cell(weapon: String, def: Dictionary, anchor: Vector2, pose: Dictionary, f: int) -> Image:
	var cv := Canvas.new()
	var xf := Xf.new()
	var ang := deg_to_rad(float(pose["ang"]))
	xf.c = cos(ang)
	xf.s = sin(ang)
	xf.fore = float(pose["fore"])
	var rec := float(pose["recoil"])
	xf.origin = anchor - Vector2(cos(ang), sin(ang)) * rec
	var shape: Dictionary = def.get("shape", {})
	var built := _build(weapon, shape)
	var ops: Array = built["ops"]
	ops.append_array(_decor(weapon, def.get("decor", []), built))
	for op: Array in ops:
		_apply_op(cv, xf, op)
	var muzzle: Vector2 = xf.pt((built["muzzle"] as Vector2).x, (built["muzzle"] as Vector2).y)
	if bool(pose["trail"]):
		_trail(cv, anchor, float(pose["arc_from"]), float(pose["ang"]), float(built["reach"]))
	var img := _shade(cv, def.get("palette", {}), f)
	if bool(pose["flash"]):
		_flash(img, str(def.get("flash", "spark")), muzzle, def.get("palette", {}))
	return img


static func _apply_op(cv: Canvas, xf: Xf, op: Array) -> void:
	match str(op[0]):
		"seg":
			cv.line(xf.pt(float(op[1]), float(op[2])), xf.pt(float(op[3]), float(op[4])), float(op[5]), float(op[6]), int(op[7]))
		"disc":
			var p := xf.pt(float(op[1]), float(op[2]))
			cv.stamp(p.x, p.y, float(op[3]), int(op[4]))
		"px":
			var q := xf.pt(float(op[1]), float(op[2]))
			cv.put(int(floor(q.x)), int(floor(q.y)), int(op[3]))


## Les formes de l'arme (repère local : u vers l'avant, v vers le bas, la prise à l'origine). Renvoie aussi la bouche du canon,
## la portée (pour la traînée) et la hauteur de l'axe de l'arme (pour les décors).
static func _build(weapon: String, sh: Dictionary) -> Dictionary:
	var ops: Array = []
	var muzzle := Vector2.ZERO
	var axis := -1.5
	var length := 8.0
	var thick := 3.0
	match weapon:
		"pistolet":
			var barrel := float(sh.get("barrel", 8.0))
			thick = float(sh.get("thick", 3.0))
			var grip := float(sh.get("grip", 4.5))
			axis = -1.6
			length = barrel
			ops.append(["seg", -1.0, -1.6, barrel, -1.6, thick, thick + float(sh.get("flare", 0.0)), METAL])
			ops.append(["seg", -3.5, -1.0, 0.5, -1.0, 4.0, 4.0, WOOD])
			ops.append(["seg", -2.0, 0.5, -2.0 - grip * 0.35, 0.5 + grip, 3.2, 3.0, WOOD])
			ops.append(["px", 0.8, 1.4, ACCENT])
			ops.append(["disc", -2.0 - grip * 0.35, 0.8 + grip, 1.5, ACCENT])
			muzzle = Vector2(barrel + 1.0, -1.6)
		"tromblon":
			var bell := float(sh.get("bell", 6.5))
			thick = 3.6
			axis = -1.5
			length = 10.0
			ops.append(["seg", -1.0, -1.5, 6.0, -1.5, 3.4, 3.6, METAL])
			ops.append(["seg", 5.0, -1.5, 11.0, -1.5, 3.6, bell * 0.8, METAL])
			ops.append(["seg", -1.0, -0.6, -8.0, 2.2, 4.0, 3.2, WOOD])
			ops.append(["disc", -8.2, 2.3, 1.7, WOOD])
			ops.append(["px", 0.6, 1.2, ACCENT])
			muzzle = Vector2(11.5, -1.5)
		"fusil":
			var barrel_f := float(sh.get("barrel", 19.0))
			axis = -1.2
			length = barrel_f
			thick = 2.2
			ops.append(["seg", 0.0, -1.2, barrel_f, -1.2, 2.2, 2.0, METAL])
			ops.append(["seg", -2.0, -0.8, 3.0, -0.8, 3.2, 3.2, METAL])
			ops.append(["seg", -1.5, -0.4, -9.0, 2.5, 3.0, 2.6, WOOD])
			ops.append(["seg", 4.0, -3.7, 11.0, -3.7, 2.0, 2.0, ACCENT])
			ops.append(["px", 11.6, -3.7, GLOW])
			ops.append(["px", 5.0, -2.5, METAL])
			ops.append(["px", 9.0, -2.5, METAL])
			muzzle = Vector2(barrel_f + 1.0, -1.2)
		_:   # sabre
			var blade := float(sh.get("blade", 15.0))
			axis = 0.0
			length = blade
			thick = 2.2
			ops.append(["seg", 1.5, 0.0, blade * 0.7, -0.2, 2.4, 2.0, METAL])
			ops.append(["seg", blade * 0.7, -0.2, blade, -1.3, 2.0, 0.9, METAL])
			ops.append(["seg", 1.0, -3.0, 1.0, 3.0, 1.5, 1.5, ACCENT])
			ops.append(["seg", -3.5, 0.0, 0.5, 0.0, 2.2, 2.2, WOOD])
			ops.append(["disc", -4.3, 0.0, 1.4, ACCENT])
			muzzle = Vector2(blade, -1.3)
	return {"ops": ops, "muzzle": muzzle, "axis": axis, "length": length, "thick": thick, "reach": length + 2.0}


## Les motifs d'un skin, posés le long de l'axe de l'arme.
static func _decor(weapon: String, decor: Array, built: Dictionary) -> Array:
	var ops: Array = []
	var ax := float(built["axis"])
	var ln := float(built["length"])
	var half := float(built["thick"]) * 0.5
	var sabre := weapon == "sabre"
	var u_lo := 2.5 if sabre else 0.5
	for d in decor:
		match str(d):
			"stripes":
				var u := u_lo + 1.0
				while u < ln - 1.0:
					ops.append(["seg", u, ax - half, u, ax + half, 1.0, 1.0, ACCENT])
					u += 3.0
			"dots":
				var u2 := u_lo + 1.5
				while u2 < ln - 0.5:
					ops.append(["px", u2, ax, ACCENT])
					u2 += 2.6
			"gem":
				ops.append(["disc", -1.2, -1.0 if not sabre else 0.0, 1.0, GLOW])
			"glowline":
				ops.append(["seg", u_lo, ax, ln - 0.8, ax, 1.0, 1.0, GLOW])
			"spikes":
				ops.append(["seg", ln - 0.5, ax - half, ln + 1.2, ax - half - 1.8, 1.2, 0.6, ACCENT])
				ops.append(["seg", ln - 0.5, ax + half, ln + 1.2, ax + half + 1.8, 1.2, 0.6, ACCENT])
				ops.append(["seg", ln * 0.5, ax - half, ln * 0.5 + 0.6, ax - half - 1.6, 1.0, 0.6, ACCENT])
			"fins":
				var u3 := u_lo + 1.5
				while u3 < ln - 1.0:
					ops.append(["seg", u3, ax - half, u3 + 0.8, ax - half - 2.6, 1.2, 0.6, ACCENT])
					u3 += 2.8
			"scales":
				var i := 0
				var u4 := u_lo
				while u4 < ln - 0.5:
					ops.append(["px", u4, ax - 0.7 + float(i % 2) * 1.4, ACCENT])
					u4 += 1.5
					i += 1
			"ribbon":
				ops.append(["seg", -2.5, 3.0, -4.5, 6.5, 1.0, 1.0, ACCENT])
				ops.append(["seg", -4.5, 6.5, -3.0, 9.5, 1.0, 1.0, ACCENT])
				ops.append(["px", -3.0, 10.0, GLOW])
			"skull":
				var sv := 0.0 if sabre else 1.5
				ops.append(["px", -2.8, sv, ACCENT])
				ops.append(["px", -1.8, sv, ACCENT])
				ops.append(["px", -2.3, sv + 1.0, ACCENT])
			"vines":
				var i2 := 0
				var u5 := u_lo
				while u5 < ln:
					ops.append(["px", u5, ax - half - 0.6 + float(i2 % 2) * 1.2, ACCENT])
					u5 += 1.2
					i2 += 1
			"wings":
				ops.append(["seg", -0.5, ax - 1.0, -3.2, ax - 4.8, 1.6, 0.8, ACCENT])
				ops.append(["seg", -0.5, ax + 1.0, -3.2, ax + 4.4, 1.6, 0.8, ACCENT])
			"flames":
				var j := 0
				var u6 := u_lo + 0.5
				while u6 < ln - 1.0:
					ops.append(["px", u6, ax - half - 0.5 - float(j % 2), ACCENT if j % 2 == 0 else GLOW])
					ops.append(["px", u6, ax + 0.4 * float(j % 2), GLOW])
					u6 += 1.7
					j += 1
			"zigzag":
				var k := 0
				var u7 := u_lo + 0.5
				while u7 < ln - 1.0:
					ops.append(["px", u7, ax - 0.8 + float(k % 2) * 1.6, GLOW])
					u7 += 1.4
					k += 1
			"petals":
				ops.append(["px", ln * 0.35, ax - half - 1.0, ACCENT])
				ops.append(["px", ln * 0.35 + 1.0, ax - half - 1.0, ACCENT])
				ops.append(["px", ln * 0.6, ax + half + 1.0, ACCENT])
				ops.append(["px", ln * 0.6 + 1.0, ax + half + 1.0, ACCENT])
				ops.append(["px", ln * 0.85, ax - half - 1.0, GLOW])
	return ops


## Couleurs : emplacement -> teinte, avec lumière en haut, ombre en bas et un mince liseré sombre autour de tout.
static func _shade(cv: Canvas, palette: Dictionary, f: int) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	if cv.x1 < 0:
		return img
	var base: Dictionary = {}
	for name: String in ["metal", "wood", "accent", "glow"]:
		base[name] = Color.html(str(palette.get(name, "#ffffff")))
	var slot_name := {METAL: "metal", WOOD: "wood", ACCENT: "accent", GLOW: "glow"}
	var pulse := 0.5 + 0.5 * sin(float(f) * 1.7)
	for y in range(cv.y0 - 1, cv.y1 + 2):
		for x in range(cv.x0 - 1, cv.x1 + 2):
			var s := cv.get_slot(x, y)
			if s == 0:
				if cv.get_slot(x - 1, y) > 0 or cv.get_slot(x + 1, y) > 0 or cv.get_slot(x, y - 1) > 0 or cv.get_slot(x, y + 1) > 0:
					if x >= 0 and y >= 0 and x < W and y < H:
						img.set_pixel(x, y, RIM)
				continue
			var c: Color = base[slot_name[s]]
			if s == GLOW:
				c = c.lightened(0.18 * pulse)
			else:
				if cv.get_slot(x, y - 1) != s:
					c = c.lightened(0.3)
				elif cv.get_slot(x, y + 1) != s:
					c = c.darkened(0.38)
				elif cv.get_slot(x + 1, y) == 0 and cv.get_slot(x, y + 1) != 0:
					c = c.darkened(0.2)
			img.set_pixel(x, y, c)
	return img


## Éclat de bouche : une petite image en pixels (voir FLASH) centrée sur la bouche du canon, aux couleurs du skin.
static func _flash(img: Image, style: String, at: Vector2, palette: Dictionary) -> void:
	var rows: Array = FLASH.get(style, FLASH["spark"])
	var a := Color.html(str(palette.get("accent", "#ffcf7a"))).lightened(0.15)
	var g := Color.html(str(palette.get("glow", "#ffe9a8"))).lightened(0.2)
	var h := rows.size()
	var w := str(rows[0]).length()
	var ox := int(round(at.x)) - w / 2
	var oy := int(round(at.y)) - h / 2
	for yy in h:
		var row := str(rows[yy])
		for xx in row.length():
			var ch := row[xx]
			if ch == ".":
				continue
			var px := ox + xx
			var py := oy + yy
			if px < 0 or py < 0 or px >= W or py >= H:
				continue
			img.set_pixel(px, py, a if ch == "a" else (g if ch == "g" else Color(1.0, 1.0, 0.95)))


## La traînée du coup de sabre : un arc de la lame levée à la lame baissée, aux couleurs du skin.
static func _trail(cv: Canvas, anchor: Vector2, from_deg: float, to_deg: float, reach: float) -> void:
	var n := 14
	for i in n + 1:
		var k := float(i) / float(n)
		var a := deg_to_rad(lerpf(from_deg, to_deg, k))
		var r := reach * (0.85 + 0.15 * sin(k * PI))
		var p := anchor + Vector2(cos(a), sin(a)) * r
		cv.put(int(floor(p.x)), int(floor(p.y)), GLOW if i % 3 != 0 else ACCENT)
