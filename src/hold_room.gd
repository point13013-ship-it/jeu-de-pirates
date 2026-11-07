class_name HoldRoom
extends Node3D
## La cale en 3D : une coupe du bateau montrée d'en haut, comme le pont. Fond plat, bordés qui montent des deux
## côtés, mur du fond, côtes de la coque, tonneaux, étagère à planches, seau, échelle vers le pont, et sur les
## bordés les voies d'eau (trou noir, éclats de bois, jet d'eau) ou, une fois bouchées, une planche clouée.
## L'eau monte sur le fond selon l'état de la coque. Le plan (distances, obstacles) est dans HoldLayout.

const WOOD_FLOOR := Color(0.56, 0.39, 0.23)
const WOOD_SLOPE := Color(0.44, 0.30, 0.18)
const WOOD_RIB := Color(0.30, 0.20, 0.12)
const WOOD_WALL := Color(0.38, 0.26, 0.15)
const WOOD_LIGHT := Color(0.80, 0.62, 0.38)
const IRON := Color(0.22, 0.22, 0.27)

var layout: HoldLayout
var _slope_angle := atan2(HoldLayout.RISE, HoldLayout.RUN)
var _water: MeshInstance3D
var _water_level := 0.0
var _t := 0.0
var _slots: Array = []        ## par voie d'eau : {open, patch, jet}


func build(p_layout: HoldLayout) -> void:
	layout = p_layout
	var hold_len := layout.half_len * 2.0
	var slope_len := sqrt(HoldLayout.RUN * HoldLayout.RUN + HoldLayout.RISE * HoldLayout.RISE)
	var floor_w := HoldLayout.FLOOR_HALF * 2.0
	# fond et bordés
	_box(Vector3(hold_len, 0.1, floor_w), Vector3(0, -0.05, 0), _wood(WOOD_FLOOR, Vector2(hold_len * 0.5, 1.0)))
	for side in [-1, 1]:
		var z: float = side * (HoldLayout.FLOOR_HALF + HoldLayout.RUN * 0.5)
		_box(Vector3(hold_len, 0.12, slope_len), Vector3(0, HoldLayout.RISE * 0.5 - 0.06, z),
				_wood(WOOD_SLOPE, Vector2(hold_len * 0.5, 1.0)), Vector3(-side * _slope_angle, 0, 0))
	# mur du fond, au-dessus de la pente de bâbord
	var wall_z := -(HoldLayout.FLOOR_HALF + HoldLayout.RUN) - 0.06
	_box(Vector3(hold_len, HoldLayout.WALL_H, 0.12), Vector3(0, HoldLayout.RISE + HoldLayout.WALL_H * 0.5, wall_z),
			_wood(WOOD_WALL, Vector2(hold_len * 0.5, 0.7)))
	# lisse en haut du mur et rebord de tribord
	_box(Vector3(hold_len, 0.12, 0.2), Vector3(0, HoldLayout.RISE + HoldLayout.WALL_H + 0.04, wall_z), _flat(WOOD_RIB))
	_box(Vector3(hold_len, 0.14, 0.2), Vector3(0, HoldLayout.RISE + 0.02, HoldLayout.FLOOR_HALF + HoldLayout.RUN + 0.04), _flat(WOOD_RIB))
	# côtes de la coque : une tous les ~2,2 m, plus les deux extrémités
	var ribs := maxi(3, int(hold_len / 2.2))
	for i in ribs + 1:
		_rib(-layout.half_len + 0.05 + (hold_len - 0.1) * float(i) / float(ribs), slope_len)
	# décor
	_decor()
	_ladder()
	_rack()
	_bucket()
	# tache de lumière sous l'écoutille
	var beam := _box(Vector3(1.3, 0.02, 1.3), Vector3(layout.hatch_x, 0.03, 0.0), null)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(1.0, 0.95, 0.75, 0.28)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# lanternes
	for lx in [-layout.half_len * 0.55, layout.half_len * 0.1, layout.half_len * 0.75]:
		_lantern(lx)
	# voies d'eau
	for s in layout.hull.slot_count():
		_slots.append(_make_hole(s))
	# l'eau
	_water = MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(1.0, 0.04, 1.0)
	_water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.16, 0.42, 0.58, 0.62)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.roughness = 0.25
	_water.material_override = wmat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.visible = false
	add_child(_water)


func _process(delta: float) -> void:
	_t += delta
	_refresh_water()


## Point de la scène pour la position (x, z) de la cale, à la hauteur h au-dessus du sol.
func point(p: Vector2, h: float) -> Vector3:
	return to_global(Vector3(p.x, HoldLayout.height_at(p.y) + h, p.y))


## Montre les voies d'eau ouvertes (trou et jet) et celles bouchées (planche clouée).
func set_leaks(leaks: int, patched: int) -> void:
	for s in _slots.size():
		var open := ((leaks >> s) & 1) == 1
		var plank := ((patched >> s) & 1) == 1 and not open
		var e: Dictionary = _slots[s]
		(e["open"] as Node3D).visible = open
		(e["patch"] as Node3D).visible = plank
		(e["jet"] as CPUParticles3D).emitting = open


## Règle le niveau de l'eau (0..1 de la cale).
func set_water(fill: float) -> void:
	_water_level = clampf(fill, 0.0, 1.0) * HoldLayout.RISE * 1.02
	_refresh_water()


func _refresh_water() -> void:
	if _water == null:
		return
	if _water_level < 0.01:
		_water.visible = false
		return
	var lvl := _water_level + sin(_t * 1.6) * 0.012
	var half_w := HoldLayout.FLOOR_HALF + minf(lvl / HoldLayout.RISE, 1.0) * HoldLayout.RUN
	_water.visible = true
	_water.scale = Vector3(layout.half_len * 2.0 - 0.1, 1.0, half_w * 2.0)
	_water.position = Vector3(0.0, lvl, 0.0)


# ------------------------------------------------------------------ construction


func _rib(x: float, slope_len: float) -> void:
	for side in [-1, 1]:
		var z: float = side * (HoldLayout.FLOOR_HALF + HoldLayout.RUN * 0.5)
		_box(Vector3(0.16, 0.08, slope_len), Vector3(x, HoldLayout.RISE * 0.5 + 0.02, z),
				_flat(WOOD_RIB), Vector3(-side * _slope_angle, 0, 0))
	_box(Vector3(0.16, 0.08, HoldLayout.FLOOR_HALF * 2.0), Vector3(x, 0.02, 0), _flat(WOOD_RIB))
	var wall_z := -(HoldLayout.FLOOR_HALF + HoldLayout.RUN)
	_box(Vector3(0.16, HoldLayout.WALL_H, 0.1), Vector3(x, HoldLayout.RISE + HoldLayout.WALL_H * 0.5, wall_z + 0.06), _flat(WOOD_RIB))


func _decor() -> void:
	# tonneaux et caisse (les cercles d'obstacle du plan)
	for c: Array in layout.circles:
		var cx := float(c[0])
		var cz := float(c[1])
		var r := float(c[2])
		if r < 0.41:
			_box(Vector3(0.8, 0.7, 0.8), Vector3(cx, 0.35, cz), _flat(WOOD_LIGHT.darkened(0.2)))
			_box(Vector3(0.84, 0.08, 0.84), Vector3(cx, 0.7, cz), _flat(WOOD_RIB))
		else:
			_cylinder(r, 0.85, Vector3(cx, 0.42, cz), _flat(Color(0.5, 0.33, 0.18)))
			_cylinder(r + 0.02, 0.07, Vector3(cx, 0.2, cz), _flat(IRON))
			_cylinder(r + 0.02, 0.07, Vector3(cx, 0.66, cz), _flat(IRON))
	# boulets empilés contre le mur du fond, à l'avant
	var bx := layout.half_len - 1.8
	var bz := -(HoldLayout.FLOOR_HALF + 0.25)
	for k in 6:
		var row := 0 if k < 3 else 1
		var col := k if k < 3 else k - 3
		_sphere(0.12, Vector3(bx + (float(col) - 1.0 + 0.5 * row) * 0.26, 0.12 + row * 0.2, bz), _flat(IRON))
	# rouleau de corde au pied de la pente de tribord
	var rope := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.12
	tor.outer_radius = 0.34
	rope.mesh = tor
	rope.material_override = _flat(Color(0.62, 0.5, 0.3))
	rope.position = Vector3(-layout.half_len * 0.2, 0.12, HoldLayout.FLOOR_HALF - 0.45)
	add_child(rope)


func _ladder() -> void:
	var x := layout.hatch_x
	var wall_z := -(HoldLayout.FLOOR_HALF + HoldLayout.RUN) + 0.06
	var y0 := HoldLayout.RISE
	var y1 := HoldLayout.RISE + HoldLayout.WALL_H + 1.1
	for dx in [-0.24, 0.24]:
		_box(Vector3(0.06, y1 - y0, 0.06), Vector3(x + dx, (y0 + y1) * 0.5, wall_z), _flat(WOOD_LIGHT))
	var rung_y := y0 + 0.2
	while rung_y < y1:
		_box(Vector3(0.52, 0.05, 0.05), Vector3(x, rung_y, wall_z), _flat(WOOD_LIGHT))
		rung_y += 0.3
	# trappe ouverte au-dessus : le rebord de l'écoutille qui dépasse
	_box(Vector3(0.7, 0.05, 0.1), Vector3(x, y1 + 0.02, wall_z), _flat(WOOD_RIB))


func _rack() -> void:
	var p := layout.rack_pos()
	var wall_z := -(HoldLayout.FLOOR_HALF + HoldLayout.RUN) + 0.1
	var y := HoldLayout.RISE + 0.35
	# montants et tablettes
	for dx in [-0.75, 0.75]:
		_box(Vector3(0.08, 1.0, 0.1), Vector3(p.x + dx, y + 0.35, wall_z), _flat(WOOD_RIB))
	for k in 2:
		_box(Vector3(1.6, 0.06, 0.28), Vector3(p.x, y + 0.1 + k * 0.5, wall_z + 0.1), _flat(WOOD_RIB))
	# planches de réparation
	for k in 6:
		var row := floori(k / 3.0)
		var col := k % 3
		_box(Vector3(1.35, 0.07, 0.2), Vector3(p.x, y + 0.17 + row * 0.5 + col * 0.08, wall_z + 0.1 + (col - 1) * 0.0),
				_flat(WOOD_LIGHT.lightened(0.08 * col)), Vector3(0, 0, 0))


func _bucket() -> void:
	var p := layout.bucket_pos()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.26
	cm.bottom_radius = 0.2
	cm.height = 0.36
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _flat(Color(0.52, 0.34, 0.2))
	mi.position = Vector3(p.x, 0.18, p.y)
	add_child(mi)
	_cylinder(0.27, 0.05, Vector3(p.x, 0.37, p.y), _flat(IRON))
	# anse
	var handle := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.24
	tor.outer_radius = 0.27
	handle.mesh = tor
	handle.material_override = _flat(IRON)
	handle.position = Vector3(p.x, 0.5, p.y)
	handle.rotation_degrees = Vector3(90, 0, 0)
	handle.scale = Vector3(1, 1, 1)
	add_child(handle)


func _lantern(x: float) -> void:
	var glow := _sphere(0.1, Vector3(x, 2.4, -1.0), null)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.85, 0.5)
	glow.material_override = gm
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 1.7
	light.omni_range = 6.5
	light.shadow_enabled = false
	light.position = Vector3(x, 2.3, -0.6)
	add_child(light)


## Un trou de coque sur la pente, avec tout ce qu'il faut pour le montrer ouvert, avec son jet, ou bouché.
func _make_hole(slot: int) -> Dictionary:
	var pos2 := layout.hole_pos(slot)
	var side := layout.hull.slot_side(slot)
	var root := Node3D.new()
	root.position = Vector3(pos2.x, HoldLayout.RISE * HoldLayout.HOLE_T, pos2.y)
	root.rotation = Vector3(side * _slope_angle, 0, 0)   # y local = normale de la pente
	add_child(root)
	# trou ouvert : disque noir, éclats de bois autour
	var open := Node3D.new()
	root.add_child(open)
	var hole := _cylinder(0.27, 0.03, Vector3(0, 0.02, 0), _flat(Color(0.02, 0.01, 0.01)), open)
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 8:
		var a := TAU * float(k) / 8.0 + float(slot) * 0.6
		var sp := _box(Vector3(0.07, 0.06, 0.2 + 0.05 * float((k + slot) % 3)),
				Vector3(cos(a) * 0.3, 0.05, sin(a) * 0.3), _flat(WOOD_LIGHT), Vector3(0.5 + 0.1 * float(k % 2), -a, 0), open)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# planche clouée
	var patch := Node3D.new()
	root.add_child(patch)
	for k in 2:
		_box(Vector3(0.95, 0.07, 0.22), Vector3(0, 0.07 + 0.02 * k, 0), _flat(WOOD_LIGHT.lightened(0.05 * k)),
				Vector3(0, 0.6 if k == 0 else -0.6, 0), patch)
	for k in 4:
		var a2 := TAU * (float(k) + 0.5) / 4.0
		_box(Vector3(0.05, 0.05, 0.05), Vector3(cos(a2) * 0.3, 0.13, sin(a2) * 0.3), _flat(IRON), Vector3.ZERO, patch)
	# jet d'eau
	var jet := CPUParticles3D.new()
	jet.amount = 16
	jet.lifetime = 0.75
	jet.direction = Vector3(0, 1, 0)
	jet.spread = 22.0
	jet.initial_velocity_min = 1.6
	jet.initial_velocity_max = 2.4
	jet.gravity = Vector3(0, -8.5, 0)
	var dm := SphereMesh.new()
	dm.radius = 0.05
	dm.height = 0.1
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color(0.7, 0.88, 1.0)
	dm.material = dmat
	jet.mesh = dm
	jet.emitting = false
	jet.position = Vector3(0, 0.08, 0)
	root.add_child(jet)
	open.visible = false
	patch.visible = false
	return {"open": open, "patch": patch, "jet": jet}


# ------------------------------------------------------------------ petits outils


func _box(size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if mat != null:
		mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent != null else self).add_child(mi)
	return mi


func _cylinder(radius: float, height: float, pos: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	if mat != null:
		mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _sphere(radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	if mat != null:
		mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


## Bois à planches : des rangées plus ou moins claires séparées d'un joint sombre.
func _wood(color: Color, tile: Vector2) -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		var row := floori(y / 4.0)
		var tint := 1.0 + (float((row * 7) % 5) - 2.0) * 0.045
		for x in 16:
			var c := color * tint
			c.a = 1.0
			if y % 4 == 0:
				c = color * 0.62
				c.a = 1.0
			elif (x + row * 5) % 16 == 0:
				c = color * 0.8
				c.a = 1.0
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(tile.x, tile.y, 1.0)
	m.roughness = 0.9
	return m
