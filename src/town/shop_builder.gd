class_name ShopBuilder
extends RefCounted
## Les intérieurs des boutiques du port (tailleur, magasin général, voilerie), en coupe comme la taverne :
## pas de toit, pas de mur côté caméra. Chaque boutique est décrite dans data/town.json (`kind`, emplacement,
## porte, obstacles) ; le décor est posé ici. Positions en coordonnées du fichier du port (x, y) ; y croît vers
## le fond de la pièce (la porte est sur le côté y0, le comptoir près du mur du fond).

const WOOD := TownBuilder.WOOD
const WOOD_D := TownBuilder.WOOD_D
const WOOD_L := TownBuilder.WOOD_L
const IRON := TownBuilder.IRON
const CANVAS := Color(0.9, 0.86, 0.74)


## L'intérieur d'une boutique d'après son `kind` ("tailor", "store" ou "sails").
static func build(it: Dictionary) -> Node3D:
	var root := TownBuilder._shell(it)
	var fp: Array = it["footprint"]
	match str(it.get("kind", "")):
		"tailor":
			_tailor(root, it, fp)
		"store":
			_store(root, fp)
		"sails":
			_sails(root, fp)
	return root


# ------------------------------------------------------------------ petits éléments communs


static func _lamps(root: Node3D, pts: Array) -> void:
	for lp: Array in pts:
		var lamp := ProcKit.ball(root, 0.13, ProcKit.w(float(lp[0]), float(lp[1]), float(lp[2])), ProcKit.glow(Color(1.0, 0.85, 0.5)))
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.68, 0.32)
		light.light_energy = 1.3
		light.omni_range = 6.5
		light.shadow_enabled = false
		light.position = ProcKit.w(float(lp[0]), float(lp[1]), float(lp[2]) - 0.3)
		root.add_child(light)


## Comptoir de bois de (x0, y0) à (x1, y1), avec son plateau plus clair (dessus à 1,1 m).
static func _counter(root: Node3D, x0: float, y0: float, x1: float, y1: float) -> void:
	var w := x1 - x0
	var d := y1 - y0
	var c := Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
	ProcKit.box(root, Vector3(w, 1.0, d), ProcKit.w(c.x, c.y, 0.5), ProcKit.wood(WOOD_D, Vector2(w * 0.5, 0.5)))
	ProcKit.box(root, Vector3(w + 0.3, 0.1, d + 0.3), ProcKit.w(c.x, c.y, 1.05), ProcKit.flat(WOOD_L.darkened(0.15)))


## Montants et planches d'une étagère contre le mur du fond (y), de x0 sur `length` mètres, aux hauteurs `levels`.
static func _shelf_unit(root: Node3D, x0: float, y: float, length: float, levels: Array) -> void:
	var top: float = float(levels[levels.size() - 1]) + 0.5
	for sx in [x0, x0 + length]:
		ProcKit.box(root, Vector3(0.12, top, 0.45), ProcKit.w(sx, y, top * 0.5), ProcKit.flat(WOOD_D))
	for lv: float in levels:
		ProcKit.box(root, Vector3(length, 0.08, 0.45), ProcKit.w(x0 + length * 0.5, y, lv), ProcKit.flat(WOOD))


static func _crate(root: Node3D, x: float, y: float, z: float, s: float, rot: float = 0.0) -> void:
	ProcKit.box(root, Vector3(s, s, s), ProcKit.w(x, y, z + s * 0.5), ProcKit.wood(WOOD_L.darkened(0.15), Vector2(1, 1)), Vector3(0, rot, 0))
	ProcKit.box(root, Vector3(s + 0.03, 0.06, s + 0.03), ProcKit.w(x, y, z + s * 0.5), ProcKit.flat(WOOD_D), Vector3(0, rot, 0))


static func _barrel(root: Node3D, x: float, y: float, z: float, r: float = 0.42, hgt: float = 0.9) -> void:
	ProcKit.cyl(root, r, hgt, ProcKit.w(x, y, z + hgt * 0.5), ProcKit.flat(Color(0.5, 0.33, 0.18)))
	ProcKit.cyl(root, r + 0.02, 0.06, ProcKit.w(x, y, z + hgt * 0.25), ProcKit.flat(IRON))
	ProcKit.cyl(root, r + 0.02, 0.06, ProcKit.w(x, y, z + hgt * 0.78), ProcKit.flat(IRON))


static func _rope_coil(root: Node3D, x: float, y: float) -> void:
	ProcKit.cyl(root, 0.4, 0.22, ProcKit.w(x, y, 0.11), ProcKit.flat(Color(0.74, 0.62, 0.4)))
	ProcKit.cyl(root, 0.14, 0.24, ProcKit.w(x, y, 0.12), ProcKit.flat(Color(0.5, 0.4, 0.25)))


# ------------------------------------------------------------------ tailleur


static func _tailor(root: Node3D, it: Dictionary, fp: Array) -> void:
	var x0 := float(fp[0])
	var y0 := float(fp[1])
	var x1 := float(fp[2])
	var y1 := float(fp[3])
	var cx := (x0 + x1) * 0.5
	var dx := float(it.get("door_x", cx))
	# tapis rond devant l'entrée
	ProcKit.cyl(root, 1.9, 0.03, ProcKit.w(dx, y0 + 3.0, 0.015), ProcKit.flat(Color(0.62, 0.2, 0.22)))
	ProcKit.cyl(root, 1.5, 0.035, ProcKit.w(dx, y0 + 3.0, 0.018), ProcKit.flat(Color(0.86, 0.72, 0.4)))
	ProcKit.cyl(root, 1.1, 0.04, ProcKit.w(dx, y0 + 3.0, 0.02), ProcKit.flat(Color(0.62, 0.2, 0.22)))
	# comptoir, avec mètre-ruban, ciseaux et pelote
	_counter(root, cx - 2.6, y1 - 3.4, cx + 2.2, y1 - 2.4)
	ProcKit.box(root, Vector3(1.4, 0.02, 0.1), ProcKit.w(cx - 0.8, y1 - 2.9, 1.12), ProcKit.flat(Color(0.95, 0.85, 0.5)))
	ProcKit.box(root, Vector3(0.5, 0.03, 0.12), ProcKit.w(cx + 1.2, y1 - 2.9, 1.13), ProcKit.flat(IRON), Vector3(0, 0.5, 0))
	ProcKit.cyl(root, 0.18, 0.2, ProcKit.w(cx - 2.0, y1 - 2.9, 1.2), ProcKit.flat(Color(0.8, 0.3, 0.35)))
	# rouleaux de tissu rangés sur le mur du fond
	var cloth := [Color(0.25, 0.4, 0.75), Color(0.85, 0.3, 0.3), Color(0.9, 0.78, 0.35), Color(0.3, 0.6, 0.4),
			Color(0.62, 0.35, 0.72), Color(0.92, 0.9, 0.82)]
	_shelf_unit(root, x0 + 0.7, y1 - 0.62, 8.5, [0.9, 1.9, 2.9])
	for row in 3:
		for k in 14:
			ProcKit.cyl(root, 0.17, 0.55, ProcKit.w(x0 + 1.0 + float(k) * 0.6, y1 - 0.62, 0.9 + float(row) + 0.2),
					ProcKit.flat(cloth[(k + row * 2) % cloth.size()] as Color), Vector3(PI / 2.0, 0, 0))
	# deux mannequins de couturière près de la vitrine
	for m: Array in [[x0 + 1.4, y0 + 1.9, Color(0.22, 0.32, 0.6)], [x1 - 1.4, y0 + 1.9, Color(0.7, 0.2, 0.25)]]:
		var mx := float(m[0])
		var my := float(m[1])
		var col: Color = m[2]
		ProcKit.cyl(root, 0.32, 0.04, ProcKit.w(mx, my, 0.02), ProcKit.flat(WOOD_D))
		ProcKit.cyl(root, 0.04, 0.9, ProcKit.w(mx, my, 0.5), ProcKit.flat(WOOD_D))
		ProcKit.cyl(root, 0.3, 0.7, ProcKit.w(mx, my, 1.35), ProcKit.flat(col))
		ProcKit.cyl(root, 0.18, 0.2, ProcKit.w(mx, my, 1.8), ProcKit.flat(col.lightened(0.15)))
		ProcKit.ball(root, 0.14, ProcKit.w(mx, my, 2.0), ProcKit.flat(Color(0.88, 0.72, 0.55)))
	# portant à manteaux le long du mur est
	var coats := [Color(0.7, 0.2, 0.2), Color(0.2, 0.3, 0.55), Color(0.25, 0.45, 0.3), Color(0.55, 0.4, 0.2), Color(0.3, 0.3, 0.35)]
	for ry in [y0 + 4.3, y0 + 7.7]:
		ProcKit.box(root, Vector3(0.08, 2.0, 0.08), ProcKit.w(x1 - 0.7, ry, 1.0), ProcKit.flat(WOOD_D))
	ProcKit.box(root, Vector3(0.08, 0.08, 3.5), ProcKit.w(x1 - 0.7, y0 + 6.0, 1.95), ProcKit.flat(WOOD_D))
	for k in 7:
		ProcKit.box(root, Vector3(0.14, 1.15, 0.45), ProcKit.w(x1 - 0.7, y0 + 4.5 + float(k) * 0.5, 1.3), ProcKit.flat(coats[k % coats.size()] as Color))
	# chapeaux sur une étagère à l'ouest
	ProcKit.box(root, Vector3(0.4, 0.07, 3.0), ProcKit.w(x0 + 0.6, y0 + 5.5, 1.8), ProcKit.flat(WOOD))
	for k in 5:
		var hc: Color = (coats[k % coats.size()] as Color).darkened(0.2)
		ProcKit.cyl(root, 0.22, 0.05, ProcKit.w(x0 + 0.6, y0 + 4.3 + float(k) * 0.55, 1.86), ProcKit.flat(hc))
		ProcKit.cyl(root, 0.13, 0.16, ProcKit.w(x0 + 0.6, y0 + 4.3 + float(k) * 0.55, 1.95), ProcKit.flat(hc))
	# miroir de cabine, cadre doré
	ProcKit.box(root, Vector3(1.1, 2.1, 0.07), ProcKit.w(x1 - 1.9, y1 - 0.45, 1.25), ProcKit.flat(Color(0.82, 0.65, 0.22), 0.4))
	ProcKit.box(root, Vector3(0.88, 1.85, 0.04), ProcKit.w(x1 - 1.9, y1 - 0.5, 1.25), ProcKit.flat(Color(0.75, 0.88, 0.95), 0.1))
	# table de coupe avec une pièce d'étoffe bleue
	var tx := x0 + 2.6
	var ty := y0 + 3.6
	ProcKit.box(root, Vector3(1.8, 0.1, 1.0), ProcKit.w(tx, ty, 0.85), ProcKit.wood(WOOD_L, Vector2(1, 1)))
	for kx in [-0.8, 0.8]:
		for ky in [-0.4, 0.4]:
			ProcKit.box(root, Vector3(0.1, 0.8, 0.1), ProcKit.w(tx + kx, ty + ky, 0.4), ProcKit.flat(WOOD_D))
	ProcKit.box(root, Vector3(1.5, 0.03, 0.8), ProcKit.w(tx, ty, 0.92), ProcKit.flat(Color(0.25, 0.4, 0.75)))
	_lamps(root, [[x0 + 2.5, y0 + 2.8, 3.6], [x1 - 2.5, y0 + 2.8, 3.6], [cx, y1 - 1.8, 3.8]])


# ------------------------------------------------------------------ magasin général


static func _store(root: Node3D, fp: Array) -> void:
	var x0 := float(fp[0])
	var y0 := float(fp[1])
	var x1 := float(fp[2])
	var y1 := float(fp[3])
	var cx := (x0 + x1) * 0.5
	# comptoir central, avec une balance et des sacs
	_counter(root, cx - 2.3, y1 - 3.6, cx + 2.3, y1 - 2.6)
	ProcKit.box(root, Vector3(0.5, 0.05, 0.4), ProcKit.w(cx - 1.2, y1 - 3.1, 1.13), ProcKit.flat(IRON))
	for sx in [-1.35, -1.05]:
		ProcKit.cyl(root, 0.15, 0.03, ProcKit.w(cx + sx, y1 - 3.1, 1.22), ProcKit.flat(Color(0.8, 0.7, 0.4)))
	for k in 3:
		var sack := ProcKit.ball(root, 0.2, ProcKit.w(cx + 0.7 + float(k) * 0.45, y1 - 3.1, 1.25), ProcKit.flat(Color(0.8, 0.7, 0.5)))
		sack.scale = Vector3(1.0, 0.8, 1.0)
	# étagères du fond : caissettes de biscuits, conserves, cordages
	_shelf_unit(root, x0 + 0.6, y1 - 0.62, 9.6, [0.5, 1.5, 2.5])
	var tins := [Color(0.8, 0.6, 0.25), Color(0.65, 0.3, 0.2), Color(0.35, 0.5, 0.35), Color(0.55, 0.55, 0.6)]
	for row in 3:
		for k in 16:
			var xx := x0 + 0.95 + float(k) * 0.58
			if row == 0:
				ProcKit.box(root, Vector3(0.42, 0.34, 0.34), ProcKit.w(xx, y1 - 0.62, 0.7), ProcKit.wood(WOOD_L.darkened(0.1), Vector2(1, 1)))
			elif row == 1:
				ProcKit.cyl(root, 0.13, 0.28, ProcKit.w(xx, y1 - 0.62, 1.68), ProcKit.flat(tins[k % tins.size()] as Color))
			else:
				ProcKit.cyl(root, 0.17, 0.2, ProcKit.w(xx, y1 - 0.62, 2.64), ProcKit.flat(Color(0.7, 0.58, 0.35)))
	# pyramide de boulets de canon sur un plateau
	var px := x0 + 2.0
	var py := y0 + 4.2
	ProcKit.box(root, Vector3(1.5, 0.22, 1.5), ProcKit.w(px, py, 0.11), ProcKit.flat(WOOD_D))
	for row in 3:
		var n := 3 - row
		for i in n:
			for j in n:
				ProcKit.ball(root, 0.2, ProcKit.w(px - float(n - 1) * 0.21 + float(i) * 0.42, py - float(n - 1) * 0.21 + float(j) * 0.42, 0.42 + float(row) * 0.34),
						ProcKit.flat(IRON.lightened(0.05), 0.5))
	# piles de planches contre le mur est
	ProcKit.box(root, Vector3(0.9, 0.5, 2.6), ProcKit.w(x1 - 0.85, y0 + 4.0, 0.25), ProcKit.wood(WOOD_L, Vector2(1, 1)))
	ProcKit.box(root, Vector3(0.9, 0.5, 2.6), ProcKit.w(x1 - 0.85, y0 + 4.0, 0.78), ProcKit.wood(WOOD_L.darkened(0.12), Vector2(1, 1)))
	ProcKit.box(root, Vector3(0.9, 0.5, 2.6), ProcKit.w(x1 - 0.85, y0 + 4.0, 1.31), ProcKit.wood(WOOD_L, Vector2(1, 1)))
	# tonneaux le long du mur ouest, caisses et cordages près de la vitrine
	for k in 3:
		_barrel(root, x0 + 0.7, y0 + 5.6 + float(k) * 0.95, 0.0)
	_crate(root, x1 - 1.2, y0 + 1.6, 0.0, 0.8, 0.2)
	_crate(root, x1 - 2.1, y0 + 1.5, 0.0, 0.7, -0.1)
	_crate(root, x1 - 1.55, y0 + 1.55, 0.8, 0.55, 0.4)
	_rope_coil(root, x0 + 1.4, y0 + 1.6)
	_rope_coil(root, x0 + 2.3, y0 + 1.6)
	# poutre au plafond, jambons suspendus
	ProcKit.box(root, Vector3(x1 - x0, 0.25, 0.25), ProcKit.w(cx, y0 + 3.0, 4.3), ProcKit.flat(WOOD_D))
	for k in 5:
		var hx := x0 + 2.0 + float(k) * 1.8
		ProcKit.cyl(root, 0.015, 0.7, ProcKit.w(hx, y0 + 3.0, 3.9), ProcKit.flat(IRON))
		var ham := ProcKit.ball(root, 0.2, ProcKit.w(hx, y0 + 3.0, 3.45), ProcKit.flat(Color(0.7, 0.35, 0.3)))
		ham.scale = Vector3(0.8, 1.2, 0.8)
	_lamps(root, [[x0 + 2.0, y0 + 2.5, 3.5], [x1 - 2.0, y0 + 2.5, 3.5], [cx, y1 - 1.8, 3.8]])


# ------------------------------------------------------------------ voilerie


static func _sails(root: Node3D, fp: Array) -> void:
	var x0 := float(fp[0])
	var y0 := float(fp[1])
	var x1 := float(fp[2])
	var y1 := float(fp[3])
	var cx := (x0 + x1) * 0.5
	# grande voile carrée pendue à une vergue, avec ses lattes de ris et un pavillon noir
	ProcKit.cyl(root, 0.07, 5.2, ProcKit.w(cx - 0.6, y1 - 0.5, 4.3), ProcKit.flat(WOOD_D), Vector3(0, 0, PI / 2.0))
	ProcKit.box(root, Vector3(4.0, 2.7, 0.05), ProcKit.w(cx - 0.6, y1 - 0.5, 2.85), ProcKit.flat(CANVAS.darkened(0.04)))
	for k in 3:
		ProcKit.box(root, Vector3(0.05, 2.7, 0.07), ProcKit.w(cx - 2.1 + float(k) * 1.5, y1 - 0.53, 2.85), ProcKit.flat(CANVAS.darkened(0.25)))
	ProcKit.box(root, Vector3(0.9, 0.9, 0.06), ProcKit.w(cx - 0.6, y1 - 0.54, 3.1), ProcKit.flat(Color(0.08, 0.08, 0.1)))
	ProcKit.ball(root, 0.2, ProcKit.w(cx - 0.6, y1 - 0.58, 3.12), ProcKit.flat(Color(0.92, 0.9, 0.85)))
	# une voile bleue, pliée, sur le mur est
	ProcKit.box(root, Vector3(2.0, 2.2, 0.05), ProcKit.w(x1 - 1.7, y1 - 0.5, 2.6), ProcKit.flat(Color(0.35, 0.5, 0.72)))
	ProcKit.box(root, Vector3(2.2, 0.1, 0.1), ProcKit.w(x1 - 1.7, y1 - 0.5, 3.75), ProcKit.flat(WOOD_D))
	# grande table de coupe avec la toile, une règle et des aiguilles
	var tx := x0 + 2.4
	var ty := y0 + 3.6
	ProcKit.box(root, Vector3(3.0, 0.12, 1.6), ProcKit.w(tx, ty, 0.95), ProcKit.wood(WOOD_L, Vector2(1, 1)))
	for kx in [-1.35, 1.35]:
		for ky in [-0.65, 0.65]:
			ProcKit.box(root, Vector3(0.14, 0.9, 0.14), ProcKit.w(tx + kx, ty + ky, 0.45), ProcKit.flat(WOOD_D))
	ProcKit.box(root, Vector3(2.5, 0.04, 1.3), ProcKit.w(tx - 0.1, ty, 1.03), ProcKit.flat(CANVAS))
	ProcKit.box(root, Vector3(0.9, 0.03, 0.04), ProcKit.w(tx + 0.5, ty + 0.2, 1.07), ProcKit.flat(IRON), Vector3(0, 0.4, 0))
	# comptoir à l'est, avec ses bobines de fil
	_counter(root, x1 - 4.4, y1 - 4.6, x1 - 1.0, y1 - 3.6)
	var thread := [Color(0.8, 0.25, 0.25), Color(0.25, 0.4, 0.75), Color(0.9, 0.8, 0.3)]
	for k in 6:
		ProcKit.cyl(root, 0.1, 0.18, ProcKit.w(x1 - 4.0 + float(k) * 0.5, y1 - 4.1, 1.2), ProcKit.flat(thread[k % 3] as Color))
	# balles de toile roulées contre le mur ouest
	for k in 4:
		var bx := x0 + 0.65 + float(k % 2) * 0.62
		var by := y0 + 7.2 + float(floori(k / 2.0)) * 0.7
		ProcKit.cyl(root, 0.3, 1.9, ProcKit.w(bx, by, 0.95), ProcKit.flat(CANVAS.darkened(float(k) * 0.03)))
		ProcKit.cyl(root, 0.31, 0.06, ProcKit.w(bx, by, 0.55), ProcKit.flat(Color(0.5, 0.35, 0.2)))
	# un mât de rechange debout dans le coin, cerclé de fer, et un rouleau de corde
	ProcKit.cyl(root, 0.16, 4.4, ProcKit.w(x1 - 0.7, y0 + 0.9, 2.2), ProcKit.wood(WOOD_L, Vector2(1, 4)))
	for k in 3:
		ProcKit.cyl(root, 0.19, 0.08, ProcKit.w(x1 - 0.7, y0 + 0.9, 0.6 + float(k) * 1.2), ProcKit.flat(IRON))
	_rope_coil(root, x1 - 1.8, y0 + 1.0)
	# maquette de navire sur une console
	ProcKit.box(root, Vector3(0.5, 0.08, 1.2), ProcKit.w(x0 + 0.6, y1 - 4.0, 1.4), ProcKit.flat(WOOD))
	ProcKit.box(root, Vector3(0.28, 0.18, 0.9), ProcKit.w(x0 + 0.6, y1 - 4.0, 1.54), ProcKit.flat(WOOD_D))
	ProcKit.cyl(root, 0.02, 0.6, ProcKit.w(x0 + 0.6, y1 - 4.0, 1.85), ProcKit.flat(WOOD_D))
	ProcKit.box(root, Vector3(0.015, 0.4, 0.32), ProcKit.w(x0 + 0.6, y1 - 4.0, 1.85), ProcKit.flat(CANVAS))
	_lamps(root, [[x0 + 2.0, y0 + 2.5, 3.6], [x1 - 2.0, y0 + 2.5, 3.6], [cx, y1 - 2.2, 4.0]])
