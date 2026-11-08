class_name EnemyFleet
extends RefCounted
## Les bateaux de pirates ennemis : de vrais bateaux (le même modèle que ceux des joueurs, voiles noires) pilotés par une IA.
## Ils croisent au large, foncent sur le bateau des joueurs quand ils le voient, se placent bord à bord et tirent des volées de
## boulets. Les boulets des joueurs les abîment ; coulés, ils laissent flotter leur butin (voir WorldLoot).
## L'hôte (ou le solo) fait vivre l'IA ; les clients copient l'état reçu (net_state / apply_net) et le lissent.
## Rien ici ne touche à la scène du jeu : le jeu fournit des rappels (Callable) pour tirer, poser du butin et tester l'eau libre.

const MAX_SHIPS := 2
const SPAWN_MIN := 280.0       ## m : un nouvel ennemi apparaît à cette distance du bateau des joueurs...
const SPAWN_MAX := 380.0       ## ... au plus
const DESPAWN := 700.0         ## m : trop loin, un ennemi est retiré (sans butin)
const AGGRO := 150.0           ## m : il voit les joueurs
const FIRE_RANGE := 64.0       ## m : portée de ses canons
const FIRE_ARC := 0.5          ## rad : le flanc doit viser à ce point près
const MIN_DIST := 26.0         ## m : il ne s'approche pas plus près
const SINK_TIME := 7.0         ## s : durée du naufrage
const PORT_SAFE := 300.0       ## m : pas d'ennemi qui apparaît si près du port
const VOLLEY_COOLDOWN := 5.0
const KINDS: Array = ["sloop", "brigantin"]
const STATS := {
	"sloop": {"hp": 70.0, "name": "Sloop flibustier", "loot": 1.0},
	"brigantin": {"hp": 130.0, "name": "Brigantin pirate", "loot": 1.7},
}
const SKIN := {"sail": "black", "hull": "crimson", "flag": "black"}

var ships: Array = []          ## {id, kind, sim: ShipSim, hp, hp_max, state, sink_t, model, cannons, label, queue, cd, home, wp, wp_t, target_pos, target_yaw, age}
var _root: Node3D
var _next_id := 1
var _spawn_t := 25.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()

## Rappels du jeu.
var fire_cb: Callable = Callable()       ## (id, indice du canon, départ Vector3, vitesse Vector3) : un boulet part
var loot_cb: Callable = Callable()       ## (genre, position Vector2, vitesse Vector2) : du butin est posé
var water_free_cb: Callable = Callable() ## (position Vector2) -> vrai si l'eau est libre (ni terre, ni quai, ni récif)
var wave_cb: Callable = Callable()       ## (position Vector2) -> hauteur de la houle
var sunk_cb: Callable = Callable()       ## (id, nom) : un ennemi vient de couler
var spawn_origin := Vector2.ZERO         ## le port : pas d'apparition à moins de PORT_SAFE
var spawn_enabled := true                ## faux : plus d'apparition spontanée (essais, ou `--no-enemies`)


func setup(parent: Node3D) -> void:
	_root = Node3D.new()
	_root.name = "EnemyFleet"
	parent.add_child(_root)
	_rng.randomize()


func alive_count() -> int:
	var n := 0
	for s: Dictionary in ships:
		if s["state"] != "sinking":
			n += 1
	return n


func find(id: int) -> int:
	for i in ships.size():
		if int((ships[i] as Dictionary)["id"]) == id:
			return i
	return -1


# ------------------------------------------------------------------ création

func spawn(kind: String, pos: Vector2, yaw: float, id: int = -1) -> int:
	var sid := id if id >= 0 else _next_id
	_next_id = maxi(_next_id, sid + 1)
	var stats: Dictionary = STATS[kind]
	var sim := ShipSim.new()
	var all_stats := IslandWorld.read_json("res://data/ship_stats.json")
	sim.configure(all_stats.get(kind, {}))
	sim.max_speed *= 0.82     # un peu moins vifs que les joueurs : on peut les semer
	sim.position = pos
	sim.yaw = yaw
	sim.sail_level = 2
	sim.sail_open = 0.66
	sim.auto_trim_pending = false
	var s := {"id": sid, "kind": kind, "sim": sim, "hp": float(stats["hp"]), "hp_max": float(stats["hp"]), "state": "patrol",
			"sink_t": 0.0, "model": null, "cannons": [], "label": null, "queue": [], "cd": [0.0, 2.5], "home": pos,
			"wp": pos, "wp_t": 0.0, "target_pos": pos, "target_yaw": yaw, "age": 0.0, "chips_hp": float(stats["hp"])}
	_make_visual(s)
	ships.append(s)
	return sid


func _make_visual(s: Dictionary) -> void:
	if _root == null:
		return
	var model := ShipModel.new()
	if not model.load_ship(str(s["kind"])):
		return
	ShipSkin.apply(model, SKIN)
	_root.add_child(model)
	s["model"] = model
	s["cannons"] = ShipCannons.build(model)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.pixel_size = 0.02
	label.render_priority = 12
	label.outline_size = 10
	label.outline_modulate = Color(0.1, 0.04, 0.04)
	label.modulate = Color(1.0, 0.6, 0.5)
	label.no_depth_test = true
	label.position = Vector3(0.0, float((model.meta.get("max_height", 8.0))) * ShipModel.SCALE * 0.78, 0.0)
	model.add_child(label)
	s["label"] = label
	_place_visual(s, 0.0)


# ------------------------------------------------------------------ boucle

## `target` : {pos: Vector2, vel: Vector2, alive: bool, wind: Vector2} (le bateau des joueurs).
func step(delta: float, authority: bool, target: Dictionary) -> void:
	_time += delta
	if authority:
		_host_step(delta, target)
	for i in range(ships.size() - 1, -1, -1):
		var s: Dictionary = ships[i]
		s["age"] = float(s["age"]) + delta
		if s["state"] == "sinking":
			s["sink_t"] = float(s["sink_t"]) + delta
			if float(s["sink_t"]) >= SINK_TIME:
				_remove(i)
				continue
		elif not authority:
			var sim: ShipSim = s["sim"]
			# le client avance comme l'hôte et se recale en douceur
			var fwd := sim.forward()
			sim.position += fwd * sim.speed * delta
			sim.position = sim.position.lerp(s["target_pos"], 1.0 - exp(-delta * 4.0))
			sim.yaw = lerp_angle(sim.yaw, float(s["target_yaw"]), 1.0 - exp(-delta * 4.0))
		_place_visual(s, delta)


func _host_step(delta: float, target: Dictionary) -> void:
	var tpos: Vector2 = target["pos"]
	# apparition et retrait
	if spawn_enabled and bool(target.get("alive", true)):
		_spawn_t -= delta
		if _spawn_t <= 0.0 and alive_count() < MAX_SHIPS:
			_spawn_t = _rng.randf_range(55.0, 110.0)
			_try_spawn(tpos)
	for i in range(ships.size() - 1, -1, -1):
		var s: Dictionary = ships[i]
		if s["state"] == "sinking":
			continue
		var sim: ShipSim = s["sim"]
		if sim.position.distance_to(tpos) > DESPAWN:
			_remove(i)
			continue
		sim.wind_dir = target.get("wind", sim.wind_dir)
		sim.wind_angle = (sim.wind_dir as Vector2).angle()
		_ai(s, delta, target)
		sim.sail_trim_target = sim.optimal_trim()
		sim.step(delta)
		_fire_queue(s, delta)


func _try_spawn(tpos: Vector2) -> void:
	for attempt in 14:
		var p := tpos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		if p.distance_to(spawn_origin) < PORT_SAFE:
			continue
		if water_free_cb.is_valid() and not bool(water_free_cb.call(p)):
			continue
		var kind: String = KINDS[0] if _rng.randf() < 0.65 else KINDS[1]
		spawn(kind, p, _rng.randf() * TAU)
		return


func _ai(s: Dictionary, dt: float, target: Dictionary) -> void:
	var sim: ShipSim = s["sim"]
	var tpos: Vector2 = target["pos"]
	var to := tpos - sim.position
	var d := to.length()
	var bearing := atan2(-to.y, to.x)   # cap qui mène droit au bateau des joueurs (même convention que ShipSim.yaw)
	var desired := sim.yaw
	var alive := bool(target.get("alive", true))
	if s["state"] == "patrol":
		s["wp_t"] = float(s["wp_t"]) - dt
		if float(s["wp_t"]) <= 0.0 or sim.position.distance_to(s["wp"]) < 25.0:
			s["wp"] = (s["home"] as Vector2) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60.0, 220.0)
			s["wp_t"] = 30.0
		var wv: Vector2 = (s["wp"] as Vector2) - sim.position
		desired = atan2(-wv.y, wv.x)
		sim.sail_level = 2
		if alive and d < AGGRO:
			s["state"] = "chase"
	else:   # chase
		if not alive or d > AGGRO * 1.7:
			s["state"] = "patrol"
			s["home"] = sim.position
		sim.sail_level = 3 if d > 75.0 else 2
		if d > 70.0:
			desired = bearing
		else:
			# présenter le flanc : cap perpendiculaire à la direction du bateau des joueurs, du côté le plus proche du cap actuel
			var a := bearing + PI * 0.5
			var b := bearing - PI * 0.5
			desired = a if absf(wrapf(a - sim.yaw, -PI, PI)) < absf(wrapf(b - sim.yaw, -PI, PI)) else b
			if d < MIN_DIST:
				desired = bearing + PI   # trop près : on s'écarte
			sim.sail_level = 2 if d > 40.0 else 1
	# éviter la terre : si l'eau n'est pas libre devant, on tourne du côté dégagé
	if water_free_cb.is_valid():
		var fwd := sim.forward()
		if not bool(water_free_cb.call(sim.position + fwd * 20.0)) or not bool(water_free_cb.call(sim.position + fwd * 10.0)):
			var left_ok := bool(water_free_cb.call(sim.position + fwd.rotated(-0.9) * 16.0))
			var right_ok := bool(water_free_cb.call(sim.position + fwd.rotated(0.9) * 16.0))
			if left_ok or not right_ok:
				desired = sim.yaw + 0.9
			else:
				desired = sim.yaw - 0.9
			sim.sail_level = 1
	var diff := wrapf(desired - sim.yaw, -PI, PI)
	sim.rudder_target = clampf(-diff * 1.8, -1.0, 1.0)
	# volée : le flanc qui regarde les joueurs, à portée et à peu près en face
	if s["state"] == "chase" and alive and d < FIRE_RANGE and d > 8.0:
		var port_vec := Vector2(sim.forward().y, -sim.forward().x)
		for si in 2:
			var side := 1.0 if si == 0 else -1.0
			var cd: Array = s["cd"]
			cd[si] = float(cd[si]) - dt
			var ang := absf((port_vec * side).angle_to(to))
			if float(cd[si]) <= 0.0 and ang < FIRE_ARC and (s["queue"] as Array).is_empty():
				cd[si] = VOLLEY_COOLDOWN + _rng.randf_range(-0.8, 1.2)
				_queue_volley(s, int(side), target)
	else:
		var cd2: Array = s["cd"]
		cd2[0] = maxf(float(cd2[0]) - dt, 0.0)
		cd2[1] = maxf(float(cd2[1]) - dt, 0.0)


## Met en file les tirs de chaque canon du flanc `side` (+1 bâbord, -1 tribord) : ils partent l'un après l'autre.
func _queue_volley(s: Dictionary, side: int, target: Dictionary) -> void:
	var model := s["model"] as ShipModel
	if model == null:
		return
	var t := 0.0
	for i in model.cannons.size():
		if int((model.cannons[i] as Array)[2]) != side:
			continue
		(s["queue"] as Array).append([t, i, target["pos"], target.get("vel", Vector2.ZERO)])
		t += _rng.randf_range(0.12, 0.35)


func _fire_queue(s: Dictionary, delta: float) -> void:
	var q: Array = s["queue"]
	for k in range(q.size() - 1, -1, -1):
		var e: Array = q[k]
		e[0] = float(e[0]) - delta
		if float(e[0]) > 0.0:
			continue
		q.remove_at(k)
		var model := s["model"] as ShipModel
		if model == null or not fire_cb.is_valid():
			continue
		var idx := int(e[1])
		if idx >= (s["cannons"] as Array).size():
			continue
		var start := _root.to_local(model.to_global(ShipCannons.muzzle_local((s["cannons"] as Array)[idx])))
		var tgt_pos: Vector2 = e[2]
		var tvel: Vector2 = e[3]
		var dist := Vector2(start.x, start.z).distance_to(tgt_pos)
		var flight := clampf(dist / 24.0, 0.7, 2.4)
		var spread := 2.6 + 0.05 * dist
		var aim := tgt_pos + tvel * flight + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
		var target3 := Vector3(aim.x, 0.2, aim.y)
		var vel := Vector3((target3.x - start.x) / flight, (target3.y - start.y) / flight + 0.5 * 16.0 * flight, (target3.z - start.z) / flight)
		fire_cb.call(int(s["id"]), idx, start, vel)


# ------------------------------------------------------------------ dégâts, naufrage, butin

## Un boulet à `pos` (repère de la scène du monde) touche-t-il la coque d'un ennemi ? Renvoie son identifiant, sinon -1.
func ball_hit(pos: Vector3) -> int:
	for s: Dictionary in ships:
		if s["state"] == "sinking" or s["model"] == null:
			continue
		var model := s["model"] as ShipModel
		var loc := model.to_local(_root.to_global(pos))
		var bx := loc.x / ShipModel.SCALE - model.shift
		var by := -loc.z / ShipModel.SCALE
		if absf(bx) > model.length * 0.5 or absf(by) > model.half_width(bx) + 0.12:
			continue
		if loc.y < -1.7 or loc.y > model.deck_height(bx) + 0.8:
			continue
		return int(s["id"])
	return -1


## Hôte : l'ennemi `id` encaisse `dmg` points. Renvoie vrai s'il coule à l'instant.
func hurt(id: int, dmg: float) -> bool:
	var i := find(id)
	if i < 0:
		return false
	var s: Dictionary = ships[i]
	if s["state"] == "sinking":
		return false
	s["hp"] = float(s["hp"]) - dmg
	if s["state"] == "patrol":
		s["state"] = "chase"   # il se sait attaqué
	if float(s["hp"]) > 0.0:
		return false
	_start_sink(s)
	return true


func _start_sink(s: Dictionary) -> void:
	s["state"] = "sinking"
	s["sink_t"] = 0.0
	var sim: ShipSim = s["sim"]
	sim.sail_level = 0
	s["queue"] = []
	# le butin s'échappe de la cale et flotte autour de l'épave
	if loot_cb.is_valid():
		var mult := float((STATS[str(s["kind"])] as Dictionary)["loot"])
		var drops: Array = []
		for k in int(round(2.0 * mult)) + _rng.randi_range(0, 1):
			drops.append("t:" + Treasure.roll(_rng, 1.4))
		for k in _rng.randi_range(3, 5):
			drops.append("plank")
		for k in _rng.randi_range(2, 4):
			drops.append("ball")
		for k in _rng.randi_range(1, 2):
			drops.append("g:%d" % int(_rng.randi_range(40, 110) * mult))
		for kind: String in drops:
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(2.0, 9.0)
			loot_cb.call(kind, sim.position + Vector2.from_angle(a) * r, Vector2.from_angle(a) * _rng.randf_range(0.2, 0.7))
	if sunk_cb.is_valid():
		sunk_cb.call(int(s["id"]), str((STATS[str(s["kind"])] as Dictionary)["name"]))


func _remove(i: int) -> void:
	var s: Dictionary = ships[i]
	if s["model"] != null:
		(s["model"] as Node).queue_free()
	ships.remove_at(i)


func clear() -> void:
	for i in range(ships.size() - 1, -1, -1):
		_remove(i)


# ------------------------------------------------------------------ affichage

func _place_visual(s: Dictionary, _delta: float) -> void:
	var model := s["model"] as ShipModel
	if model == null:
		return
	var sim: ShipSim = s["sim"]
	var wave := float(wave_cb.call(sim.position)) if wave_cb.is_valid() else 0.0
	var y := wave * 0.6
	var roll := sin(_time * 0.9 + float(s["id"])) * 0.03 - sim.rudder * 0.04 * clampf(sim.speed / maxf(sim.max_speed, 0.1), 0.0, 1.0)
	var pitch := sin(_time * 0.7 + float(s["id"]) * 1.7) * 0.02
	if s["state"] == "sinking":
		var k := clampf(float(s["sink_t"]) / SINK_TIME, 0.0, 1.0)
		y -= k * k * 5.0
		roll += k * 0.75
		pitch += k * 0.22
		model.set_sail_open(maxf(0.1, 1.0 - k * 1.4))
	else:
		model.set_sail_open(sim.sail_open)
	model.set_sail_trim(sim.sail_trim)
	model.position = Vector3(sim.position.x, y, sim.position.y)
	model.rotation = Vector3(roll, sim.yaw, pitch)
	var label := s["label"] as Label3D
	if label != null:
		var frac := clampf(float(s["hp"]) / float(s["hp_max"]), 0.0, 1.0)
		var n := int(ceil(frac * 10.0))
		label.text = "%s\n[%s%s]" % [str((STATS[str(s["kind"])] as Dictionary)["name"]), "#".repeat(n), "-".repeat(10 - n)]
		label.visible = s["state"] != "sinking"
	# des éclats quand la coque encaisse (chez tout le monde : la vie baisse dans l'état reçu)
	if float(s["hp"]) < float(s["chips_hp"]) - 0.5:
		s["chips_hp"] = float(s["hp"])
		_chips(model)


func _chips(model: ShipModel) -> void:
	for k in 8:
		var chip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.06, 0.1)
		chip.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.82, 0.64, 0.4)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		chip.material_override = m
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(chip)
		var base := model.position + Vector3(_rng.randf_range(-3.0, 3.0), 0.8, _rng.randf_range(-1.5, 1.5)).rotated(Vector3.UP, model.rotation.y)
		chip.position = base
		var tw := chip.create_tween()
		tw.set_parallel(true)
		tw.tween_property(chip, "position", base + Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(0.8, 2.0), _rng.randf_range(-1.5, 1.5)), 0.6)
		tw.tween_property(chip, "scale", Vector3.ZERO, 0.6)
		tw.chain().tween_callback(chip.queue_free)


## Un boulet ennemi vient de partir du canon `idx` de l'ennemi `id` : le fût recule, de la fumée sort (chez tout le monde).
func muzzle_effect(id: int, idx: int) -> void:
	var i := find(id)
	if i < 0:
		return
	var s: Dictionary = ships[i]
	var casts: Array = s["cannons"]
	if idx >= 0 and idx < casts.size():
		ShipCannons.kick(casts[idx])


# ------------------------------------------------------------------ réseau

func net_state() -> Array:
	var out: Array = []
	for s: Dictionary in ships:
		var sim: ShipSim = s["sim"]
		out.append([int(s["id"]), KINDS.find(str(s["kind"])), sim.position.x, sim.position.y, sim.yaw, float(s["hp"]),
				{"patrol": 0, "chase": 1, "sinking": 2}[str(s["state"])], sim.speed, sim.sail_open, sim.sail_trim, sim.rudder])
	return out


func apply_net(state: Array) -> void:
	var seen := {}
	for e: Array in state:
		var id := int(e[0])
		seen[id] = true
		var i := find(id)
		var kind: String = KINDS[clampi(int(e[1]), 0, KINDS.size() - 1)]
		if i < 0:
			spawn(kind, Vector2(float(e[2]), float(e[3])), float(e[4]), id)
			i = find(id)
		var s: Dictionary = ships[i]
		var sim: ShipSim = s["sim"]
		s["target_pos"] = Vector2(float(e[2]), float(e[3]))
		s["target_yaw"] = float(e[4])
		s["hp"] = float(e[5])
		var code := int(e[6])
		var new_state := ["patrol", "chase", "sinking"][clampi(code, 0, 2)] as String
		if new_state == "sinking" and s["state"] != "sinking":
			s["sink_t"] = 0.0
		s["state"] = new_state
		sim.speed = float(e[7])
		sim.sail_open = float(e[8])
		sim.sail_trim = float(e[9])
		sim.rudder = float(e[10])
	for i in range(ships.size() - 1, -1, -1):
		var s2: Dictionary = ships[i]
		if not seen.has(int(s2["id"])) and s2["state"] != "sinking":
			_remove(i)
