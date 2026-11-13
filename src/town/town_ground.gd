class_name TownGround
extends RefCounted
## Le sol de la ville v3 (13/11/2026, « niveau 2 » : retour de Jimmy, « les chemins se croisent en millefeuille, on voit des
## artefacts, les routes et les croisements ne sont pas beaux »). Avant, chaque rue était une suite de dalles posées sur l'herbe,
## et deux rues qui se croisaient empilaient leurs dalles à la même hauteur : elles scintillaient l'une dans l'autre.
## Maintenant il n'y a plus qu'UN sol. Une carte de la ville (une image, 4 pixels par mètre) dit pour chaque point s'il est
## pavé, à quel point, si c'est une grande rue, si c'est du sable ; shaders/town_ground.gdshader peint le sol d'après elle :
## pavés, bande de terre battue au bord, herbe, sable, avec des bords irréguliers. Un croisement n'est plus qu'un endroit pavé.
## Carte : rouge = pavé (0,5 au bord de la rue, 1 à 80 cm dedans, 0 à 80 cm dehors), vert = grande rue ou place, bleu = sable.

const PPM := 4.0          ## pixels par mètre
const SOFT := 1.6         ## m : largeur de la transition codée dans le rouge (de part et d'autre du bord)


## Fabrique la carte et la matière du sol. Coordonnées du fichier du port (x, y).
static func material(plan: Dictionary) -> ShaderMaterial:
	var land := Land._poly(plan.get("land", []))
	var lo := land[0]
	var hi := land[0]
	for p: Vector2 in land:
		lo = lo.min(p)
		hi = hi.max(p)
	lo -= Vector2(2, 2)
	hi += Vector2(2, 2)
	var w := int(ceil((hi.x - lo.x) * PPM))
	var h := int(ceil((hi.y - lo.y) * PPM))
	var data := PackedByteArray()
	data.resize(w * h * 3)
	data.fill(0)
	for s: Dictionary in plan.get("streets", []):
		var pts := Land._poly(s["pts"])
		var main := str(s["id"]) in ["quai", "grand_rue"]
		for i in pts.size() - 1:
			_segment(data, w, h, lo, pts[i], pts[i + 1], float(s["width"]), main)
	# le quai est pavé jusqu'à son bord : on pave aussi le long de la côte, entre les deux bouts de la rue du quai (sans cela
	# une bande d'herbe restait entre les pavés et l'eau)
	var quay_x := Vector2(INF, -INF)
	for s2: Dictionary in plan.get("streets", []):
		if str(s2["id"]) == "quai":
			for q: Vector2 in Land._poly(s2["pts"]):
				quay_x = Vector2(minf(quay_x.x, q.x), maxf(quay_x.y, q.x))
	for i in land.size() - 1:
		var c0 := land[i]
		var c1 := land[i + 1]
		if minf(c0.x, c1.x) >= quay_x.x - 1.0 and maxf(c0.x, c1.x) <= quay_x.y + 1.0 and maxf(c0.y, c1.y) < 12.0:
			_segment(data, w, h, lo, c0, c1, 5.0, true)
	for pth: Dictionary in plan.get("paths", []):
		var pp := Land._poly(pth["pts"])
		_segment(data, w, h, lo, pp[0], pp[1], float(pth["width"]), false)
	for r: Dictionary in plan.get("ramps", []):
		_segment(data, w, h, lo, Vector2(float(r["a"][0]), float(r["a"][1])), Vector2(float(r["b"][0]), float(r["b"][1])), float(r["width"]), not bool(r.get("stairs", false)))
	for pl: Dictionary in plan.get("plazas", []):
		_ellipse(data, w, h, lo, Vector2(float(pl["x"]), float(pl["y"])), float(pl["rx"]), float(pl["ry"]))
	for lvl: Dictionary in plan.get("levels", []):
		if str(lvl.get("style", "")) == "fort":
			_polygon(data, w, h, lo, Land._poly(lvl["poly"]), 0, true)   # la plate-forme du fort : dallée
	_polygon(data, w, h, lo, Land._poly(plan.get("sand", [])), 2, false)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/town_ground.gdshader") as Shader
	mat.set_shader_parameter("mask", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("origin", lo)
	mat.set_shader_parameter("extent", Vector2(w, h) / PPM)
	return mat


static func _put(data: PackedByteArray, at: int, v: int, main: bool) -> void:
	if v > data[at]:
		data[at] = v
	if main and v > 110:
		data[at + 1] = 255


## Une rue : le segment a-b, de largeur `width`.
static func _segment(data: PackedByteArray, w: int, h: int, lo: Vector2, a: Vector2, b: Vector2, width: float, main: bool) -> void:
	var reach := width * 0.5 + SOFT * 0.5 + 0.3
	var x0 := maxi(int(floor((minf(a.x, b.x) - reach - lo.x) * PPM)), 0)
	var x1 := mini(int(ceil((maxf(a.x, b.x) + reach - lo.x) * PPM)), w - 1)
	var y0 := maxi(int(floor((minf(a.y, b.y) - reach - lo.y) * PPM)), 0)
	var y1 := mini(int(ceil((maxf(a.y, b.y) + reach - lo.y) * PPM)), h - 1)
	for iy in range(y0, y1 + 1):
		for ix in range(x0, x1 + 1):
			var p := lo + Vector2(ix + 0.5, iy + 0.5) / PPM
			var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)
			var v := int(clampf(0.5 + (width * 0.5 - d) / SOFT, 0.0, 1.0) * 255.0)
			if v > 0:
				_put(data, (iy * w + ix) * 3, v, main)


## Une place : une ellipse, pavée comme une grande rue.
static func _ellipse(data: PackedByteArray, w: int, h: int, lo: Vector2, c: Vector2, rx: float, ry: float) -> void:
	var reach := SOFT * 0.5 + 0.3
	var x0 := maxi(int(floor((c.x - rx - reach - lo.x) * PPM)), 0)
	var x1 := mini(int(ceil((c.x + rx + reach - lo.x) * PPM)), w - 1)
	var y0 := maxi(int(floor((c.y - ry - reach - lo.y) * PPM)), 0)
	var y1 := mini(int(ceil((c.y + ry + reach - lo.y) * PPM)), h - 1)
	for iy in range(y0, y1 + 1):
		for ix in range(x0, x1 + 1):
			var p := lo + Vector2(ix + 0.5, iy + 0.5) / PPM - c
			var inside := (1.0 - Vector2(p.x / rx, p.y / ry).length()) * minf(rx, ry)   # m, positif dedans
			var v := int(clampf(0.5 + inside / SOFT, 0.0, 1.0) * 255.0)
			if v > 0:
				_put(data, (iy * w + ix) * 3, v, true)


## Un polygone plein, écrit dans le canal `channel` (0 : pavé, 2 : sable).
static func _polygon(data: PackedByteArray, w: int, h: int, lo: Vector2, poly: PackedVector2Array, channel: int, main: bool) -> void:
	if poly.size() < 3:
		return
	var a := poly[0]
	var b := poly[0]
	for p: Vector2 in poly:
		a = a.min(p)
		b = b.max(p)
	var x0 := maxi(int(floor((a.x - lo.x) * PPM)), 0)
	var x1 := mini(int(ceil((b.x - lo.x) * PPM)), w - 1)
	var y0 := maxi(int(floor((a.y - lo.y) * PPM)), 0)
	var y1 := mini(int(ceil((b.y - lo.y) * PPM)), h - 1)
	for iy in range(y0, y1 + 1):
		for ix in range(x0, x1 + 1):
			if Geometry2D.is_point_in_polygon(lo + Vector2(ix + 0.5, iy + 0.5) / PPM, poly):
				var at := (iy * w + ix) * 3
				data[at + channel] = 255
				if main:
					data[at + 1] = 255
