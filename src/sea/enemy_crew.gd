class_name EnemyCrew
extends RefCounted
## L'équipage squelette d'un bateau ennemi : un timonier à la barre et des canonniers qui font comme les joueurs.
## Un canon ne tire que s'il est chargé ; pour le recharger, un canonnier va prendre un boulet au tonneau, le porte
## jusqu'au canon, puis le charge (comme le pirate : E au tonneau, E au canon). Pas de canonnier libre, pas de tir :
## la cadence dépend du nombre de squelettes encore debout.
## Rien ici ne touche à la scène du jeu hors du modèle du bateau : les squelettes en sont des enfants.
## Même code chez l'hôte et chez les clients (pour que tout le monde voie les mêmes allées et venues) ; seul l'hôte
## décide si un canon est chargé, les clients reçoivent le masque (voir `apply_mask`).

const GUNNERS := {"sloop": 2, "brigantin": 3, "galion": 4}
const WALK_SPEED := 2.4        ## m/s
const GRAB_TIME := 0.5         ## s : prendre un boulet au tonneau
const LOAD_TIME := 0.9         ## s : bourrer le canon
const START_LOADED := 0.75     ## part des canons chargés au départ (les premières salves sont prêtes)
const STUCK_SECS := 1.4        ## s : coincé derrière un obstacle, le squelette se recale sur sa cible
const HOLD_SECS := 2.0         ## s : chez un client, un canon qu'un squelette vient de charger ne se vide pas aussitôt

var model: ShipModel
var cannon_nodes: Array = []             ## [{root, barrel}] (voir ShipCannons)
var loaded: Array = []                   ## par canon : chargé ?
var pref_side := 0                       ## flanc à recharger en premier (celui qui fait face aux joueurs), 0 = indifférent
var firing: Array = []                   ## indices des canons dont le tir est en file : on ne les recharge pas
var gunners: Array = []                  ## {enemy, bp, state, cannon, t, carry, stuck, last}
var helmsman: IslandEnemy
var _icons: Array = []                   ## la boule orange au-dessus d'un canon chargé
var _hold: Array = []                    ## minuteur de confirmation chez un client, par canon
var _ammo_spot := Vector2.ZERO
var _helm_bp := Vector2.ZERO
var _spots: Array = []                   ## par canon : où se tient le canonnier (repère du modèle)
var _faces: Array = []                   ## par canon : direction du regard du canonnier (repère de la scène : x, z)
var _time := 0.0
var _cfg: Dictionary = {}
var extra_gunners := 0                   ## lot 5 (6.2) : canonniers en plus selon le rang du bateau (avant build)
var load_time := LOAD_TIME               ## s pour bourrer un canon (13/11 : plus court aux rangs élevés, GameConfig.ENEMY_LOAD_TIME)


## Monte l'équipage sur `p_model`. `rng` : pour qui est chargé au départ.
func build(p_model: ShipModel, p_cannons: Array, kind: String, rng: RandomNumberGenerator) -> void:
	model = p_model
	cannon_nodes = p_cannons
	var base: Dictionary = (IslandWorld.read_json("res://data/enemies.json").get("kinds", {}) as Dictionary).get("skeleton", {})
	_cfg = base.duplicate()
	_cfg["windup"] = load_time
	_cfg["cooldown"] = 0.5
	var ammo: Array = model.meta.get("ammo", [0.0, 0.0])
	_ammo_spot = model.nearest_walkable(Vector2(float(ammo[0]), float(ammo[1])) + Vector2(0.0, -0.55 * signf(float(ammo[1]))))
	for i in model.cannons.size():
		var c: Array = model.cannons[i]
		var side := float(c[2])
		_spots.append(model.nearest_walkable(Vector2(float(c[0]), float(c[1]) - side * 0.75)))
		_faces.append(Vector2(0.0, -side))
		loaded.append(rng.randf() < START_LOADED)
		_hold.append(0.0)
		var icon := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.17
		sm.height = 0.34
		icon.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.55, 0.15)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		icon.material_override = m
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		icon.position = (cannon_nodes[i]["root"] as Node3D).position + Vector3(0.0, 1.35, 0.0)
		icon.visible = loaded[i]
		model.add_child(icon)
		_icons.append(icon)
	# le timonier, à la barre
	var helm: Array = model.meta.get("helm", [0.0, 0.0])
	_helm_bp = model.nearest_walkable(Vector2(float(helm[0]) - 0.55, float(helm[1])))
	helmsman = _make_skeleton(1, _helm_bp, Vector2(1.0, 0.0))
	# les canonniers partent du coffre à boulets
	var count := mini(int(GUNNERS.get(kind, 3)) + extra_gunners, model.cannons.size())   # lot 5 (6.2) : plus nombreux aux rangs élevés
	for k in count:
		var bp := model.nearest_walkable(_ammo_spot + Vector2(-0.3 * k, 0.25 * (k % 2) - 0.1))
		var g := {"enemy": _make_skeleton(10 + k, bp, Vector2(1.0, 0.0)), "bp": bp, "state": "idle", "cannon": -1,
				"t": 0.0, "carry": null, "stuck": 0.0, "last": bp, "wait": 0.4 * k}
		g["carry"] = _make_carried_ball(g["enemy"])
		gunners.append(g)


func _make_skeleton(id: int, bp: Vector2, face: Vector2) -> IslandEnemy:
	var e := IslandEnemy.create(id, "skeleton", 0, Vector2.ZERO, _cfg.duplicate())
	e.build_model(model)
	_place(e, bp, face)
	return e


## Le boulet que le canonnier tient dans la main gauche.
func _make_carried_ball(e: IslandEnemy) -> MeshInstance3D:
	var arm: Node3D = e._parts["arm_-1"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.12)
	var ball := ProcKit.ball(arm, 0.14, Vector3(0.0, -0.62, 0.1), mat)
	ball.visible = false
	return ball


func _place(e: IslandEnemy, bp: Vector2, face: Vector2) -> void:
	var p := model.to_local3(bp)
	e.pos = Vector2(p.x, p.z)
	e.ground_y = p.y
	e.facing = face
	e._last_pos = e.pos


## Bitmask des canons chargés (pour le réseau).
func mask() -> int:
	var m := 0
	for i in loaded.size():
		if loaded[i]:
			m |= 1 << i
	return m


## Client : reprend le masque de l'hôte. Un canon qu'un squelette vient de charger ici ne se vide pas avant confirmation.
func apply_mask(m: int) -> void:
	for i in loaded.size():
		var on := ((m >> i) & 1) == 1
		if on or float(_hold[i]) <= 0.0:
			loaded[i] = on


## Hôte : le canon `i` part ; plus chargé.
func fired(i: int) -> void:
	if i >= 0 and i < loaded.size():
		loaded[i] = false
	firing.erase(i)


func loaded_on_side(side: int) -> int:
	var n := 0
	for i in loaded.size():
		if loaded[i] and int((model.cannons[i] as Array)[2]) == side and not firing.has(i):
			n += 1
	return n


## Chaque image. `active` : faux quand le bateau coule (plus de rechargement).
func step(delta: float, active: bool) -> void:
	if model == null:
		return
	_time += delta
	for i in loaded.size():
		_hold[i] = maxf(float(_hold[i]) - delta, 0.0)
		_icons[i].visible = loaded[i]
	if active:
		for g: Dictionary in gunners:
			_step_gunner(g, delta)
	_update_visuals(delta)


func _step_gunner(g: Dictionary, dt: float) -> void:
	match g["state"]:
		"idle":
			g["wait"] = float(g["wait"]) - dt
			if float(g["wait"]) > 0.0:
				return
			var idx := _pick_cannon(g)
			if idx >= 0:
				g["cannon"] = idx
				g["state"] = "to_ammo"
		"to_ammo":
			if _walk(g, _ammo_spot, dt):
				g["state"] = "grab"
				g["t"] = GRAB_TIME
		"grab":
			g["t"] = float(g["t"]) - dt
			if float(g["t"]) <= 0.0:
				(g["carry"] as MeshInstance3D).visible = true
				var idx := int(g["cannon"])
				if loaded[idx]:   # un autre l'a chargé entre-temps : on en cherche un autre
					g["cannon"] = _pick_cannon(g)
					idx = int(g["cannon"])
				g["state"] = "to_cannon" if idx >= 0 else "idle"
		"to_cannon":
			var idx2 := int(g["cannon"])
			if _walk(g, _spots[idx2], dt):
				g["state"] = "loading"
				g["t"] = load_time
		"loading":
			g["t"] = float(g["t"]) - dt
			(g["enemy"] as IslandEnemy).facing = (_faces[int(g["cannon"])] as Vector2)
			if float(g["t"]) <= 0.0:
				var idx3 := int(g["cannon"])
				loaded[idx3] = true
				_hold[idx3] = HOLD_SECS
				(g["carry"] as MeshInstance3D).visible = false
				g["cannon"] = -1
				g["state"] = "idle"
				g["wait"] = 0.3


## Le canon vide le plus utile : pas déjà pris par un autre, pas en train de tirer ; le flanc tourné vers les joueurs d'abord.
func _pick_cannon(g: Dictionary) -> int:
	var best := -1
	var best_cost := INF
	var from: Vector2 = g["bp"]
	for i in loaded.size():
		if loaded[i] or firing.has(i) or _claimed_by_other(i, g):
			continue
		var cost := from.distance_to(_spots[i]) + _ammo_spot.distance_to(_spots[i])
		if pref_side != 0 and int((model.cannons[i] as Array)[2]) != pref_side:
			cost += 6.0
		if cost < best_cost:
			best_cost = cost
			best = i
	return best


func _claimed_by_other(i: int, me: Dictionary) -> bool:
	for g: Dictionary in gunners:
		if g != me and int(g["cannon"]) == i:
			return true
	return false


## Avance le canonnier vers `goal` (repère du modèle) ; vrai quand il y est.
func _walk(g: Dictionary, goal: Vector2, dt: float) -> bool:
	var bp: Vector2 = g["bp"]
	var to := goal - bp
	var e := g["enemy"] as IslandEnemy
	if to.length() < 0.12:
		return true
	var step := minf(WALK_SPEED / ShipModel.SCALE * dt, to.length())
	var moved := model.move_with_slide(bp, to.normalized() * step)
	if moved.distance_to(bp) < step * 0.25:
		g["stuck"] = float(g["stuck"]) + dt
		if float(g["stuck"]) > STUCK_SECS:   # coincé derrière un mât ou un baril : on se recale sur la cible
			moved = model.nearest_walkable(goal)
			g["stuck"] = 0.0
	else:
		g["stuck"] = 0.0
	g["bp"] = moved
	var d := moved - bp
	if d.length() > 0.0001:
		e.facing = Vector2(d.x, -d.y).normalized()   # repère de la scène : x, z
	return false


func _update_visuals(delta: float) -> void:
	var set_pos := func(e: IslandEnemy, bp: Vector2) -> void:
		var p := model.to_local3(bp)
		e.pos = Vector2(p.x, p.z)
		e.ground_y = p.y
	set_pos.call(helmsman, _helm_bp)
	helmsman.update_visual(delta, _time, true)
	for g: Dictionary in gunners:
		var e := g["enemy"] as IslandEnemy
		set_pos.call(e, g["bp"])
		# prendre le boulet et le bourrer : le même bras levé que pour le coup de sabre
		if g["state"] == "grab" or g["state"] == "loading":
			e.state = IslandEnemy.State.WINDUP
			var total := GRAB_TIME if g["state"] == "grab" else load_time
			e.cfg["windup"] = total
			e.timer = maxf(float(g["t"]), 0.0)
		else:
			e.state = IslandEnemy.State.IDLE
		e.update_visual(delta, _time, true)
