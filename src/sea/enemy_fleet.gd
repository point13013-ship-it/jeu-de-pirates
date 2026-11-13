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
const PORT_PEACE := 170.0      ## m : 13/11 (Jimmy) : un bateau des joueurs au port (à moins de ça) n'est pas pris en chasse ; une chasse déjà lancée continue
const PORT_SAFE := 300.0       ## m : pas d'ennemi qui apparaît si près du port
const VOLLEY_COOLDOWN := 5.0
const KINDS: Array = ["sloop", "brigantin", "galion"]
const STATS := {
	"sloop": {"hp": 70.0, "name": "Sloop flibustier", "loot": 1.0},
	"brigantin": {"hp": 130.0, "name": "Brigantin pirate", "loot": 1.7},
	"galion": {"hp": 190.0, "name": "Galion de la Terreur", "loot": 2.5},
}
const RANK_NAMES := ["", "Matelots", "Forbans", "Écumeurs", "Terreur des mers"]
const SKIN := {"sail": "black", "hull": "crimson", "flag": "black"}

var repairs: Array = []        ## hôte : positions des bateaux qui viennent de réparer (vidé par le jeu à chaque image)
var ships: Array = []          ## {id, kind, sim: ShipSim, hp, hp_max, state, sink_t, model, cannons, label, queue, cd, home, wp, wp_t, target_pos, target_yaw, age}
var _root: Node3D
var _next_id := 1
var _spawn_t := GameConfig.ENEMY_SPAWN_FIRST
var _time := 0.0
var _rng := RandomNumberGenerator.new()

## Rappels du jeu.
var fire_cb: Callable = Callable()       ## (id, indice du canon, départ Vector3, vitesse Vector3) : un boulet part
var loot_cb: Callable = Callable()       ## (genre, position Vector2, vitesse Vector2) : du butin est posé
var water_free_cb: Callable = Callable() ## (position Vector2) -> vrai si l'eau est libre (ni terre, ni quai, ni récif)
var wave_cb: Callable = Callable()       ## (position Vector2) -> hauteur de la houle
var blocker_cb: Callable = Callable()    ## (modèle ShipModel, position Vector2, cap) -> vrai si le bateau toucherait celui des joueurs : il s'arrête
var sunk_cb: Callable = Callable()       ## (id, nom) : un ennemi vient de couler
var port_peace := 0.0                    ## m : rayon du refuge autour du port (0 : aucun ; le jeu met PORT_PEACE)
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

func spawn(kind: String, pos: Vector2, yaw: float, id: int = -1, rank: int = 0) -> int:
	var sid := id if id >= 0 else _next_id
	_next_id = maxi(_next_id, sid + 1)
	if rank <= 0:   # (essais, ou ancien appel) : le premier rang qui utilise ce bateau
		rank = 1
		for r in GameConfig.ENEMY_RANKS.size():
			if str(GameConfig.ENEMY_RANKS[r]["kind"]) == kind:
				rank = r + 1
				break
	var rdef: Dictionary = rank_def(rank)
	var stats: Dictionary = STATS[kind]
	var sim := ShipSim.new()
	var all_stats := IslandWorld.read_json("res://data/ship_stats.json")
	sim.configure(all_stats.get(kind, {}))
	# moins vifs qu'un joueur sur le même bateau (on peut les semer), d'autant moins que le rang est haut
	var vs: Array = GameConfig.ENEMY_SPEED_VS_PLAYER
	sim.max_speed *= GameConfig.PLAYER_SHIP_SPEED_MULT * float(vs[clampi(rank - 1, 0, vs.size() - 1)])
	sim.position = pos
	sim.yaw = yaw
	sim.sail_level = 2
	sim.sail_open = 0.66
	sim.auto_trim_pending = false
	var hp := float(stats["hp"]) * GameConfig.ENEMY_HP_MULT * float(rdef["hp"])   # lot 5 : +25 %, et plus selon le rang
	var s := {"id": sid, "kind": kind, "rank": rank, "sim": sim, "hp": hp, "hp_max": hp, "state": "patrol",
			"sink_t": 0.0, "model": null, "cannons": [], "label": null, "queue": [], "cd": [0.0, 2.5], "home": pos,
			"wp": pos, "wp_t": 0.0, "target_pos": pos, "target_yaw": yaw, "age": 0.0, "chips_hp": hp,
			"planks": int(rdef["planks"]), "repair_t": GameConfig.ENEMY_REPAIR_EVERY, "calm_t": 0.0, "reveal_t": 0.0}
	_make_visual(s)
	ships.append(s)
	return sid


## La description d'un rang (1 à 4, voir GameConfig.ENEMY_RANKS).
static func rank_def(rank: int) -> Dictionary:
	return GameConfig.ENEMY_RANKS[clampi(rank, 1, GameConfig.ENEMY_RANKS.size()) - 1]


## Tire un rang au hasard selon les poids (les rangs élevés sont rares).
func _roll_rank() -> int:
	var total := 0
	for r: Dictionary in GameConfig.ENEMY_RANKS:
		total += int(r["weight"])
	var x := _rng.randi_range(1, total)
	for i in GameConfig.ENEMY_RANKS.size():
		x -= int(GameConfig.ENEMY_RANKS[i]["weight"])
		if x <= 0:
			return i + 1
	return 1


## 6.7 : l'ennemi `id` est révélé sur la carte de tout l'équipage (il vient de nous toucher, ou on échange des tirs).
func reveal(id: int) -> void:
	var i := find(id)
	if i >= 0:
		(ships[i] as Dictionary)["reveal_t"] = GameConfig.ENEMY_REVEAL_TIME


## Les ennemis révélés : [{pos: Vector2, rank, name}] (pour la carte).
func revealed() -> Array:
	var out: Array = []
	for s: Dictionary in ships:
		if float(s.get("reveal_t", 0.0)) > 0.0 and s["state"] != "sinking":
			out.append({"pos": (s["sim"] as ShipSim).position, "rank": int(s.get("rank", 1)), "name": label_name(s)})
	return out


static func label_name(s: Dictionary) -> String:
	var r := int(s.get("rank", 1))
	return "%s %s" % ["★".repeat(r), str((STATS[str(s["kind"])] as Dictionary)["name"])]


func _make_visual(s: Dictionary) -> void:
	if _root == null:
		return
	var model := ShipModel.new()
	if not model.load_ship(str(s["kind"])):
		return
	var rdef := rank_def(int(s.get("rank", 1)))
	ShipSkin.apply(model, rdef.get("skin", SKIN))   # lot 5 (6.2) : les couleurs disent le rang (voiles, coque, pavillon)
	_root.add_child(model)
	s["model"] = model
	s["cannons"] = ShipCannons.build(model)
	var crew := EnemyCrew.new()   # l'équipage de squelettes : timonier et canonniers qui rechargent
	crew.extra_gunners = int(rdef.get("crew", 0))   # lot 5 (6.2) : plus de canonniers aux rangs élevés
	var lt: Array = GameConfig.ENEMY_LOAD_TIME
	crew.load_time = float(lt[clampi(int(s.get("rank", 1)) - 1, 0, lt.size() - 1)])   # 13/11 : et ils chargent plus vite
	crew.build(model, s["cannons"], str(s["kind"]), _rng)
	s["crew"] = crew
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
		var crew = s.get("crew")
		if crew != null:
			(crew as EnemyCrew).step(delta, s["state"] != "sinking")
		_place_visual(s, delta)


func _host_step(delta: float, target: Dictionary) -> void:
	var tpos: Vector2 = target["pos"]
	# apparition et retrait
	if spawn_enabled and bool(target.get("alive", true)):
		_spawn_t -= delta
		if _spawn_t <= 0.0 and alive_count() < MAX_SHIPS:
			_spawn_t = _rng.randf_range(GameConfig.ENEMY_SPAWN_MIN, GameConfig.ENEMY_SPAWN_MAX)   # lot 5 (6.3) : plus rares
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
		# 13/11, abordage : sans timonier le bateau est désemparé (barre au centre, voiles carguées) ; son ancre jetée par un
		# joueur le retient ; les squelettes abattus reviennent
		var crew_b := s.get("crew") as EnemyCrew
		if crew_b != null:
			crew_b.step_respawn(delta)
			if crew_b.is_down(0):
				sim.rudder_target = 0.0
				sim.sail_level = 0
		s["anchor_t"] = maxf(float(s.get("anchor_t", 0.0)) - delta, 0.0)
		sim.anchored = float(s["anchor_t"]) > 0.0
		_survive(s, delta)
		s["reveal_t"] = maxf(float(s.get("reveal_t", 0.0)) - delta, 0.0)
		sim.sail_trim_target = sim.optimal_trim()
		var prev_pos := sim.position
		var prev_yaw := sim.yaw
		sim.step(delta)
		var model := s["model"] as ShipModel
		if model != null and blocker_cb.is_valid() and bool(blocker_cb.call(model, sim.position, sim.yaw)) \
				and not bool(blocker_cb.call(model, prev_pos, prev_yaw)):
			sim.position = prev_pos   # solide : il ne passe pas à travers le bateau des joueurs (s'ils se touchent déjà, il peut s'en dégager)
			sim.yaw = prev_yaw
			sim.speed *= 0.4
		_fire_queue(s, delta)


func _try_spawn(tpos: Vector2) -> void:
	for attempt in 14:
		var p := tpos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		if p.distance_to(spawn_origin) < PORT_SAFE:
			continue
		if water_free_cb.is_valid() and not bool(water_free_cb.call(p)):
			continue
		var rank := _roll_rank()   # lot 5 (6.2) : un rang au hasard, les plus hauts sont rares ; il fixe le bateau
		spawn(str(rank_def(rank)["kind"]), p, _rng.randf() * TAU, -1, rank)
		return


## Lot 5 (6.6) : l'équipage écope et répare. Un moment après le dernier coup reçu, une planche bouche une voie d'eau (des points
## de coque reviennent), tant qu'il en reste dans la cale (stock selon le rang). Chez tout le monde : la coque remonte (état reçu).
func _survive(s: Dictionary, delta: float) -> void:
	s["calm_t"] = float(s.get("calm_t", 0.0)) + delta
	if float(s["hp"]) >= float(s["hp_max"]) or int(s.get("planks", 0)) <= 0 or float(s["calm_t"]) < GameConfig.ENEMY_REPAIR_DELAY:
		return
	s["repair_t"] = float(s.get("repair_t", 0.0)) - delta
	if float(s["repair_t"]) > 0.0:
		return
	s["repair_t"] = GameConfig.ENEMY_REPAIR_EVERY
	s["planks"] = int(s["planks"]) - 1
	repairs.append((s["sim"] as ShipSim).position)   # (13/11 : le jeu fait entendre les coups de marteau)
	s["hp"] = minf(float(s["hp"]) + GameConfig.ENEMY_REPAIR_HP, float(s["hp_max"]))
	s["chips_hp"] = float(s["hp"])


func _ai(s: Dictionary, dt: float, target: Dictionary) -> void:
	var sim: ShipSim = s["sim"]
	var tpos: Vector2 = target["pos"]
	var to := tpos - sim.position
	var d := to.length()
	var bearing := atan2(-to.y, to.x)   # cap qui mène droit au bateau des joueurs (même convention que ShipSim.yaw)
	var desired := sim.yaw
	var alive := bool(target.get("alive", true))
	# 13/11 (Jimmy) : au port, un navire en patrouille n'engage pas les joueurs ; mais un navire qui les chassait déjà ne
	# lâche pas : se réfugier au port ne fait pas tomber un combat en cours
	var at_port := port_peace > 0.0 and tpos.distance_to(spawn_origin) < port_peace
	if s["state"] == "patrol":
		s["wp_t"] = float(s["wp_t"]) - dt
		if float(s["wp_t"]) <= 0.0 or sim.position.distance_to(s["wp"]) < 25.0:
			s["wp"] = (s["home"] as Vector2) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60.0, 220.0)
			s["wp_t"] = 30.0
		var wv: Vector2 = (s["wp"] as Vector2) - sim.position
		desired = atan2(-wv.y, wv.x)
		sim.sail_level = 2
		if alive and d < AGGRO and not at_port:
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
		var crew := s.get("crew") as EnemyCrew
		if crew != null:   # les canonniers rechargent d'abord le flanc tourné vers les joueurs
			crew.pref_side = 1 if absf(port_vec.angle_to(to)) < absf((-port_vec).angle_to(to)) else -1
		for si in 2:
			var side := 1.0 if si == 0 else -1.0
			var cd: Array = s["cd"]
			cd[si] = float(cd[si]) - dt
			var ang := absf((port_vec * side).angle_to(to))
			# pas de tir sans canon chargé : il faut que les squelettes aient fait leur travail
			var ready := crew == null or crew.loaded_on_side(int(side)) > 0
			if float(cd[si]) <= 0.0 and ang < FIRE_ARC and ready and (s["queue"] as Array).is_empty():
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
	var crew := s.get("crew") as EnemyCrew
	for i in model.cannons.size():
		if int((model.cannons[i] as Array)[2]) != side:
			continue
		if crew != null:
			if not crew.loaded[i]:
				continue   # canon vide : il ne tire pas
			crew.firing.append(i)
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
		var crew := s.get("crew") as EnemyCrew
		if crew != null:
			crew.fired(int(e[1]))   # le canon est vidé : un squelette devra le recharger
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
		# 13/11 : les équipages des rangs élevés visent mieux (dispersion -10 % par rang)
		var spread := (2.6 + 0.05 * dist) * (1.0 - GameConfig.ENEMY_AIM_PER_RANK * float(int(s.get("rank", 1)) - 1))
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
		if absf(bx) > model.length * 0.5 or absf(by) > model.half_width(bx) + 0.3:
			continue
		if loc.y < -2.2 or loc.y > model.deck_height(bx) + 1.6:
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
	s["calm_t"] = 0.0   # (l'équipage ne répare pas sous le feu)
	if float(s.get("reveal_t", 0.0)) > 0.0:
		s["reveal_t"] = GameConfig.ENEMY_REVEAL_TIME   # 6.7 : on échange des tirs, il reste sur la carte
	if s["state"] == "patrol":
		s["state"] = "chase"   # il se sait attaqué
	if float(s["hp"]) > 0.0:
		return false
	_start_sink(s)
	return true


## Hôte : un joueur monté à bord frappe le membre `idx` de l'équipage de l'ennemi `id` (0 : le timonier).
func crew_hit(id: int, idx: int, dmg: int) -> bool:
	var i := find(id)
	if i < 0 or (ships[i] as Dictionary).get("crew") == null:
		return false
	var s: Dictionary = ships[i]
	if s["state"] == "patrol":
		s["state"] = "chase"
	return (s["crew"] as EnemyCrew).hit(idx, dmg)


## Hôte : un joueur jette l'ancre de l'ennemi `id` : il reste sur place GameConfig.ENEMY_ANCHOR_TIME s.
func drop_anchor(id: int) -> void:
	var i := find(id)
	if i >= 0:
		(ships[i] as Dictionary)["anchor_t"] = GameConfig.ENEMY_ANCHOR_TIME


func _start_sink(s: Dictionary) -> void:
	s["state"] = "sinking"
	s["sink_t"] = 0.0
	var sim: ShipSim = s["sim"]
	sim.sail_level = 0
	s["queue"] = []
	# le butin s'échappe de la cale et flotte autour de l'épave (lot 5 : table de butin du rang, GameConfig.ENEMY_RANKS)
	if loot_cb.is_valid():
		var loot: Dictionary = rank_def(int(s.get("rank", 1)))["loot"]
		var drops: Array = []
		for k in _rng.randi_range(int(loot["treasures"][0]), int(loot["treasures"][1])):
			drops.append("t:" + Treasure.roll(_rng, float(loot["rarity"])))
		for k in _rng.randi_range(int(loot["planks"][0]), int(loot["planks"][1])):
			drops.append("plank")
		for k in _rng.randi_range(int(loot["balls"][0]), int(loot["balls"][1])):
			drops.append("ball")
		var gold := _rng.randi_range(int(loot["gold"][0]), int(loot["gold"][1]))
		for k in 2:   # en deux bourses
			drops.append("g:%d" % maxi(gold / 2, 1))
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
	# 13/11 : un bateau abîmé gîte et s'enfonce (à la place de la barre de vie)
	var hurt_k := smoothstep(0.5, 1.0, 1.0 - clampf(float(s["hp"]) / float(s["hp_max"]), 0.0, 1.0))
	y -= hurt_k * GameConfig.ENEMY_DAMAGE_SINK
	roll += hurt_k * GameConfig.ENEMY_DAMAGE_LIST * (1.0 if int(s["id"]) % 2 == 0 else -1.0)
	if s["state"] == "sinking":
		var k := clampf(float(s["sink_t"]) / SINK_TIME, 0.0, 1.0)
		y -= k * k * 5.0
		roll += k * 0.75
		pitch += k * 0.22
		model.set_sail_open(maxf(0.1, 1.0 - k * 1.4))
	else:
		model.set_sail_open(sim.sail_open)
	model.set_sail_trim(sim.sail_trim)
	# leurs voiles aussi se gonflent ou battent selon le vent (on voit s'ils sont bien réglés, donc s'ils vont vite)
	var pull := clampf(sim.wind_factor() * sim.trim_efficiency(), 0.0, 1.0)
	model.set_sail_wind(pull * smoothstep(0.05, 0.4, sim.sail_open),
			sim.sail_open * clampf((GameConfig.SAIL_LUFF_AT - pull) / GameConfig.SAIL_LUFF_AT, 0.0, 1.0), 1.0 / 60.0)
	model.position = Vector3(sim.position.x, y, sim.position.y)
	model.rotation = Vector3(roll, sim.yaw, pitch)
	var label := s["label"] as Label3D
	if label != null:
		# 13/11 : plus de barre de vie (le nom et le rang restent) ; l'état de la coque se lit sur le bateau (_update_damage)
		label.text = label_name(s)
		label.visible = s["state"] != "sinking"
	_update_damage(s, model)
	# des éclats quand la coque encaisse (chez tout le monde : la vie baisse dans l'état reçu)
	if float(s["hp"]) < float(s["chips_hp"]) - 0.5:
		s["chips_hp"] = float(s["hp"])
		_chips(model)


## Les dégâts visibles (13/11, à la place de la barre de vie) : quatre paliers selon la coque qui reste.
##   75 % : premiers trous dans la coque et planches cassées ; 50 % : voiles déchirées et fumée ; 25 % : plus de trous, fumée
##   épaisse, le bateau gîte et s'enfonce (voir _place_visual). Mêmes dégâts chez tous les joueurs : ils sont tirés de
##   l'identifiant du bateau, et la coque restante est dans l'état diffusé par l'hôte. Réparé, le bateau perd ses dégâts.
func _update_damage(s: Dictionary, model: ShipModel) -> void:
	var frac := clampf(float(s["hp"]) / float(s["hp_max"]), 0.0, 1.0)
	var level := 0 if frac > 0.75 else (1 if frac > 0.5 else (2 if frac > 0.25 else 3))
	if level == int(s.get("dmg_level", 0)):
		return
	s["dmg_level"] = level
	for old: Node in (s.get("dmg_nodes", []) as Array):
		if is_instance_valid(old):
			old.queue_free()
	var nodes: Array = []
	s["dmg_nodes"] = nodes
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * int(s["id"]) + 13
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1C1726")
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("CF9C62")
	# trous dans la coque et planches arrachées, des deux bords
	for k in [0, 3, 5, 9][level]:
		var side := 1.0 if k % 2 == 0 else -1.0
		var bx := rng.randf_range(-model.length * 0.32, model.length * 0.3)
		var hw := model.half_width(bx)
		var at := model.to_local3(Vector2(bx, side * hw * 1.02), -rng.randf_range(0.5, 1.3))
		var hole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rng.randf_range(0.3, 0.5)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.12
		cm.radial_segments = 7
		hole.mesh = cm
		hole.material_override = dark
		hole.position = at
		hole.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(hole)
		nodes.append(hole)
		for j in 3:
			var plank := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(rng.randf_range(0.5, 0.9), 0.07, 0.16)
			plank.mesh = bm
			plank.material_override = wood
			plank.position = at + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.25, 0.3), -side * 0.12)
			plank.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.8, 0.8))
			model.add_child(plank)
			nodes.append(plank)
	if level < 2:
		return
	# voiles déchirées : des lambeaux sombres sur la toile (enfants de la voile : ils la suivent quand elle tourne ou se cargue)
	for e: Dictionary in model._sails:
		var mi := e["node"] as MeshInstance3D
		if mi == null or mi.mesh == null or String(mi.name).contains("patch"):
			continue
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		for j in (2 if level == 2 else 4):
			var v: Vector3 = verts[rng.randi() % verts.size()]
			for off: float in [0.03, -0.03]:
				var rag := MeshInstance3D.new()
				var qm := QuadMesh.new()
				qm.size = Vector2(rng.randf_range(0.35, 0.7), rng.randf_range(0.5, 1.0))
				rag.mesh = qm
				rag.material_override = dark
				rag.position = v + Vector3(off, 0.0, 0.0)
				rag.rotation = Vector3(0.0, PI * 0.5, rng.randf_range(-0.5, 0.5))
				rag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.add_child(rag)
				nodes.append(rag)
	# fumée qui monte du pont
	var smoke := CPUParticles3D.new()
	smoke.amount = 14 if level == 2 else 30
	smoke.lifetime = 2.6
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 18.0
	smoke.initial_velocity_min = 1.2
	smoke.initial_velocity_max = 2.2
	smoke.gravity = Vector3(0.6, 0.4, 0.0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.5
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	sm.radial_segments = 8
	sm.rings = 4
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.16, 0.14, 0.18, 0.55)
	sm.material = smat
	smoke.mesh = sm
	smoke.position = model.to_local3(Vector2(rng.randf_range(-1.5, 2.5), 0.0), 0.6)
	model.add_child(smoke)
	nodes.append(smoke)


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
				{"patrol": 0, "chase": 1, "sinking": 2}[str(s["state"])], sim.speed, sim.sail_open, sim.sail_trim, sim.rudder,
				(s["crew"] as EnemyCrew).mask() if s.get("crew") != null else 0, int(s.get("rank", 1)),
				1 if float(s.get("reveal_t", 0.0)) > 0.0 else 0,
				(s["crew"] as EnemyCrew).dead_mask() if s.get("crew") != null else 0, 1 if float(s.get("anchor_t", 0.0)) > 0.0 else 0])
	return out


func apply_net(state: Array) -> void:
	var seen := {}
	for e: Array in state:
		var id := int(e[0])
		seen[id] = true
		var i := find(id)
		var kind: String = KINDS[clampi(int(e[1]), 0, KINDS.size() - 1)]
		if i < 0:
			spawn(kind, Vector2(float(e[2]), float(e[3])), float(e[4]), id, int(e[12]) if e.size() > 12 else 0)
			i = find(id)
		var s: Dictionary = ships[i]
		if e.size() > 13:
			s["reveal_t"] = GameConfig.ENEMY_REVEAL_TIME if int(e[13]) == 1 else 0.0
		if float(e[5]) > float(s["hp"]) + 0.5:
			s["chips_hp"] = float(e[5])   # (réparé chez l'hôte : pas d'éclats)
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
		if e.size() > 11 and s.get("crew") != null:
			(s["crew"] as EnemyCrew).apply_mask(int(e[11]))   # les canons chargés, comme l'hôte les voit
		if e.size() > 15 and s.get("crew") != null:
			(s["crew"] as EnemyCrew).apply_dead_mask(int(e[14]))
			sim.anchored = int(e[15]) == 1
	for i in range(ships.size() - 1, -1, -1):
		var s2: Dictionary = ships[i]
		if not seen.has(int(s2["id"])) and s2["state"] != "sinking":
			_remove(i)
