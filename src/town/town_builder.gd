class_name TownBuilder
extends RefCounted
## Bâtit en 3D ce que data/town.json ajoute à la ville : terrasses et marches (extérieur), et l'intérieur de la
## taverne (salle, bar, escalier, galerie). L'intérieur est une « coupe » : pas de toit, pas de mur côté
## caméra ; il remplace le bâtiment du port tant que le pirate est dedans (voir sailing_game.gd).

# 13/11 (niveau 2, intérieurs) : les couleurs de la charte v1 (design/bible-v2.md), les mêmes que les rues et les maisons.
# Avant : des bruns et des gris choisis à l'œil, plus ternes que le reste de la ville.
const STONE := Color("7d7488")
const WOOD := Color("9c6a43")
const WOOD_D := Color("3a2630")
const WOOD_L := Color("cf9c62")
const PLASTER := Color("e8c9a0")
const IRON := Color("2e2a44")


## Terrasses et marches de l'extérieur.
static func build_levels(parent: Node3D, land: Land) -> void:
	for lvl: Dictionary in land.levels:
		var r: Array = lvl["rect"]
		var root := Node3D.new()
		root.name = str(lvl["id"])
		parent.add_child(root)
		if lvl.has("axis"):
			_steps(root, lvl, float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		else:
			_deck(root, lvl, float(r[0]), float(r[1]), float(r[2]), float(r[3]))


static func _deck(root: Node3D, lvl: Dictionary, x0: float, y0: float, x1: float, y1: float) -> void:
	var h := float(lvl["h"])
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	var w := x1 - x0
	var d := y1 - y0
	var style := str(lvl.get("style", "deck"))
	if style != "none":   # (« none » : le sol est déjà dans le modèle du port, comme le plateau de la haute ville)
		ProcKit.box(root, Vector3(w, h - 0.05, d), ProcKit.w(cx, cy, (h - 0.05) * 0.5), ProcKit.flat(STONE))
	match style:
		"none":
			pass
		"plaza":   # dalles de pierre claire
			ProcKit.box(root, Vector3(w + 0.1, 0.09, d + 0.1), ProcKit.w(cx, cy, h - 0.045), ProcKit.flat(STONE.lightened(0.16)))
		"garden":   # herbe
			ProcKit.box(root, Vector3(w, 0.09, d), ProcKit.w(cx, cy, h - 0.045), ProcKit.flat(Color(0.36, 0.55, 0.30)))
		_:
			ProcKit.box(root, Vector3(w + 0.1, 0.09, d + 0.1), ProcKit.w(cx, cy, h - 0.045), ProcKit.wood(WOOD, Vector2(w * 0.5, d * 0.5)))
	for r: Array in lvl.get("rails", []):
		_rail(root, float(r[0]), float(r[1]), float(r[2]), float(r[3]), h)
	for wl: Array in lvl.get("walls", []):
		_wall(root, float(wl[0]), float(wl[1]), float(wl[2]), float(wl[3]), h, float(wl[4]))
	for dc: Array in lvl.get("decor", []):
		_decor(root, str(dc[0]), float(dc[1]), float(dc[2]), h, str(dc[3]) if dc.size() > 3 else "")


## Muret de pierre, droit selon x ou y (épaisseur 0,35), avec un chaperon plus clair.
static func _wall(root: Node3D, xa: float, ya: float, xb: float, yb: float, h: float, wh: float) -> void:
	var horizontal := absf(ya - yb) < 0.001
	var size := Vector3(xb - xa + 0.35, wh, 0.35) if horizontal else Vector3(0.35, wh, yb - ya + 0.35)
	var c := Vector2((xa + xb) * 0.5, (ya + yb) * 0.5)
	ProcKit.box(root, size, ProcKit.w(c.x, c.y, h + wh * 0.5), ProcKit.flat(STONE.darkened(0.08)))
	ProcKit.box(root, Vector3(size.x + 0.08, 0.1, size.z + 0.08), ProcKit.w(c.x, c.y, h + wh + 0.03), ProcKit.flat(STONE.lightened(0.2)))


## Décor posé sur un niveau de hauteur h : tonneau, canon (face « s » vers la mer au sud, « n » au nord), lanterne,
## banc, mât au pavillon noir, massif de fleurs.
static func _decor(root: Node3D, kind: String, x: float, y: float, h: float, face: String) -> void:
	match kind:
		"barrel":
			ProcKit.cyl(root, 0.4, 0.8, ProcKit.w(x, y, h + 0.4), ProcKit.flat(Color(0.5, 0.33, 0.18)))
			ProcKit.cyl(root, 0.42, 0.06, ProcKit.w(x, y, h + 0.2), ProcKit.flat(IRON))
			ProcKit.cyl(root, 0.42, 0.06, ProcKit.w(x, y, h + 0.62), ProcKit.flat(IRON))
		"cannon":
			var dir := 1.0 if face == "s" else -1.0   # sur l'écran, le sud est +z
			ProcKit.box(root, Vector3(0.9, 0.3, 1.1), ProcKit.w(x, y, h + 0.25), ProcKit.flat(WOOD_D))
			var tube := ProcKit.cyl(root, 0.24, 1.7, ProcKit.w(x, y - dir * 0.35, h + 0.62), ProcKit.flat(IRON), Vector3(PI / 2.0, 0, 0))
			tube.rotation.x = PI / 2.0 - 0.12 * dir
			ProcKit.ball(root, 0.15, ProcKit.w(x, y + dir * 0.55, h + 0.78), ProcKit.flat(IRON))
			ProcKit.cyl(root, 0.25, 0.5, ProcKit.w(x - 0.55, y, h + 0.25), ProcKit.flat(WOOD_D), Vector3(0, 0, PI / 2.0))
			ProcKit.cyl(root, 0.25, 0.5, ProcKit.w(x + 0.55, y, h + 0.25), ProcKit.flat(WOOD_D), Vector3(0, 0, PI / 2.0))
		"lamp":
			ProcKit.cyl(root, 0.07, 2.6, ProcKit.w(x, y, h + 1.3), ProcKit.flat(IRON))
			var lamp := ProcKit.ball(root, 0.16, ProcKit.w(x, y, h + 2.7), ProcKit.glow(Color(1.0, 0.85, 0.5)))
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"bench":
			ProcKit.box(root, Vector3(1.8, 0.1, 0.5), ProcKit.w(x, y, h + 0.5), ProcKit.flat(WOOD))
			ProcKit.box(root, Vector3(1.8, 0.4, 0.08), ProcKit.w(x, y - 0.25, h + 0.78), ProcKit.flat(WOOD))
			for dx in [-0.75, 0.75]:
				ProcKit.box(root, Vector3(0.1, 0.5, 0.4), ProcKit.w(x + dx, y, h + 0.25), ProcKit.flat(WOOD_D))
		"flag":
			ProcKit.cyl(root, 0.06, 4.5, ProcKit.w(x, y, h + 2.25), ProcKit.flat(WOOD_D))
			ProcKit.box(root, Vector3(1.5, 0.95, 0.04), ProcKit.w(x + 0.8, y, h + 4.0), ProcKit.flat(Color(0.08, 0.08, 0.1)))
			ProcKit.ball(root, 0.17, ProcKit.w(x + 0.8, y + 0.05, h + 4.05), ProcKit.flat(Color(0.92, 0.9, 0.85)))
		"bed":
			ProcKit.box(root, Vector3(2.2, 0.25, 1.2), ProcKit.w(x, y, h + 0.12), ProcKit.flat(Color(0.30, 0.20, 0.13)))
			var cols := [Color(0.9, 0.35, 0.35), Color(0.95, 0.8, 0.3), Color(0.7, 0.45, 0.9), Color(0.95, 0.55, 0.7)]
			for k in 8:
				ProcKit.ball(root, 0.14, ProcKit.w(x - 0.9 + float(k % 4) * 0.6, y - 0.3 + float(floori(k / 4.0)) * 0.6, h + 0.34), ProcKit.flat(cols[k % 4]))


## Garde-corps en bois du point (xa, ya) au point (xb, yb), droit selon x ou y, avec un poteau tous les 1,2 m.
static func _rail(root: Node3D, xa: float, ya: float, xb: float, yb: float, h: float) -> void:
	var mat := ProcKit.flat(WOOD_D)
	var horizontal := absf(ya - yb) < 0.001
	var size := Vector3(xb - xa, 0.08, 0.1) if horizontal else Vector3(0.1, 0.08, yb - ya)
	ProcKit.box(root, size, ProcKit.w((xa + xb) * 0.5, (ya + yb) * 0.5, h + 0.85), mat)
	var length := (xb - xa) if horizontal else (yb - ya)
	var n := maxi(1, ceili(length / 1.2))
	for i in n + 1:
		var t := float(i) / float(n)
		ProcKit.box(root, Vector3(0.1, 0.85, 0.1), ProcKit.w(lerpf(xa, xb, t), lerpf(ya, yb, t), h + 0.42), mat)


## Des marches pleines empilées : chacune va du bas de l'escalier jusqu'au haut, de plus en plus haute.
static func _steps(root: Node3D, lvl: Dictionary, x0: float, y0: float, x1: float, y1: float) -> void:
	var n := int(lvl.get("steps", 3))
	var h0 := float(lvl["h0"])
	var h1 := float(lvl["h1"])
	var along_y: bool = lvl["axis"] == "y"
	var rises := h1 > h0
	var mat := ProcKit.flat(STONE.lightened(0.1))
	var a0: float = y0 if along_y else x0
	var a1: float = y1 if along_y else x1
	var span := a1 - a0
	for i in n:
		var top := lerpf(minf(h0, h1), maxf(h0, h1), (float(i) + 0.5) / float(n))
		# la marche i couvre la partie haute de la pente ; vers le haut de l'escalier, on se rapproche
		var s0 := a0 + span * float(i) / float(n) if rises else a0
		var s1 := a1 if rises else a1 - span * float(i) / float(n)
		var mid := (s0 + s1) * 0.5
		if along_y:
			ProcKit.box(root, Vector3(x1 - x0, top, s1 - s0), ProcKit.w((x0 + x1) * 0.5, mid, top * 0.5), mat)
		else:
			ProcKit.box(root, Vector3(s1 - s0, top, y1 - y0), ProcKit.w(mid, (y0 + y1) * 0.5, top * 0.5), mat)


# ------------------------------------------------------------------ la taverne


## L'intérieur de la taverne : un noeud à rendre visible quand le pirate est dedans.
static func build_tavern(it: Dictionary) -> Node3D:
	var root := _shell(it)
	var y1 := float((it["footprint"] as Array)[3])
	var fh := float(it.get("floor_h", 0.45))
	# le bar
	ProcKit.box(root, Vector3(6.4, 1.0, 1.0), ProcKit.w(-13.6, 31.9, fh + 0.5), ProcKit.wood(WOOD_D, Vector2(3.0, 0.5)))
	ProcKit.box(root, Vector3(6.7, 0.1, 1.3), ProcKit.w(-13.6, 31.9, fh + 1.05), ProcKit.flat(WOOD_L.darkened(0.15)))
	for k in 5:
		ProcKit.cyl(root, 0.09, 0.16, ProcKit.w(-16.0 + float(k) * 1.3, 31.7, fh + 1.18), ProcKit.flat(Color(0.8, 0.7, 0.4)))
	# étagères de bouteilles derrière le bar
	var colors := [Color(0.2, 0.5, 0.3), Color(0.55, 0.2, 0.15), Color(0.2, 0.35, 0.6), Color(0.75, 0.6, 0.25)]
	for row in 2:
		var sy := fh + 1.6 + float(row) * 0.8
		ProcKit.box(root, Vector3(6.0, 0.08, 0.35), ProcKit.w(-13.6, y1 - 0.5, sy), ProcKit.flat(WOOD_D))
		for k in 14:
			ProcKit.cyl(root, 0.08, 0.34, ProcKit.w(-16.4 + float(k) * 0.43, y1 - 0.5, sy + 0.2), ProcKit.flat(colors[(k + row) % 4]))
	# tonneaux (petits obstacles) et tables (grands)
	for c: Array in _circles_of(it, "salle"):
		var r := float(c[2])
		if r < 0.6:
			ProcKit.cyl(root, r, 0.9, ProcKit.w(float(c[0]), float(c[1]), fh + 0.45), ProcKit.flat(Color(0.5, 0.33, 0.18)))
			ProcKit.cyl(root, r + 0.02, 0.07, ProcKit.w(float(c[0]), float(c[1]), fh + 0.22), ProcKit.flat(IRON))
			ProcKit.cyl(root, r + 0.02, 0.07, ProcKit.w(float(c[0]), float(c[1]), fh + 0.7), ProcKit.flat(IRON))
		else:
			_table(root, float(c[0]), float(c[1]), fh)
	# l'escalier et la galerie
	for s: Dictionary in it["surfaces"]:
		if s["id"] == "escalier":
			_stairs(root, s)
		elif s["id"] == "galerie":
			_gallery(root, s)
	# décor du mur du fond : barre à roue, pavillon noir à tête de mort
	ProcKit.cyl(root, 0.7, 0.08, ProcKit.w(-13.6, y1 - 0.42, 4.7), ProcKit.flat(WOOD_D), Vector3(PI / 2.0, 0, 0))
	for k in 4:
		ProcKit.box(root, Vector3(1.5, 0.07, 0.07), ProcKit.w(-13.6, y1 - 0.46, 4.7), ProcKit.flat(WOOD_D), Vector3(0, 0, PI * float(k) / 4.0))
	ProcKit.box(root, Vector3(1.6, 1.1, 0.06), ProcKit.w(-16.6, y1 - 0.42, 4.6), ProcKit.flat(Color(0.08, 0.08, 0.1)))
	ProcKit.ball(root, 0.2, ProcKit.w(-16.6, y1 - 0.47, 4.65), ProcKit.flat(Color(0.92, 0.9, 0.85)))
	ProcKit.box(root, Vector3(0.34, 0.08, 0.06), ProcKit.w(-16.6, y1 - 0.47, 4.38), ProcKit.flat(Color(0.92, 0.9, 0.85)))
	# lumières : lanternes dans la salle et à la galerie
	for lp: Array in [[-14.5, 28.0, 4.2], [-9.5, 28.8, 4.2], [-14.0, 32.4, 3.6], [-7.2, 32.0, 5.3]]:
		var lamp := ProcKit.ball(root, 0.13, ProcKit.w(float(lp[0]), float(lp[1]), float(lp[2])), ProcKit.glow(Color(1.0, 0.85, 0.5)))
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.light_color = GameConfig.LAMP_LIGHT   # (la même lumière que les lanternes des rues)
		light.light_energy = 1.4
		light.omni_range = 7.0
		light.shadow_enabled = false
		light.position = ProcKit.w(float(lp[0]), float(lp[1]), float(lp[2]) - 0.3)
		root.add_child(light)
	return root


static func _circles_of(it: Dictionary, surface_id: String) -> Array:
	for s: Dictionary in it["surfaces"]:
		if s["id"] == surface_id:
			return s.get("circles", [])
	return []


static func _table(root: Node3D, x: float, y: float, fh: float) -> void:
	ProcKit.cyl(root, 0.8, 0.08, ProcKit.w(x, y, fh + 0.8), ProcKit.wood(WOOD_L, Vector2(1, 1)))
	ProcKit.cyl(root, 0.1, 0.8, ProcKit.w(x, y, fh + 0.4), ProcKit.flat(WOOD_D))
	for k in 4:
		var a := TAU * (float(k) + 0.5) / 4.0
		ProcKit.cyl(root, 0.22, 0.45, ProcKit.w(x + cos(a) * 1.1, y + sin(a) * 1.1, fh + 0.22), ProcKit.flat(WOOD_D))
	ProcKit.cyl(root, 0.07, 0.12, ProcKit.w(x + 0.25, y + 0.1, fh + 0.9), ProcKit.flat(Color(0.8, 0.7, 0.4)))
	ProcKit.cyl(root, 0.07, 0.12, ProcKit.w(x - 0.3, y - 0.2, fh + 0.9), ProcKit.flat(Color(0.8, 0.7, 0.4)))


static func _stairs(root: Node3D, s: Dictionary) -> void:
	var r: Array = s["rect"]
	var n := int(s["steps"])
	var h0 := float(s["h0"])
	var h1 := float(s["h1"])
	var x0 := float(r[0])
	var x1 := float(r[2])
	var y0 := float(r[1])
	var y1 := float(r[3])
	var mat := ProcKit.wood(WOOD_L.darkened(0.1), Vector2(1, 1))
	for i in n:
		var top := lerpf(h0, h1, (float(i) + 0.5) / float(n))
		var sa := y0 + (y1 - y0) * float(i) / float(n)
		ProcKit.box(root, Vector3(x1 - x0, top, y1 - sa), ProcKit.w((x0 + x1) * 0.5, (sa + y1) * 0.5, top * 0.5), mat)
	# rampe du côté de la salle
	var run := y1 - y0
	var rise := h1 - h0
	var ang := atan2(rise, run)
	var rail_mat := ProcKit.flat(WOOD_D)
	ProcKit.box(root, Vector3(0.09, 0.09, sqrt(run * run + rise * rise)), ProcKit.w(x0 + 0.05, (y0 + y1) * 0.5, (h0 + h1) * 0.5 + 0.95), rail_mat, Vector3(-ang, 0, 0))
	for k in 6:
		var t := float(k) / 5.0
		ProcKit.box(root, Vector3(0.08, 0.9, 0.08), ProcKit.w(x0 + 0.05, lerpf(y0 + 0.1, y1 - 0.1, t), lerpf(h0, h1, t) + 0.45), rail_mat)


static func _gallery(root: Node3D, s: Dictionary) -> void:
	var r: Array = s["rect"]
	var x0 := float(r[0])
	var y0 := float(r[1])
	var x1 := float(r[2])
	var y1 := float(r[3])
	var h := float(s["h"])
	var w := x1 - x0
	var d := y1 - y0
	ProcKit.box(root, Vector3(w, 0.28, d), ProcKit.w((x0 + x1) * 0.5, (y0 + y1) * 0.5, h - 0.14), ProcKit.wood(WOOD, Vector2(w * 0.5, d * 0.5)))
	var rail := ProcKit.flat(WOOD_D)
	# garde-corps : sur le devant (jusqu'à l'escalier) et sur le côté de l'ouest
	ProcKit.box(root, Vector3(w - 2.0, 0.08, 0.1), ProcKit.w(x0 + (w - 2.0) * 0.5, y0 + 0.06, h + 0.95), rail)
	var x := x0 + 0.05
	while x < x1 - 2.0:
		ProcKit.box(root, Vector3(0.08, 0.9, 0.08), ProcKit.w(x, y0 + 0.06, h + 0.45), rail)
		x += 0.7
	ProcKit.box(root, Vector3(0.1, 0.08, d), ProcKit.w(x0 + 0.05, (y0 + y1) * 0.5, h + 0.95), rail)
	var y := y0
	while y < y1:
		ProcKit.box(root, Vector3(0.08, 0.9, 0.08), ProcKit.w(x0 + 0.05, y, h + 0.45), rail)
		y += 0.7
	# poteaux jusqu'au sol
	for p: Array in [[x0 + 0.1, y0 + 0.1], [x0 + 0.1, y1 - 0.4]]:
		ProcKit.box(root, Vector3(0.22, h - 0.45, 0.22), ProcKit.w(float(p[0]), float(p[1]), 0.45 + (h - 0.45) * 0.5), rail)
	# un coffre et un lit à l'étage
	ProcKit.box(root, Vector3(1.0, 0.6, 0.7), ProcKit.w(x1 - 0.9, y1 - 0.5, h + 0.3), ProcKit.wood(WOOD_D, Vector2(1, 1)))
	ProcKit.box(root, Vector3(1.0, 0.1, 0.72), ProcKit.w(x1 - 0.9, y1 - 0.5, h + 0.65), ProcKit.flat(Color(0.7, 0.55, 0.2)))
	ProcKit.box(root, Vector3(1.6, 0.35, 0.9), ProcKit.w(x0 + 1.2, y1 - 0.65, h + 0.18), ProcKit.flat(Color(0.55, 0.2, 0.2)))


# ------------------------------------------------------------------ coque commune des intérieurs


## Sol, mur du fond, murs des côtés, colombages et muret de façade avec sa porte : ce que partagent tous les
## intérieurs (la taverne comme les boutiques de ShopBuilder). `wall` (facultatif, [r, g, b]) change les murs.
static func _shell(it: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "interieur_" + str(it["id"])
	var fp: Array = it["footprint"]
	var x0 := float(fp[0])
	var y0 := float(fp[1])
	var x1 := float(fp[2])
	var y1 := float(fp[3])
	var fh := float(it.get("floor_h", 0.45))
	var ceil_h := float(it.get("ceiling", 6.6))
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	var w := x1 - x0
	var d := y1 - y0
	var door_x := float(it.get("door_x", cx))
	var wc: Array = it.get("wall", [])
	var wall_mat := ProcKit.flat(Color(float(wc[0]), float(wc[1]), float(wc[2])) if wc.size() == 3 else PLASTER)
	var beam := ProcKit.flat(WOOD_D)
	# sol de la salle (la dalle descend un peu sous le sol : sa face du dessus est à la hauteur fh)
	var top := fh + (0.03 if fh < 0.1 else 0.0)   # au ras du pavé, le plancher se confondrait avec lui
	var slab := top + 0.04
	ProcKit.box(root, Vector3(w - 0.3, slab, d - 0.3), ProcKit.w(cx, cy, slab * 0.5 - 0.04), ProcKit.wood(WOOD, Vector2((w - 0.3) * 0.5, (d - 0.3) * 0.5)))
	# mur du fond, murs des côtés
	ProcKit.box(root, Vector3(w, ceil_h, 0.3), ProcKit.w(cx, y1 - 0.15, ceil_h * 0.5), wall_mat)
	ProcKit.box(root, Vector3(0.3, ceil_h, d), ProcKit.w(x0 + 0.15, cy, ceil_h * 0.5), wall_mat)
	ProcKit.box(root, Vector3(0.3, ceil_h, d), ProcKit.w(x1 - 0.15, cy, ceil_h * 0.5), wall_mat)
	# 13/11 : un soubassement de bois sur les trois murs (lambris à hauteur d'appui, sa cimaise sombre, une plinthe) : les murs
	# n'étaient que de grands aplats d'enduit
	var panel := ProcKit.wood(WOOD, Vector2(maxf(w, d) * 0.5, 1.0))
	var rail := ProcKit.flat(WOOD_D)
	var ph := 1.05
	ProcKit.box(root, Vector3(w - 0.6, ph, 0.06), ProcKit.w(cx, y1 - 0.33, top + ph * 0.5), panel)
	ProcKit.box(root, Vector3(w - 0.6, 0.09, 0.1), ProcKit.w(cx, y1 - 0.35, top + ph + 0.045), rail)
	for sx: float in [x0 + 0.33, x1 - 0.33]:
		ProcKit.box(root, Vector3(0.06, ph, d - 0.6), ProcKit.w(sx, cy, top + ph * 0.5), panel)
		ProcKit.box(root, Vector3(0.1, 0.09, d - 0.6), ProcKit.w(sx + (0.02 if sx < cx else -0.02), cy, top + ph + 0.045), rail)
	# colombages sur le mur du fond
	var bx := x0 + 1.0
	while bx < x1:
		ProcKit.box(root, Vector3(0.22, ceil_h, 0.12), ProcKit.w(bx, y1 - 0.34, ceil_h * 0.5), beam)
		bx += 2.3
	for hh in [fh + 0.02, minf(3.3, ceil_h * 0.55), ceil_h - 0.1]:
		ProcKit.box(root, Vector3(w, 0.2, 0.14), ProcKit.w(cx, y1 - 0.36, hh), beam)
	# muret de façade, avec une porte
	var front_h := 0.95
	for seg: Array in [[x0, door_x - 0.85], [door_x + 0.85, x1]]:
		var sa := float(seg[0])
		var sb := float(seg[1])
		ProcKit.box(root, Vector3(sb - sa, front_h, 0.3), ProcKit.w((sa + sb) * 0.5, y0 + 0.15, front_h * 0.5), ProcKit.wood(WOOD_D, Vector2((sb - sa) * 0.5, 0.4)))
		ProcKit.box(root, Vector3(sb - sa, 0.1, 0.4), ProcKit.w((sa + sb) * 0.5, y0 + 0.15, front_h + 0.04), beam)
	for dx in [-0.85, 0.85]:
		ProcKit.box(root, Vector3(0.2, 2.5, 0.35), ProcKit.w(door_x + dx, y0 + 0.15, 1.25), beam)
	ProcKit.box(root, Vector3(1.9, 0.2, 0.35), ProcKit.w(door_x, y0 + 0.15, 2.5), beam)
	return root
