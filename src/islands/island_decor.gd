class_name IslandDecor
extends RefCounted
## Le décor des îles : palmiers, buissons, fougères, rochers, tonneaux, tombes, arbres morts, tours, épave, etc.
## Presque tout est assemblé en un seul maillage par objet (MeshKit). Positions en mètres, dans le repère du parent ;
## le sol des îles est à la hauteur 0. Les couleurs sont choisies dans la palette du filtre pixel art.

const BARK := Color(0.52, 0.38, 0.24)
const BARK_D := Color(0.4, 0.28, 0.18)
const BARK_L := Color(0.62, 0.46, 0.3)
const GREENS: Array[Color] = [Color(0.2, 0.45, 0.16), Color(0.15, 0.36, 0.14), Color(0.26, 0.52, 0.18), Color(0.18, 0.42, 0.2)]
const WOOD := Color(0.52, 0.34, 0.2)
const WOOD_D := Color(0.32, 0.2, 0.12)
const STONE := Color(0.5, 0.47, 0.46)
const STONE_D := Color(0.38, 0.36, 0.38)
const BONE := Color(0.9, 0.87, 0.76)
const SHIP_PATH := "res://assets/models/ship/%s.glb"

## Cercles bloquants [dx, dz, rayon] (relatifs à l'objet, avant rotation) par type d'objet.
const BLOCK := {
	"barrel": [[0, 0, 0.42]], "grave": [[0, 0, 0.42]], "tent": [[0, 0, 1.0]], "campfire": [[0, 0, 0.6]],
	"flag": [[0, 0, 0.2]], "palm": [[0, 0, 0.32]], "dead_tree": [[0, 0, 0.3]], "pillar": [[0, 0, 0.6]],
	"skull_rock": [[0, 0, 2.3]], "tower": [[0, 0, 1.9]], "cannon": [[0, 0, 0.7]], "crate": [[0, 0, 0.55]],
	"pond": [[0, 0, 1.7]], "driftwood": [[0, 0, 0.5]], "rowboat": [[0, 0, 1.2]], "hut": [[0, 0, 2.1]],
	"sandcastle": [[0, 0, 0.6]], "totem": [[0, 0, 0.45]], "arch": [[-2.0, 0, 0.9], [2.0, 0, 0.9]],
	"wreck": [[-9, 0, 2.3], [-4.5, 0, 2.5], [0, 0, 2.6], [4.5, 0, 2.5], [9, 0, 2.3]],
}


static func prop_yaw(d: Dictionary, seed_value: int) -> float:
	if d.has("rot"):
		return deg_to_rad(float(d["rot"]))
	return float((seed_value * 37) % 100) / 100.0 * TAU


## Cercles bloquants monde (x, z, r) d'un objet posé en `at` avec l'angle `yaw`.
static func blockers(kind: String, at: Vector2, yaw: float) -> Array:
	var out: Array = []
	for c: Array in BLOCK.get(kind, []):
		var off := Vector2(float(c[0]), float(c[1]))
		# rotation d'axe Y de `yaw` : x -> (cos, -sin)
		var w := Vector2(off.x * cos(yaw) + off.y * sin(yaw), -off.x * sin(yaw) + off.y * cos(yaw))
		out.append(Vector3(at.x + w.x, at.y + w.y, float(c[2])))
	return out


## Pose un objet de décor de type `kind`.
static func make(parent: Node3D, kind: String, at: Vector2, yaw: float, seed_value: int, d: Dictionary = {}, y: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(at.x, y, at.y)
	root.rotation.y = yaw
	root.name = kind
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5100 + seed_value
	match kind:
		"palm": palm(root, rng)
		"bush": bush(root, rng)
		"fern": fern(root, rng)
		"dead_tree": dead_tree(root, rng)
		"rock": rock(root, rng.randf_range(0.5, 1.0), seed_value)
		"rock_spire": rock_spire(root, rng.randf_range(0.9, 1.4), seed_value)
		"driftwood": driftwood(root, rng)
		"barrel": barrel(root)
		"crate": crate(root, rng)
		"grave": grave(root)
		"bones": bones(root)
		"xmark": xmark(root)
		"tent": tent(root)
		"campfire": campfire(root)
		"flag": flag(root, str(d.get("color", "black")))
		"pond": pond(root, rng)
		"pillar": pillar(root, rng)
		"skull_rock": skull_rock(root)
		"tower": tower(root, str(d.get("color", "blue")))
		"cannon": cannon(root)
		"rowboat": rowboat(root)
		"hut": hut(root)
		"sandcastle": sandcastle(root)
		"totem": totem(root)
		"arch": arch(root, seed_value)
		"wreck": wreck(root, str(d.get("ship", "galion")))
		"wall":
			root.position = Vector3.ZERO
			root.rotation = Vector3.ZERO
			wall(root, Vector2(float(d["from"][0]), float(d["from"][1])), Vector2(float(d["to"][0]), float(d["to"][1])))
	return root


static func _xf(pos: Vector3, euler: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(euler), pos)


# ------------------------------------------------------------------ végétation

static func palm(root: Node3D, rng: RandomNumberGenerator) -> void:
	var k := MeshKit.new()
	var height := rng.randf_range(3.6, 5.0)
	var lean := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.2, 0.9)
	var segs := 7
	var prev := Vector3.ZERO
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var cur := Vector3(lean.x * t * t * height * 0.35, height * t, lean.y * t * t * height * 0.35)
		var ring := BARK_L if i % 2 == 0 else BARK
		k.between(prev, cur, 0.2 - 0.07 * (t - 1.0 / segs), 0.2 - 0.07 * t, ring, 7)
		prev = cur
	var top := prev
	# régime de noix de coco
	for n in 4:
		var a := TAU * n / 4.0 + 0.5
		k.ball(_xf(top + Vector3(cos(a) * 0.2, -0.15, sin(a) * 0.2)), 0.12, Color(0.34, 0.22, 0.12), 6, 3)
	# palmes : quatre segments de plus en plus penchés vers le sol, de plus en plus fines
	var fronds := 9
	var tone0 := rng.randi() % 2
	for f in fronds:
		var a := TAU * f / fronds + rng.randf() * 0.25
		var dir_h := Vector3(cos(a), 0, sin(a))
		var pos := top
		var pitch := rng.randf_range(0.25, 0.5)
		var col := GREENS[(f + tone0) % 4]
		var widths := [0.42, 0.38, 0.3, 0.18]
		for sgi in 4:
			var d := (dir_h * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
			var len := 0.6
			var mid := pos + d * len * 0.5
			var basis := MeshKit.look(d)
			k.box(Transform3D(basis, mid), Vector3(float(widths[sgi]), 0.045, len * 1.05), col)
			# nervure sombre au-dessus
			k.box(Transform3D(basis, mid + Vector3.UP * 0.03), Vector3(0.05, 0.03, len * 1.05), Color(0.17, 0.4, 0.16))
			pos += d * len
			pitch -= rng.randf_range(0.3, 0.5)
	var mi := k.instance(root)
	mi.material_override = MeshKit.sway_material()
	mi.set_instance_shader_parameter("phase", rng.randf() * TAU)


static func bush(root: Node3D, rng: RandomNumberGenerator) -> void:
	var k := MeshKit.new()
	var count := rng.randi_range(4, 6)
	for i in count:
		var a := TAU * i / count + rng.randf()
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.55)
		var r := rng.randf_range(0.34, 0.55)
		k.ball(_xf(off + Vector3(0, r * 0.6, 0), Vector3(0, rng.randf() * TAU, 0)), r, GREENS[rng.randi() % 4], 7, 4)
	# fleurs : de petites boules de couleur sur le dessus
	if rng.randf() < 0.7:
		var fc: Color = [Color(0.98, 0.82, 0.33), Color(0.84, 0.33, 0.36), Color(0.93, 0.59, 0.67), Color(0.98, 0.95, 0.88)][rng.randi() % 4]
		for i in rng.randi_range(3, 6):
			var a := rng.randf() * TAU
			k.ball(_xf(Vector3(cos(a), 0.75 + rng.randf() * 0.2, sin(a)) * Vector3(0.45, 1.0, 0.45)), 0.07, fc, 5, 3)
	var mi := k.instance(root)
	mi.material_override = MeshKit.sway_material(1.1, 0.45)
	mi.set_instance_shader_parameter("phase", rng.randf() * TAU)


static func fern(root: Node3D, rng: RandomNumberGenerator) -> void:
	var k := MeshKit.new()
	var n := rng.randi_range(6, 8)
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.2
		var dir := Vector3(cos(a), 0.5, sin(a)).normalized()
		var p0 := Vector3(0, 0.05, 0)
		var d1 := Vector3(cos(a), 0.55, sin(a)).normalized()
		var d2 := Vector3(cos(a), -0.1, sin(a)).normalized()
		var col := GREENS[i % 4]
		k.box(Transform3D(MeshKit.look(d1), p0 + d1 * 0.25), Vector3(0.2, 0.03, 0.5), col)
		var p1 := p0 + d1 * 0.5
		k.box(Transform3D(MeshKit.look(d2), p1 + d2 * 0.22), Vector3(0.14, 0.03, 0.45), col)
		dir += Vector3.ZERO
	var mi := k.instance(root)
	mi.material_override = MeshKit.sway_material(0.6, 0.5)
	mi.set_instance_shader_parameter("phase", rng.randf() * TAU)


static func dead_tree(root: Node3D, rng: RandomNumberGenerator) -> void:
	var k := MeshKit.new()
	var col := Color(0.32, 0.27, 0.26)
	var col_d := Color(0.28, 0.24, 0.26)
	var top := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(2.4, 3.2), rng.randf_range(-0.3, 0.3))
	k.between(Vector3.ZERO, top * 0.5, 0.28, 0.2, col, 6)
	k.between(top * 0.5, top, 0.2, 0.09, col_d, 6)
	for i in rng.randi_range(3, 4):
		var a := rng.randf() * TAU
		var start := top * rng.randf_range(0.45, 0.85)
		var end := start + Vector3(cos(a) * rng.randf_range(0.7, 1.3), rng.randf_range(0.3, 0.8), sin(a) * rng.randf_range(0.7, 1.3))
		k.between(start, end, 0.09, 0.04, col, 5)
		var end2 := end + Vector3(cos(a + 0.7) * 0.5, 0.35, sin(a + 0.7) * 0.5)
		k.between(end, end2, 0.04, 0.02, col_d, 4)
	k.instance(root)


## Rocher à facettes (le même que les récifs), avec un peu de mousse dessus.
static func rock(root: Node3D, radius: float, seed_value: int, tall: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = SeaRocks.rock_mesh(seed_value + 300, radius)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	mi.scale = Vector3(1.0, tall, 1.0)
	mi.rotation.y = float(seed_value) * 1.7
	root.add_child(mi)
	var k := MeshKit.new()
	k.ball(_xf(Vector3(radius * 0.1, radius * 0.62 * tall, 0), Vector3.ZERO), radius * 0.5, Color(0.3, 0.58, 0.24), 7, 3)
	k.instance(root)


static func rock_spire(root: Node3D, radius: float, seed_value: int) -> void:
	rock(root, radius, seed_value, 2.6)
	var k := MeshKit.new()
	k.ball(_xf(Vector3(radius * 0.7, radius * 0.4, radius * 0.2)), radius * 0.45, Color(0.33, 0.31, 0.33), 6, 3)
	k.instance(root)


static func driftwood(root: Node3D, rng: RandomNumberGenerator) -> void:
	var k := MeshKit.new()
	var col := Color(0.62, 0.52, 0.42)
	k.between(Vector3(-0.7, 0.12, 0), Vector3(0.8, 0.1, 0.1), 0.12, 0.09, col, 6)
	k.between(Vector3(0.1, 0.1, 0.05), Vector3(0.5, 0.32, 0.5), 0.05, 0.03, Color(0.5, 0.42, 0.34), 5)
	k.instance(root)


# ------------------------------------------------------------------ objets

static func barrel(root: Node3D) -> void:
	var k := MeshKit.new()
	k.cyl(_xf(Vector3(0, 0.4, 0)), 0.3, 0.3, 0.8, WOOD, 10)
	k.cyl(_xf(Vector3(0, 0.4, 0)), 0.345, 0.345, 0.5, WOOD, 10)
	for y in [0.14, 0.66]:
		k.cyl(_xf(Vector3(0, y, 0)), 0.355, 0.355, 0.06, Color(0.2, 0.2, 0.24), 10)
	k.cyl(_xf(Vector3(0, 0.805, 0)), 0.27, 0.27, 0.02, WOOD_D, 10)
	k.instance(root)


static func crate(root: Node3D, rng: RandomNumberGenerator) -> void:
	var k := MeshKit.new()
	var s := rng.randf_range(0.7, 0.9)
	k.box(_xf(Vector3(0, s * 0.5, 0), Vector3(0, rng.randf_range(-0.3, 0.3), 0)), Vector3(s, s, s), WOOD)
	for sx in [-1, 1]:
		k.box(_xf(Vector3(sx * s * 0.45, s * 0.5, 0)), Vector3(0.08, s + 0.02, s + 0.02), WOOD_D)
	k.box(_xf(Vector3(0, s + 0.02, 0)), Vector3(s + 0.04, 0.05, 0.12), WOOD_D)
	k.instance(root)


static func grave(root: Node3D) -> void:
	var k := MeshKit.new()
	k.box(_xf(Vector3(0, 0.4, 0)), Vector3(0.62, 0.8, 0.16), STONE)
	k.cyl(_xf(Vector3(0, 0.8, 0), Vector3(PI / 2.0, 0, 0)), 0.31, 0.31, 0.16, STONE, 8)
	k.box(_xf(Vector3(0, 0.55, 0.09)), Vector3(0.08, 0.34, 0.02), STONE_D)
	k.box(_xf(Vector3(0, 0.62, 0.09)), Vector3(0.26, 0.08, 0.02), STONE_D)
	k.box(_xf(Vector3(0, 0.06, 0.55)), Vector3(0.74, 0.12, 0.9), Color(0.36, 0.28, 0.2))
	k.instance(root)


static func bones(root: Node3D) -> void:
	var k := MeshKit.new()
	k.ball(_xf(Vector3(0, 0.13, 0), Vector3.ZERO), 0.14, BONE, 6, 3)
	for sx in [-1.0, 1.0]:
		k.ball(_xf(Vector3(sx * 0.06, 0.16, 0.11)), 0.035, Color(0.1, 0.08, 0.09), 4, 2)
	for i in 4:
		k.between(Vector3(0.3 + i * 0.06, 0.03, -0.15 + i * 0.16), Vector3(0.62 + i * 0.06, 0.05, 0.05 + i * 0.16), 0.025, 0.025, BONE, 4)
	k.instance(root)


static func xmark(root: Node3D) -> void:
	var k := MeshKit.new()
	for s in [-1.0, 1.0]:
		k.box(_xf(Vector3(0, 0.025, 0), Vector3(0, s * PI / 4.0, 0)), Vector3(1.5, 0.03, 0.17), Color(0.7, 0.12, 0.1))
	k.instance(root)


static func tent(root: Node3D) -> void:
	var k := MeshKit.new()
	var cloth := Color(0.82, 0.72, 0.5)
	var cloth_d := Color(0.7, 0.6, 0.42)
	k.box(_xf(Vector3(-0.55, 0.62, 0), Vector3(0, 0, deg_to_rad(52.0))), Vector3(1.9, 0.06, 1.7), cloth)
	k.box(_xf(Vector3(0.55, 0.62, 0), Vector3(0, 0, deg_to_rad(-52.0))), Vector3(1.9, 0.06, 1.7), cloth_d)
	k.box(_xf(Vector3(0, 0.45, 0.85)), Vector3(1.0, 0.9, 0.04), cloth_d)
	# bandes rouges le long des pentes de toile
	for z in [-0.6, 0.0, 0.6]:
		k.box(_xf(Vector3(-0.552, 0.626, z), Vector3(0, 0, deg_to_rad(52.0))), Vector3(1.9, 0.07, 0.2), Color(0.84, 0.33, 0.36))
		k.box(_xf(Vector3(0.552, 0.626, z), Vector3(0, 0, deg_to_rad(-52.0))), Vector3(1.9, 0.07, 0.2), Color(0.84, 0.33, 0.36))
	k.between(Vector3(0, 0, 0.9), Vector3(0, 1.4, 0.9), 0.05, 0.05, WOOD_D)
	k.between(Vector3(0, 0, -0.9), Vector3(0, 1.4, -0.9), 0.05, 0.05, WOOD_D)
	k.instance(root)


static func campfire(root: Node3D) -> void:
	var k := MeshKit.new()
	for i in 3:
		var a := i * TAU / 3.0
		k.between(Vector3(cos(a) * 0.35, 0.05, sin(a) * 0.35), Vector3(-cos(a) * 0.2, 0.2, -sin(a) * 0.2), 0.07, 0.07, WOOD_D, 5)
	for i in 8:
		var a := TAU * i / 8.0
		k.ball(_xf(Vector3(cos(a) * 0.52, 0.07, sin(a) * 0.52)), 0.11, STONE if i % 2 == 0 else STONE_D, 5, 3)
	k.instance(root)
	var flame := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = 0.6
	cone.radial_segments = 6
	flame.mesh = cone
	flame.material_override = ProcKit.glow(Color(1.0, 0.62, 0.15))
	flame.position = Vector3(0, 0.38, 0)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.omni_range = 4.5
	light.light_energy = 0.9
	light.position = Vector3(0, 0.7, 0)
	root.add_child(light)


static func flag(root: Node3D, color: String) -> void:
	var k := MeshKit.new()
	k.between(Vector3.ZERO, Vector3(0, 3.0, 0), 0.06, 0.05, WOOD_D)
	var cloth: Color = Color(0.1, 0.1, 0.13) if color == "black" else Color(0.18, 0.3, 0.62)
	k.box(_xf(Vector3(0.55, 2.55, 0)), Vector3(1.0, 0.65, 0.03), cloth)
	if color == "black":
		k.ball(_xf(Vector3(0.55, 2.6, 0.03)), 0.1, Color(0.95, 0.93, 0.86), 6, 3)
		k.box(_xf(Vector3(0.55, 2.42, 0.03)), Vector3(0.36, 0.05, 0.02), Color(0.95, 0.93, 0.86))
	else:
		k.box(_xf(Vector3(0.55, 2.55, 0.01)), Vector3(1.0, 0.1, 0.035), Color(0.95, 0.95, 0.9))
	k.instance(root)


## Muret droit (axes seulement) entre deux points relatifs au centre de l'île, avec créneaux.
static func wall(root: Node3D, a: Vector2, b: Vector2) -> void:
	var k := MeshKit.new()
	var d := b - a
	var len := d.length()
	var mid := (a + b) * 0.5
	var along_x := absf(d.x) >= absf(d.y)
	var size := Vector3(len + 0.8, 1.5, 0.8) if along_x else Vector3(0.8, 1.5, len + 0.8)
	k.box(_xf(Vector3(mid.x, 0.75, mid.y)), size, Color(0.46, 0.43, 0.41))
	# joints : deux bandes plus sombres
	for y in [0.45, 1.0]:
		k.box(_xf(Vector3(mid.x, y, mid.y)), size + Vector3(0.03, 0.04, 0.03) * Vector3(1, 0, 1) + Vector3(0, -size.y + 0.05, 0), Color(0.36, 0.34, 0.34))
	k.box(_xf(Vector3(mid.x, 1.56, mid.y)), size + Vector3(0.12, 0.0, 0.12) + Vector3(0, -size.y + 0.12, 0), Color(0.36, 0.34, 0.34))
	var n := int(len / 1.2)
	for i in n + 1:
		var q := a + d * (float(i) / maxf(float(n), 1.0))
		k.box(_xf(Vector3(q.x, 1.85, q.y)), Vector3(0.5, 0.4, 0.5), Color(0.46, 0.43, 0.41))
	k.instance(root)


## Un coffre au trésor. Renvoie {root, lid, pile, glint} ; le couvercle pivote autour de son bord arrière.
static func chest(parent: Node3D, p: Vector2) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(p.x, 0.0, p.y)
	parent.add_child(root)
	var gold := Color(0.95, 0.76, 0.2)
	var wood := Color(0.5, 0.3, 0.16)
	var wood_d := Color(0.34, 0.2, 0.11)
	var base := MeshKit.new()
	base.box(_xf(Vector3(0, 0.21, 0)), Vector3(0.9, 0.42, 0.6), wood)
	for sx in [-0.34, 0.34]:
		base.box(_xf(Vector3(sx, 0.21, 0)), Vector3(0.09, 0.44, 0.64), gold)
	base.box(_xf(Vector3(0, 0.03, 0)), Vector3(0.96, 0.06, 0.66), wood_d)
	base.instance(root)
	var pile := ProcKit.ball(root, 0.3, Vector3(0, 0.36, 0), ProcKit.glow(Color(1.0, 0.82, 0.25)))
	pile.scale = Vector3(1.2, 0.35, 0.8)
	pile.visible = false
	var hinge := Node3D.new()
	hinge.position = Vector3(0, 0.42, -0.3)
	root.add_child(hinge)
	var lid := MeshKit.new()
	lid.box(_xf(Vector3(0, 0.06, 0.3)), Vector3(0.9, 0.12, 0.6), wood_d)
	lid.cyl(_xf(Vector3(0, 0.12, 0.3), Vector3(0, 0, PI / 2.0)), 0.3, 0.3, 0.9, wood, 8)
	for sx in [-0.34, 0.34]:
		lid.cyl(_xf(Vector3(sx, 0.12, 0.3), Vector3(0, 0, PI / 2.0)), 0.315, 0.315, 0.09, gold, 8)
	lid.box(_xf(Vector3(0, 0.03, 0.62)), Vector3(0.12, 0.14, 0.04), gold)
	lid.instance(hinge)
	var glint := ProcKit.ball(root, 0.07, Vector3(0, 1.0, 0), ProcKit.glow(Color(1.0, 0.92, 0.45)))
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"root": root, "lid": hinge, "pile": pile, "glint": glint}


## Une baie des dieux à cueillir. Posée dans un buisson (cachée : `fruit` n'apparaît que quand on s'approche), ou
## par terre (baie lâchée : `in_bush` faux, toujours visible). Renvoie {root, fruit, glint}.
static func berry_spot(parent: Node3D, p: Vector2, color: Color, in_bush: bool, seed_value: int) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(p.x, 0.0, p.y)
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + seed_value
	if in_bush:
		var bush_root := Node3D.new()
		root.add_child(bush_root)
		bush(bush_root, rng)
	var fruit := Node3D.new()
	fruit.position = Vector3(0, 0.95 if in_bush else 0.22, 0)
	root.add_child(fruit)
	ProcKit.ball(fruit, 0.17, Vector3.ZERO, ProcKit.glow(color))
	var leaves := MeshKit.new()
	leaves.box(_xf(Vector3(-0.1, 0.17, 0), Vector3(0, 0, 0.6)), Vector3(0.22, 0.03, 0.12), GREENS[2])
	leaves.box(_xf(Vector3(0.1, 0.17, 0), Vector3(0, 0, -0.6)), Vector3(0.22, 0.03, 0.12), GREENS[0])
	leaves.instance(fruit)
	var glint := ProcKit.ball(fruit, 0.06, Vector3(0, 0.55, 0), ProcKit.glow(Color(1.0, 0.97, 0.8)))
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fruit.visible = not in_bush
	return {"root": root, "fruit": fruit, "glint": glint}


# ------------------------------------------------------------------ monuments et décors à thème

static func pond(root: Node3D, rng: RandomNumberGenerator) -> void:
	var k := MeshKit.new()
	k.cyl(_xf(Vector3(0, 0.02, 0)), 1.9, 1.9, 0.04, Color(0.33, 0.31, 0.33), 14)
	k.cyl(_xf(Vector3(0, 0.035, 0)), 1.6, 1.6, 0.04, Color(0.24, 0.57, 0.62), 14)
	k.cyl(_xf(Vector3(0.2, 0.05, -0.2)), 0.55, 0.55, 0.03, Color(0.36, 0.7, 0.72), 10)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		k.ball(_xf(Vector3(cos(a) * 1.85, 0.12, sin(a) * 1.85)), 0.28, STONE if i % 2 == 0 else STONE_D, 6, 3)
	for i in 4:
		var a := rng.randf() * TAU
		k.cyl(_xf(Vector3(cos(a) * 0.7, 0.06, sin(a) * 0.7)), 0.2, 0.2, 0.02, Color(0.3, 0.6, 0.24), 8)
	k.instance(root)


static func pillar(root: Node3D, rng: RandomNumberGenerator) -> void:
	var k := MeshKit.new()
	var h := rng.randf_range(1.6, 2.6)
	k.cyl(_xf(Vector3(0, h * 0.5, 0)), 0.42, 0.36, h, STONE, 8)
	k.box(_xf(Vector3(0, 0.1, 0)), Vector3(1.0, 0.2, 1.0), STONE_D)
	k.box(_xf(Vector3(0, h + 0.1, 0), Vector3(0, 0.3, 0.1)), Vector3(0.9, 0.2, 0.9), STONE)
	k.ball(_xf(Vector3(0.25, 0.25, 0.3)), 0.28, Color(0.3, 0.58, 0.24), 6, 3)
	k.instance(root)


static func skull_rock(root: Node3D) -> void:
	var k := MeshKit.new()
	var rock_c := Color(0.44, 0.42, 0.42)
	var rock_d := Color(0.32, 0.3, 0.34)
	k.ball(_xf(Vector3(0, 1.7, 0), Vector3.ZERO), 2.0, rock_c, 10, 5)
	k.ball(_xf(Vector3(0, 0.6, 0.2)), 1.7, rock_d, 9, 4)
	# orbites creuses, nez, dents
	for sx in [-1.0, 1.0]:
		k.ball(_xf(Vector3(sx * 0.8, 1.9, 1.5), Vector3.ZERO), 0.55, Color(0.08, 0.06, 0.09), 7, 4)
		k.ball(_xf(Vector3(sx * 0.8, 1.9, 1.62), Vector3.ZERO), 0.18, Color(0.5, 1.0, 0.6), 5, 3)
	k.box(_xf(Vector3(0, 1.3, 1.85), Vector3(0.3, 0, 0)), Vector3(0.28, 0.45, 0.2), Color(0.1, 0.08, 0.1))
	for i in 5:
		k.box(_xf(Vector3(-0.8 + i * 0.4, 0.45, 1.55)), Vector3(0.26, 0.5, 0.25), BONE)
	k.ball(_xf(Vector3(0.4, 3.4, -0.2)), 0.7, Color(0.3, 0.58, 0.24), 7, 3)
	k.instance(root)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.6)
	light.omni_range = 5.0
	light.light_energy = 0.9
	light.position = Vector3(0, 1.9, 2.4)
	root.add_child(light)


static func tower(root: Node3D, color: String) -> void:
	var k := MeshKit.new()
	var st := Color(0.46, 0.43, 0.41)
	var st_d := Color(0.36, 0.34, 0.34)
	k.cyl(_xf(Vector3(0, 2.1, 0)), 1.7, 1.45, 4.2, st, 12)
	for y in [1.0, 2.0, 3.0]:
		k.cyl(_xf(Vector3(0, y, 0)), 1.62, 1.62, 0.07, st_d, 12)
	k.cyl(_xf(Vector3(0, 4.3, 0)), 1.75, 1.75, 0.2, st_d, 12)
	for i in 8:
		var a := TAU * i / 8.0
		k.box(_xf(Vector3(cos(a) * 1.6, 4.65, sin(a) * 1.6), Vector3(0, -a, 0)), Vector3(0.55, 0.5, 0.45), st)
	# porte et meurtrières
	k.box(_xf(Vector3(0, 0.7, 1.6)), Vector3(0.9, 1.4, 0.2), Color(0.32, 0.2, 0.12))
	k.box(_xf(Vector3(0, 0.7, 1.7)), Vector3(0.5, 0.9, 0.1), Color(0.14, 0.1, 0.1))
	for a in [0.0, PI * 0.5, PI]:
		k.box(_xf(Vector3(cos(a + 0.9) * 1.5, 3.1, sin(a + 0.9) * 1.5), Vector3(0, -(a + 0.9), 0)), Vector3(0.1, 0.5, 0.3), Color(0.1, 0.08, 0.1))
	k.instance(root)
	var f := Node3D.new()
	f.position = Vector3(0, 4.5, 0)
	root.add_child(f)
	flag(f, color)


static func cannon(root: Node3D) -> void:
	var k := MeshKit.new()
	k.box(_xf(Vector3(0, 0.32, 0)), Vector3(0.7, 0.2, 1.3), WOOD_D)
	for sx in [-0.36, 0.36]:
		k.cyl(_xf(Vector3(sx, 0.3, 0.1), Vector3(0, 0, PI / 2.0)), 0.3, 0.3, 0.1, WOOD, 8)
	k.cyl(_xf(Vector3(0, 0.62, 0.15), Vector3(PI / 2.0 - 0.15, 0, 0)), 0.2, 0.15, 1.5, Color(0.2, 0.2, 0.24), 8)
	k.ball(_xf(Vector3(0, 0.55, -0.62)), 0.18, Color(0.2, 0.2, 0.24), 6, 3)
	k.instance(root)


static func rowboat(root: Node3D) -> void:
	var k := MeshKit.new()
	var wood := Color(0.52, 0.34, 0.2)
	var inside := Color(0.7, 0.52, 0.32)
	k.box(_xf(Vector3(0, 0.15, 0)), Vector3(0.95, 0.1, 2.3), inside)
	for sx in [-1.0, 1.0]:
		k.box(_xf(Vector3(sx * 0.5, 0.35, 0), Vector3(0, 0, sx * -0.25)), Vector3(0.1, 0.5, 2.2), wood)
	k.box(_xf(Vector3(0, 0.4, 1.2), Vector3(0.5, 0, 0)), Vector3(0.8, 0.5, 0.1), wood)
	k.box(_xf(Vector3(0, 0.4, -1.2), Vector3(-0.5, 0, 0)), Vector3(0.8, 0.5, 0.1), wood)
	k.box(_xf(Vector3(0, 0.45, 0)), Vector3(1.0, 0.07, 0.3), wood)
	k.between(Vector3(0.9, 0.2, -0.8), Vector3(1.6, 0.05, 0.6), 0.04, 0.04, WOOD_D)
	k.instance(root, Vector3.ZERO, 0.0)
	root.rotation.z = deg_to_rad(8.0)


static func hut(root: Node3D) -> void:
	var k := MeshKit.new()
	var wall := Color(0.62, 0.46, 0.3)
	var roof := Color(0.82, 0.7, 0.4)
	k.box(_xf(Vector3(0, 0.9, 0)), Vector3(2.6, 1.8, 2.6), wall)
	for y in [0.4, 0.9, 1.4]:
		k.box(_xf(Vector3(0, y, 0)), Vector3(2.64, 0.05, 2.64), Color(0.45, 0.3, 0.2))
	k.box(_xf(Vector3(-0.75, 2.2, 0), Vector3(0, 0, deg_to_rad(40.0))), Vector3(2.2, 0.14, 3.1), roof)
	k.box(_xf(Vector3(0.75, 2.2, 0), Vector3(0, 0, deg_to_rad(-40.0))), Vector3(2.2, 0.14, 3.1), Color(0.72, 0.6, 0.34))
	k.box(_xf(Vector3(0, 0.7, 1.31)), Vector3(0.8, 1.4, 0.06), Color(0.2, 0.12, 0.08))
	k.box(_xf(Vector3(1.31, 1.1, 0)), Vector3(0.06, 0.6, 0.7), Color(0.12, 0.1, 0.12))
	k.instance(root)


static func sandcastle(root: Node3D) -> void:
	var k := MeshKit.new()
	var sand := Color(0.7, 0.58, 0.4)
	var sand_d := Color(0.58, 0.48, 0.33)
	k.cyl(_xf(Vector3(0, 0.2, 0)), 0.55, 0.5, 0.4, sand, 8)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		k.cyl(_xf(Vector3(cos(a) * 0.5, 0.38, sin(a) * 0.5)), 0.17, 0.14, 0.76, sand_d, 6)
	k.cyl(_xf(Vector3(0, 0.55, 0)), 0.22, 0.12, 0.4, sand, 6)
	k.between(Vector3(0, 0.75, 0), Vector3(0, 1.0, 0), 0.015, 0.015, WOOD_D, 3)
	k.box(_xf(Vector3(0.1, 0.92, 0)), Vector3(0.2, 0.12, 0.02), Color(0.84, 0.33, 0.36))
	k.instance(root)


static func totem(root: Node3D) -> void:
	var k := MeshKit.new()
	var cols := [Color(0.62, 0.46, 0.3), Color(0.84, 0.33, 0.36), Color(0.98, 0.82, 0.33), Color(0.18, 0.3, 0.62)]
	for i in 4:
		k.box(_xf(Vector3(0, 0.45 + i * 0.7, 0)), Vector3(0.62, 0.66, 0.62), cols[i])
		k.box(_xf(Vector3(0, 0.52 + i * 0.7, 0.33)), Vector3(0.4, 0.14, 0.06), Color(0.1, 0.08, 0.1))
		k.box(_xf(Vector3(0, 0.34 + i * 0.7, 0.33)), Vector3(0.3, 0.1, 0.06), Color(0.95, 0.93, 0.86))
	k.box(_xf(Vector3(0, 3.2, 0), Vector3(0, 0, 0)), Vector3(1.3, 0.12, 0.3), cols[2])
	k.instance(root)


static func arch(root: Node3D, seed_value: int) -> void:
	# deux gros rochers reliés par un linteau : un portique naturel
	var k := MeshKit.new()
	var c := Color(0.44, 0.41, 0.4)
	var cd := Color(0.33, 0.31, 0.33)
	k.ball(_xf(Vector3(-2.0, 1.7, 0)), 1.3, c, 8, 4)
	k.ball(_xf(Vector3(-2.0, 0.7, 0), Vector3.ZERO), 1.5, cd, 8, 3)
	k.ball(_xf(Vector3(2.0, 1.4, 0)), 1.2, cd, 8, 4)
	k.ball(_xf(Vector3(2.0, 0.6, 0)), 1.4, c, 8, 3)
	k.box(_xf(Vector3(0, 3.1, 0), Vector3(0, 0, 0.1)), Vector3(4.4, 0.9, 1.4), c)
	k.ball(_xf(Vector3(0.4, 3.7, 0)), 0.8, Color(0.3, 0.58, 0.24), 7, 3)
	k.instance(root)


## L'épave d'un vrai bateau du jeu (modèle 3D), échoué, penché, à moitié enfoncé dans le sable.
static func wreck(root: Node3D, ship: String) -> void:
	var scene := load(SHIP_PATH % ship) as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * 1.5
	model.position = Vector3(0, -0.7, 0)
	model.rotation = Vector3(deg_to_rad(18.0), deg_to_rad(90.0), deg_to_rad(6.0))
	root.add_child(model)
