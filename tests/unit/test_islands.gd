extends SceneTree
## Tests des îles : chaque ennemi, coffre et accessoire est sur la terre ferme ; les îles ne se touchent pas et sont
## loin du port et des récifs ; on y marche (Land) et un bateau s'y arrête ; les ennemis poursuivent, frappent et
## meurent comme prévu ; les coffres ne s'ouvrent qu'une fois ; l'état réseau fait l'aller-retour.
## Lancer : godot --headless --path . -s tests/unit/test_islands.gd

var _failed := 0


func _initialize() -> void:
	var w := _world()
	_test_layout(w)
	_test_land(w)
	_test_relief(w)
	_test_combat()
	_test_chests()
	_test_net()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
		print("ÉCHEC : ", what)


func _world() -> IslandWorld:
	var w := IslandWorld.new()
	w.setup(IslandWorld.read_json(IslandWorld.ISLANDS_PATH), IslandWorld.read_json(IslandWorld.ENEMIES_PATH))
	return w


func _test_layout(w: IslandWorld) -> void:
	_check(w.islands.size() >= 4, "au moins quatre îles")
	_check(w.enemies.size() > 0 and w.chests.size() > 0, "il y a des ennemis et des coffres")
	for i in w.islands.size():
		var isl: Dictionary = w.islands[i]
		var name := str(isl["name"])
		for en_id: int in isl["enemies"]:
			var en := w.enemies[en_id]
			_check(w.walkable(i, en.home, 0.4 * float(en.cfg["scale"])), "%s : l'ennemi %s est sur un sol praticable" % [name, en.kind])
		for ch_id: int in isl["chests"]:
			var ch: Dictionary = w.chests[ch_id]
			_check(w.sdf(i, ch["pos"]) >= 1.0, "%s : un coffre est à l'intérieur des terres" % name)
			var reachable := false
			for k in 16:
				var q: Vector2 = (ch["pos"] as Vector2) + Vector2.from_angle(TAU * k / 16.0) * 1.1
				if w.walkable(i, q, 0.22):
					reachable = true
			_check(reachable, "%s : un coffre est accessible à pied" % name)
		var palms := 0
		for it: Dictionary in isl["items"]:
			if it["kind"] == "palm":
				palms += 1
		_check(palms == int((isl["scatter"] as Dictionary).get("palm", 0)), "%s : tous les palmiers sont placés" % name)
		for j in range(i + 1, w.islands.size()):
			var other: Dictionary = w.islands[j]
			var gap: float = (isl["center"] as Vector2).distance_to(other["center"]) - float(isl["radius"]) - float(other["radius"])
			_check(gap > 40.0, "%s et %s sont assez éloignées (%.0f m)" % [name, str(other["name"]), gap])
		# loin du port (terre de x -62..42, z -52..30) et des récifs
		var c: Vector2 = isl["center"]
		var dx := maxf(maxf(-62.0 - c.x, c.x - 42.0), 0.0)
		var dz := maxf(maxf(-52.0 - c.y, c.y - 30.0), 0.0)
		_check(Vector2(dx, dz).length() > float(isl["radius"]) + 60.0, "%s est loin du port" % name)
		for r: Array in IslandWorld.read_json("res://data/hull.json").get("rocks", []):
			_check(Vector2(float(r[0]), float(r[1])).distance_to(c) > float(isl["radius"]) + 20.0, "%s est loin des récifs" % name)


func _test_land(w: IslandWorld) -> void:
	var land := Land.new()
	land.load_meta(IslandWorld.read_json("res://assets/models/port/port_meta.json"))
	land.load_town(IslandWorld.read_json("res://data/town.json"))
	land.island_discs = w.walk_discs()
	var i := 0
	var isl: Dictionary = w.islands[i]
	var c: Vector2 = isl["center"]
	# un point libre près du centre de la première île
	var free := land.nearest_walkable(c + Vector2(0, 6), 5.0)
	_check(land.is_walkable(free), "on peut se tenir sur l'île aux Crabes")
	_check(land.walk_height(free, 0.0) == 0.0, "le sol de l'île est à la hauteur 0")
	_check(not land.is_walkable(c + Vector2(0, 80)), "la mer n'est pas praticable")
	# un bateau qui entre dans l'île s'arrête
	var lobe: Vector3 = isl["lobes"][0]
	var edge := Vector2(lobe.x, lobe.y) + Vector2(lobe.z + 0.3, 0)
	_check(w.ship_hit_index([edge]) == 0, "la coque touche l'île avant le bord marchable")
	_check(w.ship_hit_index([Vector2(lobe.x, lobe.y) + Vector2(lobe.z + 3.0, 0)]) < 0 or w.sdf(0, Vector2(lobe.x, lobe.y) + Vector2(lobe.z + 3.0, 0)) > -3.0, "la coque ne touche pas l'île de loin")
	_check(w.island_at(c) == 0, "island_at retrouve l'île")
	_check(w.island_at(Vector2(0, 10)) == -1, "pas d'île au port")


func _test_combat() -> void:
	var w := _world()
	var rng := RandomNumberGenerator.new()
	var crab: IslandEnemy = null
	for en in w.enemies:
		if en.kind == "crab":
			crab = en
			break
	var island := crab.island
	var player := {"id": 7, "pos": crab.pos + Vector2(4.0, 0.0)}
	# trop loin : le crabe reste tranquille
	var far := {"id": 7, "pos": crab.pos + Vector2(30.0, 0.0)}
	w.step(0.1, [far])
	_check(crab.state == IslandEnemy.State.IDLE, "un joueur lointain n'attire pas le crabe")
	# proche : il poursuit, puis frappe
	var got_hit := false
	for k in 200:
		for ev: Dictionary in w.step(0.05, [player]):
			if int(ev["target"]) == 7 and int(ev["damage"]) == 1:
				got_hit = true
		if got_hit:
			break
	_check(got_hit, "le crabe rejoint le joueur immobile et le blesse")
	_check(crab.pos.distance_to(player["pos"]) < 1.6, "le crabe est contre le joueur")
	# un joueur qui s'éloigne pendant l'armement n'est pas touché
	var crab2: IslandEnemy = null
	for en in w.enemies:
		if en.kind == "crab" and en != crab:
			crab2 = en
			break
	var p2 := {"id": 8, "pos": crab2.pos + Vector2(3.0, 0.0)}
	var hit2 := false
	for k in 40:
		w.step(0.05, [p2])
		if crab2.state == IslandEnemy.State.WINDUP:
			p2["pos"] = crab2.pos + Vector2(4.0, 0.0)   # il recule hors de portée
			break
	for k in 40:
		for ev: Dictionary in w.step(0.05, [p2]):
			if int(ev["target"]) == 8:
				hit2 = true
		if crab2.state == IslandEnemy.State.RECOVER:
			break
	_check(not hit2, "reculer pendant l'armement évite le coup")
	# le sabre : un crabe a 2 points de vie
	var victim := w.enemies[0]
	victim.revive()
	var dir := Vector2(1, 0)
	var origin := victim.pos - dir * 1.2
	var hits1 := w.swing(origin, dir)
	_check(hits1.size() == 1 and not bool(hits1[0]["killed"]), "un premier coup blesse le crabe sans le tuer")
	victim.knock = Vector2.ZERO
	victim.pos = origin + dir * 1.2
	var hits2 := w.swing(origin, dir)
	_check(hits2.size() == 1 and bool(hits2[0]["killed"]), "le deuxième coup le tue")
	_check(int(hits2[0]["gold"]) >= 2 and int(hits2[0]["gold"]) <= 5, "il lâche entre 2 et 5 or")
	_check(victim.is_dead(), "l'ennemi est mort")
	_check(w.swing(origin, dir).is_empty(), "on ne frappe pas un mort")
	# un coup dans le dos ne touche pas
	var other := w.enemies[1]
	other.revive()
	_check(w.swing(other.pos + Vector2(1.0, 0.0), Vector2(1, 0)).is_empty(), "un coup dans la direction opposée rate")
	# retour à la vie quand plus personne n'est là
	victim.timer = 0.0
	for k in 3:
		w.step(0.1, [])
	_check(not victim.is_dead() or w.islands.size() == 0, "l'ennemi mort revient quand l'île est vide")
	rng.seed = 1


func _test_chests() -> void:
	var w := _world()
	var g := w.open_chest(0)
	_check(g == int(w.chests[0]["gold"]) and g > 0, "le coffre donne son or")
	_check(w.open_chest(0) == -1, "un coffre ouvert est vide")
	_check(w.nearest_chest((w.chests[0] as Dictionary)["pos"]) != 0, "le coffre ouvert n'est plus proposé")
	var near := w.nearest_chest((w.chests[1] as Dictionary)["pos"] + Vector2(0.5, 0.0))
	_check(near == 1, "le coffre fermé le plus proche est proposé")
	# il se referme après un long moment si personne n'est là
	(w.chests[0] as Dictionary)["timer"] = 0.0
	w.step(0.1, [])
	_check(not (w.chests[0] as Dictionary)["open"], "le coffre se remplit à nouveau")


func _test_net() -> void:
	var a := _world()
	var b := _world()
	a.enemies[0].pos = a.enemies[0].pos + Vector2(1.5, 0.5)
	a.enemies[0].hp = 1
	a.enemies[1].state = IslandEnemy.State.DEAD
	a.open_chest(1)
	b.apply_net(a.net_state(), true)
	_check(b.enemies[0].remote_target.distance_to(a.enemies[0].pos) < 0.02, "la position de l'ennemi arrive")
	_check(b.enemies[0].hp == 1, "la vie de l'ennemi arrive")
	_check(b.enemies[1].is_dead(), "la mort de l'ennemi arrive")
	_check((b.chests[1] as Dictionary)["open"] and not (b.chests[0] as Dictionary)["open"], "les coffres ouverts arrivent")


## Une rampe se monte à pied, une falaise non ; le sol suit la hauteur du plateau.
func _test_relief(w: IslandWorld) -> void:
	var land := Land.new()
	land.load_meta(IslandWorld.read_json("res://assets/models/port/port_meta.json"))
	land.island_discs = w.walk_discs()
	land.island_height = w.ground_h
	var isl: Dictionary = w.islands[0]
	var pl: Dictionary = (isl["plateaus"] as Array)[0]
	var c: Vector2 = pl["c"]
	var top: float = pl["h"]
	_check(absf(w.ground_h(c) - top) < 0.001, "le plateau est à sa hauteur")
	_check(absf(w.ground_h(c + Vector2(30, 0))) < 0.001 or w.island_at(c + Vector2(30, 0)) < 0, "la plaine est à 0")
	# on monte la rampe (angle 0 : vers +x) jusqu'au sommet
	var pos: Vector2 = c + Vector2(float(pl["r"]) + float(pl["ramp_len"]) - 0.3, 0)
	var h := 0.0
	for k in 400:
		var r := land.step(pos, Vector2(-0.05, 0), h)
		pos = Vector2(r.x, r.y)
		h = r.z
	_check(absf(h - top) < 0.05 and pos.distance_to(c) < float(pl["r"]), "on grimpe la rampe jusqu'au plateau (h=%.2f)" % h)
	# la falaise (côté opposé à la rampe) arrête
	var p2: Vector2 = c + Vector2(-float(pl["r"]) - 1.0, 0)
	var h2 := 0.0
	if land.is_walkable(p2):
		for k in 200:
			var r := land.step(p2, Vector2(0.05, 0), h2)
			p2 = Vector2(r.x, r.y)
			h2 = r.z
		_check(h2 < 0.35, "on ne grimpe pas la falaise (h=%.2f)" % h2)
	# les objets du plateau ne sont pas posés sur une pente
	for k in w.chests.size():
		var ch: Dictionary = w.chests[k]
		_check(w.is_flat(int(ch["island"]), ch["pos"], 0.4), "le coffre %d est sur un sol plat" % k)
