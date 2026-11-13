class_name HoldRoom
extends Node3D
## La cale en 3D : une coupe du bateau montrée d'en haut, comme le pont. Fond plat, bordés qui montent des deux
## côtés, mur du fond, côtes de la coque, tonneaux, étagère à planches, seau, échelle vers le pont, et sur les
## bordés les voies d'eau (trou noir, éclats de bois, jet d'eau) ou, une fois bouchées, une planche clouée.
## L'eau monte sur le fond selon l'état de la coque. Le plan (distances, obstacles) est dans HoldLayout.

# palette v1 (12/11/2026, design/bible-v2.md) : les quatre bois, l'ombre commune
const WOOD_FLOOR := Color("9C6A43")
const WOOD_SLOPE := Color("6A4532")
const WOOD_RIB := Color("3A2630")
const WOOD_WALL := Color("5A3A2C")
const WOOD_LIGHT := Color("CF9C62")
const IRON := Color("2E2A44")
const CLOTH := Color("D9CBB0")
const CEIL_Y := 3.3          ## hauteur du pont au-dessus de la cale (plafond invisible qui porte l'ombre)

var layout: HoldLayout
var _slope_angle := atan2(HoldLayout.RISE, HoldLayout.RUN)
var _water: MeshInstance3D
var _water_level := 0.0
var _t := 0.0
var _slots: Array = []        ## par voie d'eau : {open, patch, jet}
var _lamps: Array = []        ## les lumières des lanternes (elles vacillent)


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
	_tools_cabinet()
	_bucket()
	# (12/11, refonte v2) le pont au-dessus : invisible, il porte l'ombre ; le soleil n'entre que par l'écoutille (aim_sun)
	_deck_shadow()
	_hammocks()
	_room_walls()
	_portholes()
	# lanternes (lot 3 : une tous les ~3 m, flammes qui vacillent) ; réserves aux deux bouts, cloisons, poutres
	var n_lamps := maxi(3, int(hold_len / GameConfig.HOLD_LANTERN_EVERY))
	for i in n_lamps:
		_lantern(lerpf(-layout.half_len + 1.2, layout.half_len - 1.2, (float(i) + 0.5) / float(n_lamps)))
	_bulkheads()
	_storage(-1)
	_storage(1)
	_beams()
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
	# les flammes vacillent (deux sinusoïdes désaccordées par lanterne : jamais en même temps)
	for i in _lamps.size():
		var l := _lamps[i] as OmniLight3D
		var f := 1.0 + GameConfig.HOLD_FLICKER * (0.6 * sin(_t * 9.0 + i * 1.7) + 0.4 * sin(_t * 23.0 + i * 0.9))
		l.light_energy = 1.7 * f


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


## Le soleil par l'écoutille (12/11, refonte v2). La cale était éclairée à plat, comme en plein air ; maintenant un plafond
## invisible (le pont) lui fait de l'ombre, percé d'un trou, l'écoutille, placé pour que la tache de soleil tombe au pied de
## l'échelle quelle que soit l'heure. Dans le rai : un voile de lumière et des poussières qui flottent. `light_dir` : direction
## dans laquelle va la lumière (repère du monde).
func aim_sun(light_dir: Vector3) -> void:
	if _ceil == null:
		return
	var d := (global_transform.basis.inverse() * light_dir).normalized()
	if d.y > -0.15:
		d = Vector3(d.x, -0.15, d.z).normalized()   # soleil couchant : on garde un rai visible
	var target := Vector3(layout.hatch_x, 0.0, -0.4)
	var t := CEIL_Y / -d.y
	var hole := target - d * t
	_ceil.position = Vector3(hole.x, 0.0, hole.z)
	# le voile de lumière : une boîte fine et allongée du trou à la tache, additive et très transparente
	var mid := (hole + target) * 0.5
	_shaft.position = mid
	_shaft.basis = Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT)
	_shaft.scale = Vector3(1.0, 1.0, t)
	_dust.position = mid
	_dust.basis = _shaft.basis


var _ceil: Node3D
var _hammock_xs: Array[float] = []   ## où sont les hamacs (les hublots les évitent)
var _shaft: MeshInstance3D
var _dust: CPUParticles3D


func _deck_shadow() -> void:
	_ceil = Node3D.new()
	add_child(_ceil)
	var big := 60.0
	var h := 0.65   # demi-côté du trou de l'écoutille
	for r: Array in [[0.0, -(big + h) * 0.5 - h * 0.5, big * 2.0, big], [0.0, (big + h) * 0.5 + h * 0.5, big * 2.0, big],
			[-(big + h) * 0.5 - h * 0.5, 0.0, big, h * 2.0], [(big + h) * 0.5 + h * 0.5, 0.0, big, h * 2.0]]:
		var b := _box(Vector3(float(r[2]), 0.2, float(r[3])), Vector3(float(r[0]), CEIL_Y, float(r[1])), null, Vector3.ZERO, _ceil)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# le rai de lumière
	_shaft = MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.15, 1.15, 1.0)
	_shaft.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.86, 0.58, 0.07)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_shaft.material_override = m
	_shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shaft)
	# les poussières dans le rai
	_dust = CPUParticles3D.new()
	_dust.amount = 40
	_dust.lifetime = 6.0
	_dust.preprocess = 6.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.5, 0.5, 1.6)
	_dust.direction = Vector3(0, 1, 0)
	_dust.spread = 180.0
	_dust.gravity = Vector3(0, -0.02, 0)
	_dust.initial_velocity_min = 0.02
	_dust.initial_velocity_max = 0.08
	_dust.local_coords = true
	var dm := QuadMesh.new()
	dm.size = Vector2(0.035, 0.035)
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(1.0, 0.92, 0.7, 0.75)
	dm.material = dmat
	_dust.mesh = dm
	add_child(_dust)


## 13/11 : la cale en trois pièces. Chaque cloison intérieure : deux pans de bordé de part et d'autre de la porte, un linteau,
## deux montants ; une lanterne au-dessus de la porte.
func _room_walls() -> void:
	var top := HoldLayout.RISE + HoldLayout.WALL_H
	var half_w := HoldLayout.FLOOR_HALF + HoldLayout.RUN
	var door := GameConfig.HOLD_DOOR_HALF
	for wx: float in layout.walls:
		for side in [-1.0, 1.0]:
			var z0: float = side * door
			var z1: float = side * half_w
			_box(Vector3(0.12, top, absf(z1 - z0)), Vector3(wx, top * 0.5, (z0 + z1) * 0.5), _wood(WOOD_WALL, Vector2(0.8, 0.7)))
			_box(Vector3(0.2, top, 0.16), Vector3(wx, top * 0.5, side * (door + 0.02)), _flat(WOOD_RIB))
		_box(Vector3(0.2, 0.24, door * 2.0 + 0.3), Vector3(wx, top - 0.12, 0.0), _flat(WOOD_RIB))
		_box(Vector3(0.16, top - 2.05, door * 2.0), Vector3(wx, 2.05 + (top - 2.05) * 0.5 - 0.12, 0.0), _wood(WOOD_WALL, Vector2(0.5, 0.3)))


## 13/11 : des hublots dans le mur du fond, pour ne plus se sentir enfermé : un cercle de laiton, la mer et le ciel derrière,
## avec la ligne d'eau qui monte et descend. Ils évitent l'échelle, l'étagère et les hamacs.
const _PORTHOLE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 sky : source_color = vec3(0.62, 0.80, 0.92);
uniform vec3 sea_top : source_color = vec3(0.31, 0.72, 0.66);
uniform vec3 sea_deep : source_color = vec3(0.08, 0.19, 0.29);
uniform float phase = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (dot(p, p) > 1.0) { discard; }
	float line = 0.12 * sin(TIME * 0.9 + phase) + 0.05 * sin(p.x * 6.0 + TIME * 2.3 + phase);
	float under = smoothstep(line - 0.02, line + 0.02, p.y);
	vec3 water = mix(sea_top, sea_deep, clamp((p.y - line) * 1.4, 0.0, 1.0));
	water += 0.10 * smoothstep(0.05, 0.0, abs(p.y - line));
	ALBEDO = mix(sky, water, under);
}
"""
static var _porthole_shader: Shader


func _portholes() -> void:
	if _porthole_shader == null:
		_porthole_shader = Shader.new()
		_porthole_shader.code = _PORTHOLE_SHADER
	var wall_z := -(HoldLayout.FLOOR_HALF + HoldLayout.RUN) + 0.02
	var y := HoldLayout.RISE + 1.0
	var avoid: Array[float] = [layout.hatch_x, layout.rack_pos().x]
	avoid.append_array(_hammock_xs)
	avoid.append(layout.tools_pos().x)   # (l'armoire aux instruments)
	var x := -layout.half_len + 1.6
	var k := 0
	while x < layout.half_len - 1.4:
		var ok := true
		for a: float in avoid:
			if absf(x - a) < 1.35:
				ok = false
		for wx: float in layout.walls:
			if absf(x - wx) < 0.6:
				ok = false
		if ok:
			var glass := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.62, 0.62)
			glass.mesh = qm
			var m := ShaderMaterial.new()
			m.shader = _porthole_shader
			m.set_shader_parameter("phase", float(k) * 1.7)
			glass.material_override = m
			glass.position = Vector3(x, y, wall_z)
			glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(glass)
			var ring := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.29
			tor.outer_radius = 0.37
			tor.rings = 20
			tor.ring_segments = 6
			ring.mesh = tor
			ring.material_override = _flat(Color("DCAE5C"))
			ring.position = Vector3(x, y, wall_z + 0.03)
			ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			add_child(ring)
			for bolt in 4:
				var ang := TAU * (float(bolt) + 0.5) / 4.0
				_box(Vector3(0.05, 0.05, 0.05), Vector3(x + cos(ang) * 0.33, y + sin(ang) * 0.33, wall_z + 0.06), _flat(IRON))
			# la lumière du jour qui entre par le hublot
			var light := OmniLight3D.new()
			light.light_color = Color(0.72, 0.86, 1.0)
			light.light_energy = 0.55
			light.omni_range = 2.6
			light.shadow_enabled = false
			light.position = Vector3(x, y, wall_z + 0.5)
			add_child(light)
			k += 1
		x += GameConfig.HOLD_PORTHOLE_EVERY


## Deux hamacs tendus devant le mur du fond, entre les côtes, loin de l'échelle et de l'étagère.
func _hammocks() -> void:
	var wall_z := -(HoldLayout.FLOOR_HALF + HoldLayout.RUN) + 0.05
	var rack_x := layout.rack_pos().x
	var placed := 0
	for x: float in [layout.half_len * 0.45, -layout.half_len * 0.12, layout.half_len * 0.1, -layout.half_len * 0.4]:
		if placed >= 2 or absf(x - layout.hatch_x) < 1.8 or absf(x - rack_x) < 1.9:
			continue
		placed += 1
		_hammock_xs.append(x)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 10
		var y0 := HoldLayout.RISE + 1.35
		for i in n:
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var pts: Array[Vector3] = []
			for u: float in [u0, u1]:
				var px := x - 0.95 + 1.9 * u
				var py := y0 - 0.38 * sin(PI * u)
				pts.append(Vector3(px, py, wall_z + 0.18))
				pts.append(Vector3(px, py - 0.06 * sin(PI * u), wall_z + 0.18 + 0.55 * (0.6 + 0.4 * sin(PI * u))))
			st.add_vertex(pts[0]); st.add_vertex(pts[2]); st.add_vertex(pts[1])
			st.add_vertex(pts[1]); st.add_vertex(pts[2]); st.add_vertex(pts[3])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var cm := _flat(CLOTH.darkened(0.08 * placed))
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = cm
		add_child(mi)
		for sx in [-1.0, 1.0]:   # cordes jusqu'aux côtes
			_box(Vector3(0.32, 0.03, 0.03), Vector3(x + sx * 1.1, y0 + 0.05, wall_z + 0.3), _flat(Color("A87A52")), Vector3(0, 0, sx * 0.4))
		# une couverture roulée dans le premier, un sac dans le second
		var bun := _sphere(0.16, Vector3(x + 0.2, y0 - 0.26, wall_z + 0.45), _flat(Color("B25A3E") if placed == 1 else Color("A87A52")))
		bun.scale = Vector3(1.8, 0.8, 1.0)


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


## 13/11 (Jimmy) : l'armoire aux instruments. Une petite armoire de bois sombre contre le mur du fond, porte ouverte, avec
## dessus une grande boussole de laiton (le cadran, la rose et l'aiguille rouge) : on comprend ce qu'on y prend.
func _tools_cabinet() -> void:
	var p := layout.tools_pos()
	var wall_z := -(HoldLayout.FLOOR_HALF + HoldLayout.RUN) + 0.22
	var y := HoldLayout.RISE + 0.3
	var brass := _flat(Color("d9a441"))
	_box(Vector3(1.1, 1.5, 0.4), Vector3(p.x, y + 0.75, wall_z), _flat(WOOD_RIB))
	_box(Vector3(0.96, 1.36, 0.06), Vector3(p.x, y + 0.75, wall_z + 0.2), _flat(WOOD_WALL))
	for k in 2:
		_box(Vector3(0.96, 0.05, 0.3), Vector3(p.x, y + 0.45 + k * 0.5, wall_z + 0.05), _flat(WOOD_LIGHT))
	_box(Vector3(0.06, 1.36, 0.5), Vector3(p.x + 0.56, y + 0.75, wall_z + 0.42), _flat(WOOD_RIB))   # la porte, ouverte
	# la boussole en enseigne, au-dessus
	var dial := _cylinder(0.42, 0.08, Vector3(p.x, y + 1.95, wall_z + 0.18), brass)
	dial.rotation.x = PI * 0.5
	var face := _cylinder(0.34, 0.09, Vector3(p.x, y + 1.95, wall_z + 0.19), _flat(Color("efe4cc")))
	face.rotation.x = PI * 0.5
	_box(Vector3(0.07, 0.5, 0.04), Vector3(p.x, y + 1.95, wall_z + 0.25), _flat(Color("b23a30")), Vector3(0, 0, 0.6))
	_box(Vector3(0.05, 0.3, 0.04), Vector3(p.x, y + 1.95, wall_z + 0.25), _flat(IRON), Vector3(0, 0, 0.6 + PI * 0.5))
	# la longue-vue posée sur la tablette
	var tube := _cylinder(0.07, 0.6, Vector3(p.x - 0.1, y + 1.03, wall_z + 0.1), brass)
	tube.rotation.z = PI * 0.5


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
	_lamps.append(light)
	# la lanterne elle-même : cage de fer, chapeau, crochet au mur
	_box(Vector3(0.2, 0.26, 0.2), Vector3(x, 2.4, -1.0), _flat(IRON.lightened(0.1)))
	_box(Vector3(0.26, 0.05, 0.26), Vector3(x, 2.56, -1.0), _flat(IRON))
	_box(Vector3(0.04, 0.04, 0.6), Vector3(x, 2.6, -1.3), _flat(IRON))


## Lot 3 (3.3) : les cloisons de bois aux deux bouts de la cale.
func _bulkheads() -> void:
	var h := HoldLayout.RISE + HoldLayout.WALL_H
	var depth := (HoldLayout.FLOOR_HALF + HoldLayout.RUN) * 2.0
	for side in [-1, 1]:
		_box(Vector3(0.14, h, depth), Vector3(side * (layout.half_len + 0.07), h * 0.5, 0.0), _wood(WOOD_WALL, Vector2(1.0, 0.8)))
		_box(Vector3(0.2, h, 0.2), Vector3(side * (layout.half_len - 0.05), h * 0.5, -(HoldLayout.FLOOR_HALF + HoldLayout.RUN) + 0.1), _flat(WOOD_RIB))


## Lot 3 (3.3) : la réserve d'un bout de la cale (côté `side` : -1 arrière, 1 avant), là où l'on ne marche pas : tonneaux couchés
## et debout, caisses empilées, sacs. Un peu de hasard fixe (même cale pour tous les joueurs).
func _storage(side: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040 + side
	var x0 := side * (layout.half_len - HoldLayout.MARGIN * 0.5)
	# rangée de tonneaux debout le long de la cloison
	var z := -HoldLayout.FLOOR_HALF + 0.45
	while z < HoldLayout.FLOOR_HALF - 0.3:
		var bx := x0 + side * rng.randf_range(0.0, 0.25)
		_barrel(Vector3(bx, 0.42, z), rng.randf_range(0.34, 0.4))
		if rng.randf() < 0.45:   # un deuxième par-dessus, parfois
			_barrel(Vector3(bx, 1.27, z), 0.33)
		z += rng.randf_range(0.82, 0.95)
	# caisses empilées sur la pente du fond et sur celle de devant
	for zs in [-(HoldLayout.FLOOR_HALF + 0.55), HoldLayout.FLOOR_HALF + 0.5]:
		var base_y := HoldLayout.height_at(zs)
		for k in 3:
			var s := rng.randf_range(0.5, 0.7)
			var y := base_y + s * 0.5 + (s * float(k) if k < 2 else 0.0)
			var cx := x0 - side * (0.1 if k < 2 else 0.75)
			_box(Vector3(s, s, s), Vector3(cx, y, zs), _flat(WOOD_LIGHT.darkened(rng.randf_range(0.1, 0.3))), Vector3(0, rng.randf_range(-0.3, 0.3), 0))
			_box(Vector3(s + 0.03, 0.05, s + 0.03), Vector3(cx, y + s * 0.5, zs), _flat(WOOD_RIB))
	# sacs de grain près des tonneaux
	for k in 3:
		var sack := _sphere(0.26, Vector3(x0 - side * 0.55, 0.2, -0.6 + k * 0.45), _flat(Color(0.66, 0.56, 0.4).darkened(0.08 * k)))
		sack.scale = Vector3(1.0, 0.75, 0.85)


func _barrel(pos: Vector3, r: float) -> void:
	_cylinder(r, 0.85, pos, _flat(Color(0.5, 0.33, 0.18)))
	_cylinder(r + 0.02, 0.06, pos + Vector3(0, -0.22, 0), _flat(IRON))
	_cylinder(r + 0.02, 0.06, pos + Vector3(0, 0.22, 0), _flat(IRON))


## Lot 3 (3.3) : les barrots du pont, au-dessus du mur du fond (on ne les met pas au-dessus du passage : ils cacheraient le pirate).
func _beams() -> void:
	var wall_z := -(HoldLayout.FLOOR_HALF + HoldLayout.RUN)
	var y := HoldLayout.RISE + HoldLayout.WALL_H + 0.12
	_box(Vector3(layout.half_len * 2.0, 0.18, 0.3), Vector3(0, y, wall_z + 0.2), _flat(WOOD_RIB))
	var n := maxi(3, int(layout.half_len * 2.0 / 2.2))
	for i in n + 1:
		var x := -layout.half_len + 0.1 + (layout.half_len * 2.0 - 0.2) * float(i) / float(n)
		_box(Vector3(0.18, 0.18, 0.9), Vector3(x, y + 0.02, wall_z + 0.5), _flat(WOOD_RIB))


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
