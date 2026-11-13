class_name IslandEnemy
extends RefCounted
## Un ennemi d'île (crabe, squelette, soldat de la Marine, officier, capitaine). La logique tourne chez l'hôte
## (ou en solo) : il rôde près de son point d'attache, poursuit un joueur qui s'approche, arme un coup (le
## joueur peut reculer), frappe, récupère. Les autres joueurs reçoivent seulement l'état (position, vie, phase)
## et jouent l'animation. Réglages dans data/enemies.json.

enum State { IDLE, CHASE, WINDUP, RECOVER, DEAD, HEAL }

var id := 0
var kind := ""
var island := 0
var cfg: Dictionary = {}
var home := Vector2.ZERO
var pos := Vector2.ZERO
var facing := Vector2(0, 1)
var hp := 1
var max_hp := 1
var state := State.IDLE
var timer := 0.0              ## durée restante de la phase (armement, récupération) ou de la mort
var hurt_t := 0.0             ## flash teinté après un coup reçu (GameConfig.HIT_FLASH_TIME)
var knock := Vector2.ZERO     ## vitesse de recul
var wander_t := 0.0
var wander_to := Vector2.ZERO
var target_id := 0
var node: Node3D
var ground_y := 0.0           ## hauteur du sol sous l'ennemi (plateau, rampe)
var remote_target := Vector2.ZERO   ## chez un client : où l'hôte dit qu'il est
var _parts: Dictionary = {}
var _meshes: Array[MeshInstance3D] = []
var _bar_back: MeshInstance3D
var _bar_fill: MeshInstance3D
var _walk_phase := 0.0
var _last_pos := Vector2.ZERO
var _moving := 0.0
var _death_t := 0.0
var _flash: StandardMaterial3D
var _flash_on := false
var slow_t := 0.0             ## lot 5 (6.8) : s de ralentissement restantes (touché par un boulet)
var food := GameConfig.MOB_FOOD   ## lot 5 (6.9) : rations qui lui restent
var _shown_hp := -1           ## (chez tous : les PV remontent = il vient de manger)


static func create(p_id: int, p_kind: String, p_island: int, p_home: Vector2, p_cfg: Dictionary) -> IslandEnemy:
	var e := IslandEnemy.new()
	e.id = p_id
	e.kind = p_kind
	e.island = p_island
	e.cfg = p_cfg
	e.home = p_home
	e.pos = p_home
	e.remote_target = p_home
	e.max_hp = int(p_cfg["hp"])
	e.hp = e.max_hp
	e.wander_to = p_home
	e._last_pos = p_home
	return e


func is_dead() -> bool:
	return state == State.DEAD


# ------------------------------------------------------------------ logique (hôte ou solo)

## Fait avancer l'ennemi. `targets` : [{id, pos}] des joueurs à terre sur l'île. `world` donne les collisions.
## Renvoie les coups portés : [{enemy, target, damage, from}].
func step(delta: float, targets: Array, world: IslandWorld, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	hurt_t = maxf(hurt_t - delta, 0.0)
	slow_t = maxf(slow_t - delta, 0.0)
	if state == State.DEAD:
		timer -= delta
		return out
	# lot 5 (6.9) : blessé, à l'écart des joueurs, il mange une ration pour se soigner (ça prend du temps)
	if state == State.HEAL:
		timer -= delta
		if timer <= 0.0:
			hp = mini(hp + maxi(int(round(max_hp * GameConfig.MOB_HEAL_FRAC)), 1), max_hp)
			food -= 1
			state = State.IDLE
		return out
	var near := _nearest(targets)
	var safe := near.is_empty() or pos.distance_to(near["pos"]) > GameConfig.MOB_HEAL_SAFE
	if food > 0 and safe and hp < max_hp * GameConfig.MOB_HEAL_BELOW and (state == State.IDLE or state == State.CHASE):
		state = State.HEAL
		timer = GameConfig.MOB_HEAL_TIME
		return out
	if knock.length() > 0.05:
		_move(knock * delta, world)
		knock = knock.move_toward(Vector2.ZERO, 9.0 * delta)
	var tgt := _nearest(targets)
	match state:
		State.IDLE:
			if not tgt.is_empty() and pos.distance_to(tgt["pos"]) <= float(cfg["aggro"]):
				state = State.CHASE
				target_id = int(tgt["id"])
			else:
				_wander(delta, world, rng)
		State.CHASE:
			var cur := _by_id(targets, target_id)
			if cur.is_empty():
				cur = tgt
			if cur.is_empty() or home.distance_to(cur["pos"]) > float(cfg["leash"]) or pos.distance_to(home) > float(cfg["leash"]) * 1.2:
				state = State.IDLE
				wander_to = home
				return out
			target_id = int(cur["id"])
			var to: Vector2 = (cur["pos"] as Vector2) - pos
			var dist := to.length()
			if dist > 0.001:
				facing = to / dist
			if dist <= float(cfg["reach"]) * 0.85:
				state = State.WINDUP
				timer = float(cfg["windup"])
			else:
				_move(facing * float(cfg["speed"]) * delta, world)
		State.WINDUP:
			timer -= delta
			if timer <= 0.0:
				for t: Dictionary in targets:
					var d: Vector2 = (t["pos"] as Vector2) - pos
					if d.length() <= float(cfg["reach"]) + 0.45 and (d.length() < 0.3 or d.normalized().dot(facing) > 0.2):
						out.append({"enemy": id, "target": int(t["id"]), "damage": int(cfg["damage"]), "from": pos})
				state = State.RECOVER
				timer = float(cfg["cooldown"])
		State.RECOVER:
			timer -= delta
			if timer <= 0.0:
				state = State.CHASE if not tgt.is_empty() else State.IDLE
	return out


func _nearest(targets: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for t: Dictionary in targets:
		var d := pos.distance_to(t["pos"])
		if d < best_d:
			best_d = d
			best = t
	return best


func _by_id(targets: Array, tid: int) -> Dictionary:
	for t: Dictionary in targets:
		if int(t["id"]) == tid:
			return t
	return {}


func _wander(delta: float, world: IslandWorld, rng: RandomNumberGenerator) -> void:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = rng.randf_range(1.5, 4.0)
		wander_to = home + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 2.5) if rng.randf() < 0.6 else pos
	var d := wander_to - pos
	if d.length() > 0.15:
		facing = d.normalized()
		_move(facing * float(cfg["speed"]) * 0.35 * delta, world)


func _move(delta_pos: Vector2, world: IslandWorld) -> void:
	if slow_t > 0.0:
		delta_pos *= GameConfig.MOB_SLOW_FACTOR   # lot 5 (6.8) : sonné par un boulet
	var r := 0.35 * float(cfg["scale"])
	var t := pos + delta_pos
	if absf(world.height(island, t) - world.height(island, pos)) > 0.3:
		return   # une falaise : on ne la monte pas
	if world.walkable(island, t, r):
		pos = t
	elif world.walkable(island, Vector2(t.x, pos.y), r):
		pos = Vector2(t.x, pos.y)
	elif world.walkable(island, Vector2(pos.x, t.y), r):
		pos = Vector2(pos.x, t.y)


## Reçoit un coup de `dmg` venant de `from`. Renvoie vrai s'il en meurt.
func hurt(dmg: int, from: Vector2, power: float, ranged: bool = false) -> bool:
	if state == State.DEAD:
		return false
	hp -= dmg
	hurt_t = GameConfig.HIT_FLASH_TIME
	var away := pos - from
	if away.length() > 0.01:
		knock = away.normalized() * power * float(cfg.get("knockback", 2.0))
	if hp <= 0:
		hp = 0
		state = State.DEAD
		timer = 0.0
		return true
	if state == State.IDLE or state == State.HEAL:
		state = State.CHASE   # (un coup interrompt son repas)
	elif state == State.WINDUP and not ranged:   # (13/11 : une balle ne casse plus son élan : il ne se fige plus sous le feu)
		# un coup reçu en armant le sien le casse parfois : l'ennemi doit reprendre son élan
		timer = float(cfg["windup"]) * 0.6
	return false


## Remet l'ennemi à son point d'attache, en pleine forme.
func revive() -> void:
	hp = max_hp
	state = State.IDLE
	pos = home
	remote_target = home
	knock = Vector2.ZERO
	_death_t = 0.0
	hurt_t = 0.0
	timer = 0.0
	food = GameConfig.MOB_FOOD
	slow_t = 0.0


# ------------------------------------------------------------------ réseau

func net_state() -> Array:
	return [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), hp, int(state), snappedf(atan2(facing.x, facing.y), 0.01)]


func apply_net(s: Array, snap: bool) -> void:
	remote_target = Vector2(float(s[0]), float(s[1]))
	var new_hp := int(s[2])
	if new_hp < hp:
		hurt_t = GameConfig.HIT_FLASH_TIME
	hp = new_hp
	var st := int(s[3])
	if st == State.DEAD and state != State.DEAD:
		_death_t = 0.0
	if st != State.DEAD and state == State.DEAD:
		_death_t = 0.0
	if st != int(state):
		if st == State.WINDUP:
			timer = float(cfg["windup"])
		elif st == State.RECOVER:
			timer = float(cfg["cooldown"])
	state = st as State
	var a := float(s[4])
	facing = Vector2(sin(a), cos(a))
	if snap or pos.distance_to(remote_target) > 6.0:
		pos = remote_target


# ------------------------------------------------------------------ modèle 3D et animation

func build_model(parent: Node3D) -> void:
	node = Node3D.new()
	parent.add_child(node)
	var s := float(cfg["scale"])
	match kind:
		"crab":
			_build_crab()
		_:
			_build_humanoid()
	node.scale = Vector3.ONE * s
	_collect_meshes(node)
	# barre de vie, au-dessus de la tête (face à la caméra)
	var top := 0.95 if kind == "crab" else 2.15
	_bar_back = _bar(Color(0.08, 0.04, 0.06), Vector2(0.9, 0.12), Vector3(0, top, 0), 0)
	_bar_fill = _bar(Color(0.86, 0.16, 0.14), Vector2(0.84, 0.08), Vector3(0, top, 0), 1)
	_bar_back.visible = false
	_bar_fill.visible = false


func _bar(color: Color, size: Vector2, p: Vector3, prio: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true   # (13/11 : sans ça, l'échelle du rectangle est ignorée : la barre restait toujours pleine)
	m.albedo_color = color
	m.no_depth_test = true
	m.render_priority = 10 + prio
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p
	node.add_child(mi)
	return mi


func _collect_meshes(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and not (c == _bar_back or c == _bar_fill):
			_meshes.append(c)
		_collect_meshes(c)


func _mat(c: Color) -> StandardMaterial3D:
	return ProcKit.flat(c)


func _pivot(parent: Node3D, p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	parent.add_child(n)
	return n


func _build_crab() -> void:
	var shell := _mat(Color(0.82, 0.30, 0.18))
	var shell_d := _mat(Color(0.62, 0.20, 0.13))
	var dark := _mat(Color(0.10, 0.07, 0.07))
	var white := _mat(Color(0.96, 0.94, 0.88))
	var body := ProcKit.ball(node, 0.5, Vector3(0, 0.32, 0), shell)
	body.scale = Vector3(1.0, 0.55, 0.78)
	var back := ProcKit.ball(node, 0.34, Vector3(0, 0.46, -0.05), shell_d)
	back.scale = Vector3(1.0, 0.5, 0.8)
	for sx in [-1.0, 1.0]:
		# yeux sur tiges
		ProcKit.cyl(node, 0.025, 0.2, Vector3(sx * 0.17, 0.62, 0.3), dark)
		var eye := ProcKit.ball(node, 0.07, Vector3(sx * 0.17, 0.74, 0.32), white)
		eye.scale = Vector3.ONE
		ProcKit.ball(node, 0.035, Vector3(sx * 0.17, 0.75, 0.38), dark)
		# pinces : bras + pince (deux mâchoires)
		var arm := _pivot(node, Vector3(sx * 0.46, 0.38, 0.22))
		_parts["claw_%d" % int(sx)] = arm
		ProcKit.box(arm, Vector3(0.1, 0.1, 0.38), Vector3(0, 0, 0.19), shell_d)
		var hand := ProcKit.ball(arm, 0.2, Vector3(0, 0, 0.45), shell)
		hand.scale = Vector3(1.0, 0.7, 1.0)
		ProcKit.box(arm, Vector3(0.06, 0.1, 0.24), Vector3(-0.07, 0, 0.66), shell_d)
		ProcKit.box(arm, Vector3(0.06, 0.1, 0.24), Vector3(0.07, 0, 0.66), shell_d)
		# pattes
		for k in 3:
			var leg := _pivot(node, Vector3(sx * 0.4, 0.28, -0.18 + k * 0.17))
			_parts["leg_%d_%d" % [int(sx), k]] = leg
			var seg := ProcKit.box(leg, Vector3(0.36, 0.05, 0.05), Vector3(sx * 0.18, -0.05, 0), shell_d, Vector3(0, 0, sx * -0.4))
			seg.rotation.z = sx * -0.45


func _build_humanoid() -> void:
	var skin: Color
	var coat: Color
	var trousers: Color
	var hat_c: Color
	var bone := kind == "skeleton" or kind == "captain"
	match kind:
		"skeleton":
			skin = Color(0.88, 0.85, 0.74)
			coat = Color(0.45, 0.20, 0.16)
			trousers = Color(0.30, 0.24, 0.22)
			hat_c = Color(0.18, 0.15, 0.17)
		"captain":
			skin = Color(0.84, 0.88, 0.78)
			coat = Color(0.62, 0.14, 0.10)
			trousers = Color(0.22, 0.14, 0.12)
			hat_c = Color(0.12, 0.10, 0.12)
		"officer":
			skin = Color(0.86, 0.66, 0.5)
			coat = Color(0.10, 0.18, 0.42)
			trousers = Color(0.90, 0.88, 0.82)
			hat_c = Color(0.95, 0.93, 0.88)
		_:   # marine
			skin = Color(0.84, 0.64, 0.48)
			coat = Color(0.20, 0.34, 0.62)
			trousers = Color(0.92, 0.91, 0.86)
			hat_c = Color(0.96, 0.95, 0.9)
	var m_skin := _mat(skin)
	var m_coat := _mat(coat)
	var m_trou := _mat(trousers)
	var m_hat := _mat(hat_c)
	var m_dark := _mat(Color(0.10, 0.08, 0.09))
	var m_gold := _mat(Color(0.92, 0.74, 0.25))
	var m_steel := _mat(Color(0.78, 0.80, 0.86))
	# jambes
	for sx in [-1.0, 1.0]:
		var leg := _pivot(node, Vector3(sx * 0.13, 0.78, 0))
		_parts["leg_%d" % int(sx)] = leg
		ProcKit.box(leg, Vector3(0.15, 0.78, 0.16), Vector3(0, -0.39, 0), m_trou)
		ProcKit.box(leg, Vector3(0.17, 0.1, 0.26), Vector3(0, -0.74, 0.04), m_dark)
	# buste
	var torso := _pivot(node, Vector3(0, 0.78, 0))
	_parts["torso"] = torso
	ProcKit.box(torso, Vector3(0.52, 0.62, 0.3), Vector3(0, 0.31, 0), m_coat)
	ProcKit.box(torso, Vector3(0.54, 0.08, 0.32), Vector3(0, 0.02, 0), m_dark)   # ceinture
	if kind == "officer" or kind == "marine":
		ProcKit.box(torso, Vector3(0.06, 0.6, 0.02), Vector3(0, 0.31, 0.155), m_gold)   # boutons
	if kind == "officer" or kind == "captain":
		for sx in [-1.0, 1.0]:
			ProcKit.box(torso, Vector3(0.2, 0.05, 0.22), Vector3(sx * 0.3, 0.63, 0), m_gold)   # épaulettes
	if bone:
		# côtes visibles sous le manteau ouvert
		for k in 3:
			ProcKit.box(torso, Vector3(0.3, 0.035, 0.02), Vector3(0, 0.22 + k * 0.1, 0.16), _mat(Color(0.92, 0.9, 0.8)))
	# tête
	var head := _pivot(torso, Vector3(0, 0.78, 0))
	_parts["head"] = head
	ProcKit.ball(head, 0.19, Vector3.ZERO, m_skin)
	if bone:
		var glow := ProcKit.glow(Color(0.5, 1.0, 0.6) if kind == "captain" else Color(0.08, 0.06, 0.08))
		for sx in [-1.0, 1.0]:
			ProcKit.ball(head, 0.045, Vector3(sx * 0.075, 0.03, 0.16), glow)
		ProcKit.box(head, Vector3(0.14, 0.05, 0.04), Vector3(0, -0.1, 0.16), _mat(Color(0.95, 0.93, 0.85)))   # dents
	else:
		for sx in [-1.0, 1.0]:
			ProcKit.ball(head, 0.025, Vector3(sx * 0.075, 0.03, 0.17), m_dark)
	# chapeau : tricorne (pirates) ou bicorne blanc / casquette (Marine)
	if kind == "marine":
		ProcKit.cyl(head, 0.2, 0.1, Vector3(0, 0.17, 0), m_hat)
		ProcKit.box(head, Vector3(0.36, 0.03, 0.14), Vector3(0, 0.12, 0.2), m_dark)
	elif kind == "officer":
		ProcKit.box(head, Vector3(0.62, 0.14, 0.22), Vector3(0, 0.2, 0), m_hat)
		ProcKit.box(head, Vector3(0.1, 0.14, 0.24), Vector3(0, 0.2, 0), m_gold)
	else:
		ProcKit.cyl(head, 0.3, 0.05, Vector3(0, 0.15, 0), m_hat)
		ProcKit.cyl(head, 0.2, 0.17, Vector3(0, 0.25, 0), m_hat)
		if kind == "captain":
			ProcKit.box(head, Vector3(0.1, 0.3, 0.03), Vector3(0.12, 0.44, 0), _mat(Color(0.9, 0.2, 0.15)))   # plume
	# bras : le gauche balance, le droit tient l'arme
	var arm_l := _pivot(torso, Vector3(-0.34, 0.56, 0))
	_parts["arm_-1"] = arm_l
	ProcKit.box(arm_l, Vector3(0.13, 0.52, 0.14), Vector3(0, -0.26, 0), m_coat)
	ProcKit.ball(arm_l, 0.07, Vector3(0, -0.55, 0), m_skin)
	var arm_r := _pivot(torso, Vector3(0.34, 0.56, 0))
	_parts["arm_1"] = arm_r
	ProcKit.box(arm_r, Vector3(0.13, 0.52, 0.14), Vector3(0, -0.26, 0), m_coat)
	ProcKit.ball(arm_r, 0.07, Vector3(0, -0.55, 0), m_skin)
	# sabre : lame pointée devant, tenue à la main
	var blade := _pivot(arm_r, Vector3(0, -0.55, 0))
	_parts["blade"] = blade
	ProcKit.box(blade, Vector3(0.05, 0.05, 0.14), Vector3(0, 0, 0), m_dark)
	ProcKit.box(blade, Vector3(0.17, 0.04, 0.04), Vector3(0, 0, 0.09), m_gold)
	var length := 1.1 if kind == "captain" else 0.8
	ProcKit.box(blade, Vector3(0.04, 0.03, length), Vector3(0, 0, 0.1 + length * 0.5), m_steel)
	blade.rotation.x = deg_to_rad(-40.0)
	if kind == "marine" or kind == "officer":
		pass


## Anime et place le modèle (chez tout le monde). `origin` : monde x/z -> scène, déjà géré par le parent.
func update_visual(delta: float, time: float, authority: bool) -> void:
	if node == null:
		return
	if not authority:
		pos = pos.lerp(remote_target, 1.0 - exp(-delta * 12.0))
		if state == State.WINDUP or state == State.RECOVER:
			timer -= delta
	var moved := pos.distance_to(_last_pos)
	_last_pos = pos
	var speed := moved / maxf(delta, 0.0001)
	_moving = lerpf(_moving, clampf(speed / 2.0, 0.0, 1.0), 1.0 - exp(-delta * 10.0))
	if state == State.DEAD:
		_death_t += delta
		var k := clampf(_death_t / 0.5, 0.0, 1.0)
		node.visible = _death_t < 1.4
		node.position = Vector3(pos.x, ground_y, pos.y)
		node.rotation = Vector3(deg_to_rad(-90.0) * k if kind != "crab" else 0.0, atan2(facing.x, facing.y), deg_to_rad(180.0) * k if kind == "crab" else 0.0)
		var s := float(cfg["scale"])
		node.scale = Vector3.ONE * s * (1.0 - clampf((_death_t - 0.9) / 0.5, 0.0, 1.0))
		_bar_back.visible = false
		_bar_fill.visible = false
		return
	node.visible = true
	var sc := float(cfg["scale"])
	node.scale = Vector3.ONE * sc
	_walk_phase += delta * (4.0 + speed * 3.2)
	var swing := sin(_walk_phase) * _moving
	var bob := absf(sin(_walk_phase)) * 0.05 * _moving
	node.position = Vector3(pos.x, ground_y + bob, pos.y)
	node.rotation = Vector3(0.0, atan2(facing.x, facing.y), 0.0)
	var windup_k := 0.0
	var strike_k := 0.0
	if state == State.WINDUP:
		windup_k = 1.0 - clampf(_remaining_windup() / maxf(float(cfg["windup"]), 0.01), 0.0, 1.0)
	elif state == State.RECOVER:
		var total := float(cfg["cooldown"])
		var since := total - timer
		strike_k = clampf(1.0 - since / 0.25, 0.0, 1.0) if since >= 0.0 else 0.0
	if kind == "crab":
		for sx in [-1, 1]:
			var claw: Node3D = _parts["claw_%d" % sx]
			var up := -0.9 * windup_k + 0.7 * strike_k
			claw.rotation = Vector3(up, sx * (0.25 + 0.2 * sin(time * 2.0 + id)), 0.0)
			for k in 3:
				var leg: Node3D = _parts["leg_%d_%d" % [sx, k]]
				leg.rotation.y = sin(_walk_phase * 1.6 + k * 1.3 + (0.0 if sx > 0 else PI)) * 0.4 * _moving
		node.position.y += 0.02 * sin(time * 3.0 + id) * (1.0 - _moving)
	else:
		for sx in [-1, 1]:
			var leg: Node3D = _parts["leg_%d" % sx]
			leg.rotation.x = swing * 0.7 * sx
		var arm_l: Node3D = _parts["arm_-1"]
		arm_l.rotation.x = -swing * 0.6
		var arm_r: Node3D = _parts["arm_1"]
		# armement : bras levé au-dessus de la tête ; coup : il retombe vite devant, puis revient au repos
		var arm_angle := lerpf(swing * 0.5, deg_to_rad(-150.0), windup_k)
		if state == State.RECOVER:
			var since := float(cfg["cooldown"]) - timer
			if since < 0.1:
				arm_angle = lerpf(deg_to_rad(-150.0), deg_to_rad(-60.0), clampf(since / 0.1, 0.0, 1.0))
			else:
				arm_angle = lerpf(deg_to_rad(-60.0), swing * 0.5, clampf((since - 0.1) / 0.3, 0.0, 1.0))
		arm_r.rotation.x = arm_angle
		var torso: Node3D = _parts["torso"]
		torso.rotation.x = deg_to_rad(-12.0) * windup_k + deg_to_rad(18.0) * strike_k
		var blade: Node3D = _parts["blade"]
		blade.rotation.x = deg_to_rad(-40.0 - 60.0 * strike_k)
		var head: Node3D = _parts["head"]
		head.rotation.z = sin(time * 1.4 + id) * 0.04
	# coup reçu : flash teinté court (rouge-orangé, qui s'éteint) au lieu de l'ancien voile blanc opaque qui faisait un fantôme,
	# un petit recul visuel du corps (chez tout le monde, même si seul l'hôte déplace vraiment l'ennemi) et une gerbe d'étincelles
	# lot 5 (6.9) : il mange (penché, qui mâche) ; quand ses PV remontent, une gerbe verte
	if state == State.HEAL:
		node.position.y += 0.03 * absf(sin(time * 9.0))
		node.rotation.x = 0.25
	if _shown_hp >= 0 and hp > _shown_hp:
		_heal_burst()
	_shown_hp = hp
	var flash_k := clampf(hurt_t / GameConfig.HIT_FLASH_TIME, 0.0, 1.0)
	if flash_k > 0.0:
		var mat := _flash_mat()
		mat.albedo_color = Color(GameConfig.HIT_FLASH_COLOR, GameConfig.HIT_FLASH_ALPHA * flash_k)
		node.position -= Vector3(facing.x, 0.0, facing.y) * GameConfig.HIT_RECOIL_VISUAL * flash_k
		if not _flash_on:
			_impact_burst()
	for mi in _meshes:
		mi.material_overlay = _flash_mat() if flash_k > 0.0 else null
	_flash_on = flash_k > 0.0
	var show_bar := hp < max_hp
	_bar_back.visible = show_bar
	_bar_fill.visible = show_bar
	if show_bar:
		# 13/11 (Jimmy : « la barre reste pleine, puis le mob meurt d'un coup ») : la barre se vide vraiment, par la droite.
		# Le rectangle est rétréci en largeur et décalé dans son propre maillage (qui fait toujours face à la caméra), et non
		# déplacé dans le repère de l'ennemi, qui tourne avec lui.
		var frac := clampf(float(hp) / float(max_hp), 0.001, 1.0)
		(_bar_fill.mesh as QuadMesh).center_offset = Vector3(-0.42 * (1.0 - frac) / frac, 0.0, 0.0)
		_bar_fill.position.x = 0.0
	# la barre ne doit pas grossir avec l'échelle de l'ennemi
	var inv := 1.0 / sc
	_bar_back.scale = Vector3(inv, inv, inv)
	_bar_fill.scale = Vector3(maxf(float(hp) / float(max_hp), 0.001) * inv, inv, inv)
	_bar_back.position.y = (0.95 if kind == "crab" else 2.15) + 0.0
	_bar_fill.position.y = _bar_back.position.y
	_bar_fill.position.x = -0.42 * (1.0 - float(hp) / float(max_hp)) * inv


func _remaining_windup() -> float:
	return maxf(timer, 0.0)


## Matériau du flash, propre à cet ennemi (son opacité suit SON coup : un matériau partagé ferait clignoter tous les ennemis).
func _flash_mat() -> StandardMaterial3D:
	if _flash == null:
		_flash = StandardMaterial3D.new()
		_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash.albedo_color = Color(GameConfig.HIT_FLASH_COLOR, GameConfig.HIT_FLASH_ALPHA)
		_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	return _flash


## Lot 5 (6.9) : il vient de se soigner : des croix vertes montent autour de lui.
func _heal_burst() -> void:
	if node == null or node.get_parent() == null:
		return
	var parent := node.get_parent() as Node3D
	for k in 6:
		var p := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 0.04)
		p.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.45, 1.0, 0.5)
		p.material_override = m
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(p)
		var a := TAU * float(k) / 6.0
		var base := node.position + Vector3(cos(a) * 0.45, 0.6, sin(a) * 0.45)
		p.position = base
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position:y", base.y + 1.2, 0.9)
		tw.tween_property(p, "scale", Vector3.ONE * 0.2, 0.9)
		tw.chain().tween_callback(p.queue_free)


## Petites étincelles d'impact (orange et blanches) qui jaillissent du torse et retombent. Joué chez chaque joueur, quand le
## flash démarre (sur l'hôte au coup, sur les clients quand l'état réseau annonce des PV en moins).
func _impact_burst() -> void:
	if node == null or node.get_parent() == null:
		return
	var parent := node.get_parent() as Node3D
	var sc := float(cfg.get("scale", 1.0))
	var base := node.position + Vector3(0.0, (0.45 if kind == "crab" else 1.2) * sc, 0.0)
	for k in GameConfig.HIT_SPARKS:
		var drop := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		sm.radial_segments = 6
		sm.rings = 3
		drop.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.55, 0.15) if k % 3 != 0 else Color(1.0, 0.95, 0.8)
		drop.material_override = m
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(drop)
		drop.position = base
		var a := TAU * float(k) / float(GameConfig.HIT_SPARKS) + randf() * 0.6
		var d := Vector3(cos(a), 0.0, sin(a)) * randf_range(0.25, 0.6)
		var tw := drop.create_tween()
		tw.set_parallel(true)
		tw.tween_property(drop, "position:x", base.x + d.x, 0.3)
		tw.tween_property(drop, "position:z", base.z + d.z, 0.3)
		tw.tween_property(drop, "position:y", base.y + randf_range(0.2, 0.5), 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(drop, "scale", Vector3.ONE * 0.2, 0.3)
		tw.chain().tween_property(drop, "position:y", base.y - 0.3, 0.18).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(drop.queue_free)
