class_name IslandLife
extends Node3D
## La vie des îles : mouettes (corbeaux sur les îles de morts), petits crabes inoffensifs, fumée des feux de camp, brume des îles
## de morts, lucioles la nuit, traces de pas dans le sable, éclaboussures, plantes qui s'écartent au passage, feuilles qui
## tombent quand on frappe un palmier, et les trouvailles (bouteilles, journaux) avec leur éclat doré.
## Tout est visuel et local (rien n'est envoyé sur le réseau). Le jeu appelle `update` à chaque image.

const NEAR := 95.0              ## m : on ne fait vivre que ce qui est près du joueur
const GULLS := 6
const CRAB_RANGE := 46.0
const PRINTS := 56
const PRINT_LIFE := 14.0        ## s : une trace s'efface en 14 s
const LEAVES := 64
const PUSH_RANGE := 1.7         ## m : une plante commence à s'écarter à cette distance
const LORE_REACH := 1.5         ## m : portée pour ramasser une trouvaille

var islands: IslandWorld
var night := false
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _scan_t := 0.0
var _near_ids: Array = []                  ## îles à moins de NEAR m du joueur, les plus proches d'abord
var _per_island: Dictionary = {}           ## indice -> {smoke: [CPUParticles3D], fog: CPUParticles3D, crabs: Array}
var _gulls: Array = []                     ## {node, wing_l, wing_r, island, angle, radius, height, speed, phase, crow}
var _prints: Array = []                    ## {node, age}
var _print_i := 0
var _print_acc := 0.0
var _print_side := 1.0
var _leaves: Array = []                    ## {node, vel, spin, life}
var _rings: Array = []                     ## éclaboussures : {node, t}
var _fireflies: CPUParticles3D
var _pushed: Dictionary = {}               ## plante (item) -> inclinaison actuelle (0…1)
var _kicks: Dictionary = {}                ## plante -> secousse restante après un coup
var _soft: GradientTexture2D
var _taken: Dictionary = {}                ## graine d'une trouvaille -> true (ramassée dans cette partie)
var _mat_cache: Dictionary = {}


func setup(p_islands: IslandWorld) -> void:
	islands = p_islands
	name = "IslandLife"
	_rng.randomize()
	_soft = _make_soft_dot()
	for k in GULLS:
		_gulls.append(_make_gull())
	for k in PRINTS:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.17, 0.3)
		q.orientation = PlaneMesh.FACE_Y
		mi.mesh = q
		mi.material_override = _flat_mat(Color(0.2, 0.14, 0.08, 0.42))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_prints.append({"node": mi, "age": PRINT_LIFE})
	for k in LEAVES:
		var mi2 := MeshInstance3D.new()
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.2, 0.12)
		mi2.mesh = q2
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.55, 0.2)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi2.material_override = m
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi2.visible = false
		add_child(mi2)
		_leaves.append({"node": mi2, "vel": Vector3.ZERO, "spin": 0.0, "life": 0.0})
	_fireflies = CPUParticles3D.new()
	_fireflies.amount = 22
	_fireflies.lifetime = 5.0
	_fireflies.preprocess = 2.0
	_fireflies.local_coords = false
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fireflies.emission_box_extents = Vector3(8.0, 0.8, 7.0)
	_fireflies.direction = Vector3.UP
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 0.1
	_fireflies.initial_velocity_max = 0.45
	_fireflies.gravity = Vector3.ZERO
	var fm := SphereMesh.new()
	fm.radius = 0.05
	fm.height = 0.1
	fm.radial_segments = 6
	fm.rings = 3
	_fireflies.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.vertex_color_use_as_albedo = true
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fireflies.material_override = fmat
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.4, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.95, 0.4, 1.0))
	ramp.add_point(0.75, Color(0.8, 1.0, 0.4, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.8, 1.0, 0.4, 0.0))
	_fireflies.color_ramp = ramp
	_fireflies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fireflies.emitting = false
	add_child(_fireflies)


# ------------------------------------------------------------------ outils de fabrication

func _make_soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _solid(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mat_cache[key] = m
	return _mat_cache[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _solid(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _make_gull() -> Dictionary:
	var node := Node3D.new()
	add_child(node)
	node.visible = false
	var wl := Node3D.new()
	var wr := Node3D.new()
	node.add_child(wl)
	node.add_child(wr)
	return {"node": node, "wing_l": wl, "wing_r": wr, "island": -1, "angle": _rng.randf() * TAU, "radius": 0.0, "height": 0.0,
			"speed": _rng.randf_range(0.18, 0.3), "phase": _rng.randf() * TAU, "crow": false, "built": ""}


## (Re)dessine un oiseau selon l'île qu'il survole : mouette blanche, ou corbeau noir sur une île de morts.
func _dress_bird(g: Dictionary, crow: bool) -> void:
	var tag := "crow" if crow else "gull"
	if g["built"] == tag:
		return
	g["built"] = tag
	var node := g["node"] as Node3D
	var wl := g["wing_l"] as Node3D
	var wr := g["wing_r"] as Node3D
	for ch in node.get_children():
		if ch != wl and ch != wr:
			ch.queue_free()
	for w in [wl, wr]:
		for ch in w.get_children():
			ch.queue_free()
	var body_c := Color(0.1, 0.1, 0.13) if crow else Color(0.96, 0.96, 0.94)
	var wing_c := Color(0.07, 0.07, 0.1) if crow else Color(0.88, 0.9, 0.92)
	var tip_c := Color(0.07, 0.07, 0.1) if crow else Color(0.25, 0.27, 0.32)
	_box(node, Vector3(0.16, 0.14, 0.5), Vector3.ZERO, body_c)
	_box(node, Vector3(0.12, 0.12, 0.14), Vector3(0, 0.03, 0.3), body_c)
	_box(node, Vector3(0.05, 0.04, 0.12), Vector3(0, 0.0, 0.42), Color(0.95, 0.7, 0.2) if not crow else Color(0.3, 0.3, 0.32))
	for side in [-1.0, 1.0]:
		var w: Node3D = wl if side < 0.0 else wr
		w.position = Vector3(side * 0.07, 0.04, 0.0)
		_box(w, Vector3(0.45, 0.03, 0.26), Vector3(side * 0.24, 0, 0), wing_c)
		_box(w, Vector3(0.22, 0.03, 0.2), Vector3(side * 0.56, 0, 0.0), tip_c)


# ------------------------------------------------------------------ boucle

## Contexte : pos (Vector2 monde), where ("land", "ship", "swim", …), moved (m à pied), face (Vector2), night, storm, rain.
func update(delta: float, ctx: Dictionary) -> void:
	if islands == null:
		return
	_time += delta
	night = bool(ctx.get("night", false))
	var pos: Vector2 = ctx["pos"]
	var where := str(ctx.get("where", "ship"))
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.6
		_scan(pos)
	var storm := float(ctx.get("storm", 0.0)) > 0.5
	_update_gulls(delta, storm)
	for i: int in _near_ids:
		_update_island(i, pos, delta, where)
	_update_fireflies(pos, where)
	if where == "land":
		_update_prints(delta, pos, float(ctx.get("moved", 0.0)), ctx.get("face", Vector2(0, 1)))
		_update_plants(delta, pos)
	else:
		_update_plants(delta, Vector2(1.0e6, 1.0e6))
	_update_prints_fade(delta)
	_update_leaves(delta)
	_update_rings(delta)
	_update_lore_glints()


## Quelles îles sont près du joueur ? On ne construit leurs accessoires (fumée, brume, crabes) qu'à ce moment-là.
func _scan(pos: Vector2) -> void:
	var list: Array = []
	for i in islands.islands.size():
		var isl: Dictionary = islands.islands[i]
		var d := pos.distance_to(isl["center"]) - float(isl["radius"])
		if d < NEAR:
			list.append([d, i])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_near_ids = []
	for e: Array in list:
		_near_ids.append(int(e[1]))
		_ensure_island(int(e[1]))
	# les accessoires des îles lointaines s'éteignent
	for i: int in _per_island:
		if not _near_ids.has(i):
			var rec: Dictionary = _per_island[i]
			for s: CPUParticles3D in rec["smoke"]:
				s.emitting = false
			if rec["fog"] != null:
				(rec["fog"] as CPUParticles3D).emitting = false
			for c: Dictionary in rec["crabs"]:
				(c["node"] as Node3D).visible = false
	# les oiseaux se répartissent sur les îles proches
	for k in _gulls.size():
		var g: Dictionary = _gulls[k]
		if _near_ids.is_empty():
			g["island"] = -1
			(g["node"] as Node3D).visible = false
			continue
		var island: int = _near_ids[k % _near_ids.size()]
		# ils tournent autour du joueur (près de la plage, ou au-dessus du bateau qui longe la côte), pas au centre de l'île
		var too_far := not g.has("center") or pos.distance_to(g["center"]) > 38.0
		if int(g["island"]) != island or too_far:
			g["island"] = island
			var isl: Dictionary = islands.islands[island]
			var crow := str(isl.get("tone", "lush")) == "dead"
			_dress_bird(g, crow)
			g["center"] = pos + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-10.0, 10.0))
			g["radius"] = _rng.randf_range(8.0, 19.0)
			g["height"] = _rng.randf_range(6.5, 11.0)
			g["speed"] = _rng.randf_range(0.2, 0.34) * (1.0 if not crow else 0.8)
			(g["node"] as Node3D).visible = true


func _ensure_island(i: int) -> void:
	if _per_island.has(i):
		return
	var isl: Dictionary = islands.islands[i]
	if isl["node"] == null:
		return
	var rec := {"smoke": [], "fog": null, "crabs": []}
	_per_island[i] = rec
	var c: Vector2 = isl["center"]
	for it: Dictionary in isl["items"]:
		if it["kind"] == "campfire":
			var p: Vector2 = it["pos"]
			rec["smoke"].append(_make_smoke(Vector3(p.x, islands.height(i, p) + 0.9, p.y)))
	if str(isl.get("tone", "lush")) == "dead":
		rec["fog"] = _make_fog(Vector3(c.x, 0.9, c.y), float(isl["radius"]))
	elif float(isl["radius"]) >= 6.0:
		var crng := RandomNumberGenerator.new()
		crng.seed = hash(str(isl["id"])) + 77
		var want := clampi(int(float(isl["radius"]) / 3.0), 3, 10)
		var tries := 0
		while (rec["crabs"] as Array).size() < want and tries < 400:
			tries += 1
			var rad: float = isl["radius"]
			var p2 := c + Vector2(crng.randf_range(-rad, rad), crng.randf_range(-rad, rad))
			var s := islands.sdf(i, p2)
			if s < 0.9 or s > 2.3:
				continue
			(rec["crabs"] as Array).append(_make_crab(i, p2, crng))


func _make_smoke(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 3.4
	p.preprocess = 3.0
	p.local_coords = false
	p.direction = Vector3(0.25, 1.0, 0.05)
	p.spread = 14.0
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 1.15
	p.gravity = Vector3(0.45, 0.25, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft
	p.material_override = m
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.5, 0.52, 0.55))
	ramp.set_color(1, Color(0.72, 0.72, 0.74, 0.0))
	p.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 2.6))
	p.scale_amount_curve = curve
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = at
	p.emitting = true
	add_child(p)
	return p


func _make_fog(at: Vector3, radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 13.0
	p.preprocess = 13.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(radius * 0.8, 0.3, radius * 0.8)
	p.direction = Vector3(1.0, 0.0, 0.3)
	p.spread = 30.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	var q := QuadMesh.new()
	q.size = Vector2(7.0, 7.0)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft
	p.material_override = m
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.66, 0.84, 0.78, 0.0))
	ramp.add_point(0.3, Color(0.66, 0.84, 0.78, 0.11))
	ramp.add_point(0.7, Color(0.66, 0.84, 0.78, 0.11))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.66, 0.84, 0.78, 0.0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = at
	p.emitting = true
	add_child(p)
	return p


# ------------------------------------------------------------------ oiseaux

func _update_gulls(delta: float, storm: bool) -> void:
	for g: Dictionary in _gulls:
		var node := g["node"] as Node3D
		var i: int = g["island"]
		if i < 0 or not node.visible:
			continue
		var c: Vector2 = g["center"]
		g["angle"] = float(g["angle"]) + delta * float(g["speed"])
		g["phase"] = float(g["phase"]) + delta * (9.0 if not bool(g["crow"]) else 7.0)
		var a: float = g["angle"]
		var r: float = g["radius"]
		var p := Vector3(c.x + cos(a) * r, float(g["height"]) + sin(_time * 0.7 + float(g["phase"]) * 0.01) * 0.5, c.y + sin(a) * r)
		node.position = p
		# cap : le long du cercle
		var tang := Vector3(-sin(a), 0.0, cos(a))
		node.rotation = Vector3(0.0, atan2(tang.x, tang.z), -0.28)
		var flap := sin(float(g["phase"]))
		var glide := 0.5 + 0.5 * sin(_time * 0.4 + a * 3.0)   # parfois il plane
		var amp := 0.7 * (1.0 - 0.8 * glide)
		(g["wing_l"] as Node3D).rotation.z = -flap * amp - 0.1
		(g["wing_r"] as Node3D).rotation.z = flap * amp + 0.1
	if storm:
		pass


# ------------------------------------------------------------------ par île : fumée, brume, crabes

func _update_island(i: int, pos: Vector2, delta: float, _where: String) -> void:
	if not _per_island.has(i):
		return
	var rec: Dictionary = _per_island[i]
	for s: CPUParticles3D in rec["smoke"]:
		s.emitting = true
	if rec["fog"] != null:
		(rec["fog"] as CPUParticles3D).emitting = true
	for c: Dictionary in rec["crabs"]:
		_update_crab(c, i, pos, delta)


func _make_crab(island: int, at: Vector2, crng: RandomNumberGenerator) -> Dictionary:
	var node := Node3D.new()
	add_child(node)
	var shell_c := Color(0.86, 0.3, 0.2) if crng.randf() < 0.7 else Color(0.9, 0.52, 0.22)
	_box(node, Vector3(0.3, 0.1, 0.22), Vector3(0, 0.1, 0), shell_c)
	_box(node, Vector3(0.2, 0.06, 0.16), Vector3(0, 0.17, 0), shell_c.lightened(0.1))
	for sx in [-1.0, 1.0]:
		var claw := _box(node, Vector3(0.13, 0.07, 0.12), Vector3(sx * 0.2, 0.13, 0.17), shell_c.lightened(0.05))
		claw.rotation.y = sx * 0.4
		_box(node, Vector3(0.025, 0.07, 0.025), Vector3(sx * 0.05, 0.22, 0.1), Color(0.1, 0.08, 0.08))
		for k in 3:
			_box(node, Vector3(0.12, 0.025, 0.025), Vector3(sx * 0.2, 0.05, -0.07 + k * 0.06), shell_c.darkened(0.25)).rotation.z = sx * -0.5
	node.position = Vector3(at.x, 0.0, at.y)
	node.visible = false
	return {"node": node, "pos": at, "home": at, "island": island, "state": "idle", "t": crng.randf_range(0.5, 3.0), "dir": Vector2.RIGHT,
			"yaw": crng.randf() * TAU, "alive": true}


func _update_crab(c: Dictionary, island: int, player: Vector2, delta: float) -> void:
	var node := c["node"] as Node3D
	var pos: Vector2 = c["pos"]
	var d := pos.distance_to(player)
	node.visible = d < CRAB_RANGE
	if not node.visible:
		return
	var speed := 0.0
	var t := float(c["t"]) - delta
	if d < 2.7:   # il détale, de côté, loin du joueur
		c["state"] = "flee"
		var away := (pos - player).normalized()
		c["dir"] = away
		speed = 3.4
	elif c["state"] == "flee":
		c["state"] = "idle"
		t = _rng.randf_range(1.0, 3.0)
	elif c["state"] == "idle" and t <= 0.0:
		c["state"] = "wander"
		var a := _rng.randf() * TAU
		c["dir"] = Vector2(cos(a), sin(a))
		t = _rng.randf_range(0.6, 1.6)
	elif c["state"] == "wander":
		speed = 0.9
		if t <= 0.0:
			c["state"] = "idle"
			t = _rng.randf_range(1.0, 4.0)
	c["t"] = t
	if speed > 0.0:
		var dir: Vector2 = c["dir"]
		var np := pos + dir * speed * delta
		var s := islands.sdf(island, np)
		if s > 0.25 and s < 3.2:   # il reste sur la plage
			c["pos"] = np
			pos = np
		else:
			c["dir"] = -dir
		# les crabes marchent de côté : leur flanc regarde où ils vont
		c["yaw"] = lerp_angle(float(c["yaw"]), atan2(dir.x, dir.y) + PI * 0.5, 1.0 - exp(-delta * 10.0))
	node.position = Vector3(pos.x, islands.height(island, pos) + 0.0 + 0.012 * sin(_time * 30.0) * (1.0 if speed > 0.0 else 0.0), pos.y)
	node.rotation.y = float(c["yaw"])


# ------------------------------------------------------------------ lucioles, traces de pas, éclaboussures

func _update_fireflies(pos: Vector2, where: String) -> void:
	var on := false
	if night and where == "land":
		var i := islands.island_at(pos)
		if i >= 0 and str(islands.islands[i].get("tone", "lush")) == "lush" and islands.sdf(i, pos) > 3.0:
			on = true
			_fireflies.position = Vector3(pos.x, islands.height(i, pos) + 1.1, pos.y)
	_fireflies.emitting = on


func _update_prints(delta: float, pos: Vector2, moved: float, face: Vector2) -> void:
	if moved <= 0.0001:
		return
	_print_acc += moved
	if _print_acc < 0.62:
		return
	_print_acc = 0.0
	var i := islands.island_at(pos)
	if i < 0:
		return
	var s := islands.sdf(i, pos)
	var tone := str(islands.islands[i].get("tone", "lush"))
	if s > 4.4 and tone != "dead":
		return   # l'herbe ne garde pas les traces
	var f := face.normalized() if face.length() > 0.01 else Vector2(0, 1)
	_print_side = -_print_side
	var side := Vector2(-f.y, f.x) * 0.12 * _print_side
	var at := pos + side
	var rec: Dictionary = _prints[_print_i]
	_print_i = (_print_i + 1) % _prints.size()
	var node := rec["node"] as MeshInstance3D
	node.position = Vector3(at.x, islands.height(i, at) + 0.025, at.y)
	node.rotation = Vector3(0.0, atan2(f.x, f.y), 0.0)
	node.visible = true
	rec["age"] = 0.0
	# dans l'eau peu profonde, un petit éclaboussement
	if s < 0.3:
		splash(at, 0.5)


func _update_prints_fade(delta: float) -> void:
	for rec: Dictionary in _prints:
		var node := rec["node"] as MeshInstance3D
		if not node.visible:
			continue
		rec["age"] = float(rec["age"]) + delta
		var k := float(rec["age"]) / PRINT_LIFE
		if k >= 1.0:
			node.visible = false
			continue
		node.transparency = clampf(k * k, 0.0, 1.0)


## Une éclaboussure : deux anneaux d'écume qui s'élargissent à la surface.
func splash(at: Vector2, size: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.62
	tm.rings = 14
	tm.ring_segments = 4
	mi.mesh = tm
	mi.material_override = _flat_mat(Color(0.95, 0.98, 1.0, 0.8))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y := -1.2
	var i := islands.island_at(at, 3.0)
	if i >= 0:
		y = IslandWorld.SHALLOW_Y + 0.05
	mi.position = Vector3(at.x, y, at.y)
	mi.scale = Vector3(0.3, 0.3, 0.3) * size
	add_child(mi)
	_rings.append({"node": mi, "t": 0.0, "size": size})


func _update_rings(delta: float) -> void:
	for k in range(_rings.size() - 1, -1, -1):
		var r: Dictionary = _rings[k]
		r["t"] = float(r["t"]) + delta
		var u := float(r["t"]) / 0.7
		var node := r["node"] as MeshInstance3D
		if u >= 1.0:
			node.queue_free()
			_rings.remove_at(k)
			continue
		var sc := (0.3 + 1.6 * u) * float(r["size"])
		node.scale = Vector3(sc, sc * 0.4, sc)
		node.transparency = u * u


# ------------------------------------------------------------------ plantes et feuilles

func _update_plants(delta: float, pos: Vector2) -> void:
	for i: int in _near_ids:
		var isl: Dictionary = islands.islands[i]
		if pos.distance_to(isl["center"]) > float(isl["radius"]) + 8.0 and _pushed.is_empty() and _kicks.is_empty():
			continue
		for it: Dictionary in isl["plants"]:
			var p: Vector2 = it["pos"]
			var d := p.distance_to(pos)
			var k := float(_pushed.get(int(it["seed"]), 0.0))
			var kick := float(_kicks.get(int(it["seed"]), 0.0))
			var tgt := 0.0
			if d < PUSH_RANGE:
				tgt = 1.0 - d / PUSH_RANGE
				if k < 0.05 and tgt > 0.3 and it["kind"] != "palm" and not _kicks.has(int(it["seed"])):
					pass
			if tgt <= 0.0 and k <= 0.002 and kick <= 0.002:
				continue
			k = lerpf(k, tgt, 1.0 - exp(-delta * 9.0))
			kick = maxf(kick - delta * 1.6, 0.0)
			if k > 0.002:
				_pushed[int(it["seed"])] = k
			else:
				_pushed.erase(int(it["seed"]))
				k = 0.0
			if kick > 0.002:
				_kicks[int(it["seed"])] = kick
			else:
				_kicks.erase(int(it["seed"]))
			var node := it["node"] as Node3D
			if node == null:
				continue
			var yaw: float = it["yaw"]
			var away := (p - pos).normalized() if d > 0.01 else Vector2.RIGHT
			var amp := 0.08 if it["kind"] == "palm" else 0.5
			var ang := k * amp + kick * sin(_time * 22.0) * (0.06 if it["kind"] == "palm" else 0.25)
			var axis := Vector3.UP.cross(Vector3(away.x, 0.0, away.y)).normalized()
			node.transform.basis = Basis(axis, ang) * Basis(Vector3.UP, yaw) if axis.length() > 0.01 else Basis(Vector3.UP, yaw)


## Un coup de sabre : un palmier ou un buisson devant le joueur secoue ses feuilles. Rend vrai si quelque chose a été secoué.
func swing(origin: Vector2, dir: Vector2) -> bool:
	var hit := false
	var d := dir.normalized()
	for i: int in _near_ids:
		for it: Dictionary in islands.islands[i]["plants"]:
			var p: Vector2 = it["pos"]
			var to := p - origin
			var dist := to.length()
			if dist > 2.3 or dist < 0.05 or d.dot(to / dist) < 0.25:
				continue
			_kicks[int(it["seed"])] = 1.0
			var crown := 3.6 if it["kind"] == "palm" else 0.8
			var h := islands.height(i, p)
			_burst_leaves(Vector3(p.x, h + crown, p.y), 8 if it["kind"] == "palm" else 5)
			hit = true
	return hit


func _burst_leaves(at: Vector3, n: int) -> void:
	var made := 0
	for l: Dictionary in _leaves:
		if made >= n:
			break
		var node := l["node"] as MeshInstance3D
		if node.visible:
			continue
		node.visible = true
		node.position = at + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.2, 0.4), _rng.randf_range(-0.5, 0.5))
		l["vel"] = Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(0.0, 0.8), _rng.randf_range(-0.8, 0.8))
		l["spin"] = _rng.randf_range(-6.0, 6.0)
		l["life"] = _rng.randf_range(1.6, 2.6)
		node.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		made += 1


func _update_leaves(delta: float) -> void:
	for l: Dictionary in _leaves:
		var node := l["node"] as MeshInstance3D
		if not node.visible:
			continue
		l["life"] = float(l["life"]) - delta
		var vel: Vector3 = l["vel"]
		vel.y = move_toward(vel.y, -1.1, delta * 3.5)   # elle tombe en flottant
		vel.x = move_toward(vel.x, 0.3, delta)
		l["vel"] = vel
		node.position += vel * delta + Vector3(sin(_time * 5.0 + float(l["spin"])) * 0.4 * delta, 0, 0)
		node.rotation.x += float(l["spin"]) * delta
		node.rotation.z += float(l["spin"]) * 0.6 * delta
		if float(l["life"]) <= 0.0 or node.position.y < 0.02:
			node.visible = false


# ------------------------------------------------------------------ trouvailles

## La trouvaille (bouteille, journal) à portée du joueur à pied, ou {}. Les naufragés sont des PNJ à part.
func nearest_lore(p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := LORE_REACH
	for i: int in _near_ids:
		for it: Dictionary in islands.islands[i]["lore_items"]:
			if it["kind"] == "castaway" or _taken.has(int(it["seed"])):
				continue
			var d: float = (it["pos"] as Vector2).distance_to(p)
			if d < best_d:
				best_d = d
				best = it
	return best


## Ramasse la trouvaille : elle disparaît (l'éclat et l'objet).
func take_lore(it: Dictionary) -> void:
	_taken[int(it["seed"])] = true
	var node := it.get("node") as Node3D
	if node != null:
		node.visible = false
	# un petit scintillement de feuilles… ou d'écume, pour marquer l'instant
	var p: Vector2 = it["pos"]
	_burst_leaves(Vector3(p.x, 0.4, p.y), 0)


func is_taken(it: Dictionary) -> bool:
	return _taken.has(int(it["seed"]))


func _update_lore_glints() -> void:
	for i: int in _near_ids:
		for it: Dictionary in islands.islands[i]["lore_items"]:
			var node := it.get("node") as Node3D
			if node == null or _taken.has(int(it["seed"])):
				continue
			var glint := node.get_node_or_null("glint") as Node3D
			if glint != null:
				glint.position.y = (0.75 if it["kind"] == "bottle" else 1.0) + 0.1 * sin(_time * 3.0 + float(it["seed"]))
				glint.scale = Vector3.ONE * (1.0 + 0.25 * sin(_time * 6.0 + float(it["seed"])))
