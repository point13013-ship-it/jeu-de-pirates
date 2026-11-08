class_name ShipCannons
extends RefCounted
## Les canons du bateau : gros, rouges et cuivrés pour qu'on les repère tout de suite sur le pont. Un canon est un
## nœud tourné vers l'extérieur (axe X du nœud = direction du tir), posé sur le pont à l'emplacement donné par les
## données du bateau ([x, y, côté, z] dans ship_meta.json). Le fût est un sous-nœud : il recule quand on tire.

const IRON := Color(0.17, 0.18, 0.23)
const IRON_L := Color(0.30, 0.32, 0.38)
const BRASS := Color(0.86, 0.62, 0.16)
const CARRIAGE := Color(0.60, 0.20, 0.14)
const CARRIAGE_D := Color(0.36, 0.12, 0.09)
const WOOD_L := Color(0.70, 0.50, 0.28)
const AXIS_HEIGHT := 0.50        ## m : hauteur de l'axe du fût au-dessus du pont
const MUZZLE_X := 1.18           ## m : la bouche, devant l'axe du nœud
const RECOIL := 0.42             ## m : recul du fût au tir
const GROW := 1.4                ## agrandissement de tout le canon (les haubans et le gréement cachent un petit canon)

static var _mats: Dictionary = {}


static func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html(false)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_mats[key] = m
	return _mats[key]


static func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Cylindre d'axe `axis` ("x", "y" ou "z"), `r_top` côté +axe.
static func _cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, axis: String, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = pos
	if axis == "x":
		mi.rotation = Vector3(0.0, 0.0, -PI / 2.0)   # le haut du cylindre (+Y) pointe vers +X
	elif axis == "z":
		mi.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	parent.add_child(mi)
	return mi


## Pose les canons sur le bateau. Renvoie un tableau [{root, barrel, loaded_marker}] dans l'ordre des données.
static func build(ship: ShipModel) -> Array:
	var out: Array = []
	for c: Array in ship.cannons:
		var side := float(c[2])
		var root := Node3D.new()
		var cx := (float(c[0]) + ship.shift) * ShipModel.SCALE
		var cz := -float(c[1]) * ShipModel.SCALE
		root.position = Vector3(cx, ship.deck_height(float(c[0])), cz)
		root.rotation.y = side * PI / 2.0   # l'axe X du nœud regarde vers l'extérieur
		# plus gros que nature : on doit les repérer d'un coup d'œil ; vers l'étrave, où le pont se resserre, un peu moins
		# (sinon la culasse des deux canons d'un même rang se touche au milieu)
		root.scale = Vector3.ONE * GROW * clampf(absf(float(c[1])) * ShipModel.SCALE / 1.9, 0.72, 1.0)
		ship.add_child(root)
		# affût : deux flancs rouges, un plateau et une traverse
		for z in [-0.30, 0.30]:
			_box(root, Vector3(1.05, 0.42, 0.13), Vector3(-0.02, 0.25, z), CARRIAGE)
			_box(root, Vector3(1.0, 0.05, 0.15), Vector3(-0.02, 0.47, z), CARRIAGE_D)
		_box(root, Vector3(0.95, 0.07, 0.72), Vector3(-0.02, 0.10, 0.0), CARRIAGE_D)
		_box(root, Vector3(0.12, 0.36, 0.72), Vector3(-0.50, 0.28, 0.0), CARRIAGE)
		# quatre roues pleines (essieux avant et arrière)
		for ax in [0.22, -0.34]:
			for z in [-0.40, 0.40]:
				var rad := 0.16 if ax > 0.0 else 0.19
				_cyl(root, rad, rad, 0.11, Vector3(ax, rad, z), "z", WOOD_L)
				_cyl(root, 0.06, 0.06, 0.13, Vector3(ax, rad, z), "z", IRON)
		# le fût : cône de fonte, frettes de laiton, bouche évasée, bouton de culasse
		var barrel := Node3D.new()
		barrel.position = Vector3(0.0, AXIS_HEIGHT, 0.0)
		root.add_child(barrel)
		_cyl(barrel, 0.20, 0.28, 1.55, Vector3(0.36, 0.0, 0.0), "x", IRON)
		_cyl(barrel, 0.29, 0.29, 0.07, Vector3(-0.22, 0.0, 0.0), "x", BRASS)
		_cyl(barrel, 0.27, 0.27, 0.07, Vector3(0.20, 0.0, 0.0), "x", BRASS)
		_cyl(barrel, 0.25, 0.24, 0.07, Vector3(0.62, 0.0, 0.0), "x", BRASS)
		_cyl(barrel, 0.26, 0.20, 0.16, Vector3(1.12, 0.0, 0.0), "x", IRON_L)
		_cyl(barrel, 0.26, 0.26, 0.05, Vector3(1.20, 0.0, 0.0), "x", BRASS)
		var knob := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		knob.mesh = sm
		knob.material_override = _mat(BRASS)
		knob.position = Vector3(-0.50, 0.0, 0.0)
		barrel.add_child(knob)
		# l'âme noire de la bouche (un disque sombre qui ferme le cylindre)
		_cyl(barrel, 0.12, 0.12, 0.02, Vector3(1.205, 0.0, 0.0), "x", Color(0.03, 0.03, 0.04))
		root.set_meta("barrel", barrel)
		out.append({"root": root, "barrel": barrel})
	return out


## Fait reculer le fût d'un canon (tir) puis le ramène.
static func kick(entry: Dictionary) -> void:
	var barrel := entry["barrel"] as Node3D
	var tw := barrel.create_tween()
	tw.tween_property(barrel, "position:x", -RECOIL, 0.07)
	tw.tween_property(barrel, "position:x", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Position de la bouche (repère du bateau) d'un canon.
static func muzzle_local(entry: Dictionary) -> Vector3:
	return (entry["root"] as Node3D).transform * Vector3(MUZZLE_X, AXIS_HEIGHT, 0.0)
