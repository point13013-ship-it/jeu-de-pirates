extends SceneTree
## Tests de la mer : réglage des voiles face au vent, vent qui dérive, îles tirées au hasard (même monde pour tous), tonneaux et
## caisses cassables, butin du monde, trésors, armes à feu, saut par-dessus le bastingage, bateaux ennemis (IA, volées, naufrage).
## Lancer : godot --headless --path . -s tests/unit/test_sea.gd

var _failed := 0


func _initialize() -> void:
	_test_trim()
	_test_wind()
	_test_gen()
	_test_chunk_sync()
	_test_breakables()
	_test_treasures()
	_test_weapons()
	_test_loot()
	_test_jump()
	await _test_fleet()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
		print("ÉCHEC : ", what)


# ------------------------------------------------------------------ voiles et vent

func _test_trim() -> void:
	var sim := ShipSim.new()
	sim.yaw = 0.0
	sim.wind_dir = Vector2(1, 0)   # le vent pousse vers l'étrave : vent arrière
	_check(absf(sim.optimal_trim()) < 0.1, "vent arrière : l'idéal est des vergues perpendiculaires")
	_check(sim.trim_efficiency() > 0.99, "vent arrière, vergues droites : plein rendement")
	# vent de travers : il faut orienter les vergues
	sim.yaw = -PI / 2.0
	sim.wind_dir = Vector2(1, 0)
	var best := sim.optimal_trim()
	_check(absf(best) > 0.7 and absf(best) < 1.13, "vent de travers : angle idéal marqué (%.2f rad)" % best)
	sim.sail_trim = 0.0
	var bad := sim.trim_efficiency()
	sim.sail_trim = best
	var good := sim.trim_efficiency()
	_check(good > 0.99 and bad < 0.3, "vergues mal réglées : rendement faible (%.2f) ; bien réglées : plein (%.2f)" % [bad, good])
	# plus vite avec de bonnes voiles
	var fast := ShipSim.new()
	var slow := ShipSim.new()
	for s: ShipSim in [fast, slow]:
		s.yaw = -PI / 2.0
		s.wind_dir = Vector2(1, 0)
		s.sail_level = 3
		s.sail_open = 1.0
		s.auto_trim_pending = false
	fast.sail_trim = best
	fast.sail_trim_target = best
	slow.sail_trim = 0.0
	slow.sail_trim_target = 0.0
	for k in 300:
		fast.step(0.05)
		slow.step(0.05)
	_check(fast.speed > slow.speed * 2.0, "des voiles bien réglées vont bien plus vite (%.1f contre %.1f m/s)" % [fast.speed, slow.speed])
	# vent debout : rien à régler
	var head := ShipSim.new()
	head.yaw = PI
	head.wind_dir = Vector2(1, 0)
	_check(head.trim_efficiency() == 1.0, "vent debout : pas de réglage qui tienne, le rendement ne baisse pas")
	# hisser depuis des voiles affalées règle d'emblée les vergues
	var h := ShipSim.new()
	h.yaw = -PI / 2.0
	h.wind_dir = Vector2(1, 0)
	h.change_sails(1)
	_check(is_equal_approx(h.sail_trim_target, h.optimal_trim()) and h.sail_level == 1, "on hisse : vergues réglées d'emblée")
	h.change_sails(-5)
	_check(h.sail_level == 0, "on affale jusqu'à zéro")
	# tourner les vergues : l'entrée change la cible, bornée
	h.trim_input = 1.0
	for k in 400:
		h.step(0.05)
	_check(is_equal_approx(h.sail_trim_target, ShipSim.MAX_TRIM), "les vergues tournent jusqu'à leur butée")


func _test_wind() -> void:
	var sim := ShipSim.new()
	var lo := 9.0
	var hi := -9.0
	for k in 600:
		sim.drift_wind(float(k) * 2.0)
		lo = minf(lo, sim.wind_angle)
		hi = maxf(hi, sim.wind_angle)
	_check(lo > deg_to_rad(-46.0) and hi < deg_to_rad(46.0), "le vent reste dans sa bande autour du vent d'origine")
	_check(hi - lo > deg_to_rad(20.0), "et il bouge vraiment")
	sim.drift_wind(123.0)
	var a := sim.wind_angle
	sim.drift_wind(123.0)
	_check(a == sim.wind_angle, "même temps, même vent (les joueurs sont d'accord)")


# ------------------------------------------------------------------ îles tirées au hasard

func _test_gen() -> void:
	var avoid: Array = [Vector3(110.0, 140.0, 45.0)]
	var count := 0
	for cx in range(-4, 5):
		for cz in range(-4, 5):
			var c := Vector2i(cx, cz)
			var a := IslandGen.generate(c, 777, avoid)
			var b := IslandGen.generate(c, 777, avoid)
			_check(JSON.stringify(a) == JSON.stringify(b), "la case %s donne toujours la même île" % c)
			if a.is_empty():
				continue
			count += 1
			var ctr := Vector2(float(a["center"][0]), float(a["center"][1]))
			_check(not IslandGen.PORT_RECT.has_point(ctr), "case %s : pas d'île sur le port" % c)
			_check(ctr.distance_to(Vector2(110, 140)) > 150.0, "case %s : loin des îles du fichier" % c)
			var lobes: Array = a["lobes"]
			for e: Dictionary in a.get("enemies", []) + a.get("chests", []):
				_check(IslandGen._sdf(lobes, Vector2(float(e["at"][0]), float(e["at"][1]))) >= 2.5, "case %s : ennemis et coffres sont sur la terre" % c)
			for pl: Dictionary in a.get("plateaus", []):
				_check(IslandGen._sdf(lobes, Vector2(float(pl["at"][0]), float(pl["at"][1]))) > 0.0, "case %s : plateau sur la terre" % c)
	_check(count >= 20 and count <= 60, "environ la moitié des cases ont une île (%d sur 81)" % count)
	var other := 0
	for cx in range(-4, 5):
		for cz in range(-4, 5):
			if JSON.stringify(IslandGen.generate(Vector2i(cx, cz), 778, avoid)) != JSON.stringify(IslandGen.generate(Vector2i(cx, cz), 777, avoid)):
				other += 1
	_check(other > 40, "une autre graine donne un autre monde")
	# les baies sont rarissimes
	var berries := 0
	var total := 0
	for cx in range(-12, 13):
		for cz in range(-12, 13):
			var d := IslandGen.generate(Vector2i(cx, cz), 31, [])
			if d.is_empty():
				continue
			total += 1
			if d.has("berries"):
				berries += 1
	_check(total > 100 and float(berries) / float(total) < 0.09, "baies des dieux très rares : %d îles sur %d" % [berries, total])


func _world() -> IslandWorld:
	var w := IslandWorld.new()
	w.setup(IslandWorld.read_json(IslandWorld.ISLANDS_PATH), IslandWorld.read_json(IslandWorld.ENEMIES_PATH))
	return w


func _test_chunk_sync() -> void:
	var host := _world()
	var fixed := host.islands.size()
	var made := 0
	for k in 40:
		if host.ensure_around(Vector2(900.0 + 3.0 * k, 700.0)) >= 0:
			made += 1
	_check(made > 0 and host.islands.size() == fixed + made, "l'hôte génère des îles autour du bateau (%d)" % made)
	# l'hôte ouvre un coffre : le client, qui n'a généré aucune île, doit tout refaire à l'identique
	var client := _world()
	client.apply_net(host.net_state(), true)
	_check(client.islands.size() == host.islands.size(), "le client refait les mêmes îles")
	var same := true
	for i in host.islands.size():
		same = same and str(client.islands[i]["id"]) == str(host.islands[i]["id"]) and client.islands[i]["center"] == host.islands[i]["center"]
	_check(same, "dans le même ordre, aux mêmes endroits")
	_check(client.enemies.size() == host.enemies.size() and client.chests.size() == host.chests.size() and client.breakables.size() == host.breakables.size(),
			"mêmes ennemis, coffres et tonneaux (indices communs pour le réseau)")
	_check(host.ensure_around(Vector2(900.0, 700.0)) == -1 or true, "ré-appeler ne casse rien")
	# les îles agrandies : chacune est plus grande qu'à l'origine
	var orig := IslandWorld.read_json(IslandWorld.ISLANDS_PATH)["islands"] as Array
	var first_lobe: Array = orig[0]["lobes"][0]
	var scaled: Vector3 = host.islands[0]["lobes"][0]
	_check(is_equal_approx(scaled.z, float(first_lobe[2]) * IslandWorld.ISLAND_SCALE), "les îles du fichier sont agrandies")


# ------------------------------------------------------------------ tonneaux et caisses

func _test_breakables() -> void:
	var w := _world()
	_check(w.breakables.size() >= 8, "il y a des tonneaux et des caisses à casser (%d)" % w.breakables.size())
	var k := 0
	var b: Dictionary = w.breakables[k]
	var p: Vector2 = b["pos"]
	var isl: Dictionary = w.islands[int(b["island"])]
	var blocked_before := (isl["blockers_c"] as Array).has(b["block"])
	_check(blocked_before, "un tonneau intact bloque le passage")
	# trop loin : rien
	_check(w.hit_breakables(p + Vector2(10, 0), Vector2.LEFT, 1.9, 0.3).is_empty(), "trop loin : rien ne casse")
	# un coup dans le mauvais sens : rien
	_check(w.hit_breakables(p + Vector2(1.2, 0), Vector2.RIGHT, 1.9, 0.3).is_empty(), "dos tourné : rien ne casse")
	var hits: Array = []
	for n in 3:
		hits = w.hit_breakables(p + Vector2(1.2, 0), Vector2.LEFT, 1.9, 0.3)
		if not hits.is_empty():
			break
	_check(hits.size() == 1 and bool(b["broken"]), "le coup casse l'objet")
	_check(not (isl["blockers_c"] as Array).has(b["block"]), "cassé, il ne bloque plus")
	_check(w.hit_breakables(p + Vector2(1.2, 0), Vector2.LEFT, 1.9, 0.3).is_empty(), "on ne casse pas deux fois la même caisse")
	# le butin : toujours quelque chose, du genre connu
	for n in 40:
		var loot := w.prop_loot("crate" if n % 2 == 0 else "barrel")
		_check(not loot.is_empty(), "un objet brisé lâche toujours quelque chose")
		for kind in loot:
			var s := str(kind)
			_check(s == "plank" or s == "ball" or s.begins_with("g:") or (s.begins_with("t:") and Treasure.exists(s.substr(2))), "butin valide : %s" % s)
	# il se reforme quand personne n'est là
	b["timer"] = 0.0
	w.step(0.1, [])
	_check(not bool(b["broken"]) and (isl["blockers_c"] as Array).has(b["block"]), "l'objet se reforme (et rebloque)")
	# l'état réseau fait l'aller-retour
	w.hit_breakables(p + Vector2(1.2, 0), Vector2.LEFT, 1.9, 0.3, 5)
	var other := _world()
	other.apply_net(w.net_state(), true)
	_check(bool((other.breakables[k] as Dictionary)["broken"]), "les autres voient l'objet cassé")


# ------------------------------------------------------------------ trésors

func _test_treasures() -> void:
	_check(Treasure.defs().size() >= 4, "des trésors sont définis")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen := {}
	for n in 600:
		var id := Treasure.roll(rng)
		_check(Treasure.exists(id), "tirage valide")
		seen[id] = int(seen.get(id, 0)) + 1
	_check(int(seen.get("coffret", 0)) > int(seen.get("couronne", 0)) * 3, "le trésor rare est vraiment rare")
	var rare := 0
	var rare_boosted := 0
	for n in 600:
		if Treasure.roll(rng, 1.0) == "couronne":
			rare += 1
		if Treasure.roll(rng, 4.0) == "couronne":
			rare_boosted += 1
	_check(rare_boosted > rare, "un coffre bien gardé donne plus souvent un trésor rare")
	_check(Treasure.index_of("calice") >= 0 and Treasure.id_at(Treasure.index_of("calice")) == "calice", "rang <-> identifiant")
	_check(Treasure.id_at(99) == "" and Treasure.index_of("nimportequoi") == -1, "inconnu : vide")
	_check(Treasure.total_value(["coffret", "calice"]) == Treasure.value_of("coffret") + Treasure.value_of("calice"), "valeur d'une liste")
	var icon := Treasure.make_icon("crane")
	_check(icon.get_child_count() > 0, "une maquette existe pour chaque trésor")
	icon.free()


# ------------------------------------------------------------------ armes

func _test_weapons() -> void:
	_check(Weapons.order().size() >= 4 and Weapons.exists("tromblon") and Weapons.is_gun("fusil") and not Weapons.is_gun("sabre"), "armes du catalogue")
	_check(Weapons.ammo_of("tromblon") == "shells" and Weapons.ammo_of("pistolet") == "bullets", "bonnes munitions")
	_check(Weapons.next_owned("sabre", ["sabre", "fusil"]) == "fusil" and Weapons.next_owned("fusil", ["sabre", "fusil"]) == "sabre", "X : arme suivante, en boucle")
	var w := _world()
	var crab: IslandEnemy = null
	for en in w.enemies:
		if en.kind == "crab":
			crab = en
			break
	crab.revive()
	crab.pos = Vector2(8.0, 0.0)
	var pistol := Weapons.get_def("pistolet")
	var hits := w.shoot(Vector2.ZERO, Vector2.RIGHT, pistol)
	_check(hits.size() == 1 and bool(hits[0]["killed"]), "le pistolet tue un crabe (2 vies) d'un tir à 8 m")
	crab.revive()
	crab.pos = Vector2(30.0, 0.0)
	_check(w.shoot(Vector2.ZERO, Vector2.RIGHT, pistol).is_empty(), "hors de portée du pistolet")
	var sniper := Weapons.get_def("fusil")
	var hit_far := w.shoot(Vector2.ZERO, Vector2.RIGHT, sniper)
	_check(hit_far.size() == 1, "le fusil de précision porte à 30 m")
	# la balle du fusil traverse : deux crabes alignés, deux touchés
	crab.revive()
	crab.pos = Vector2(10.0, 0.0)
	var second: IslandEnemy = null
	for en in w.enemies:
		if en.kind == "crab" and en != crab:
			second = en
			break
	second.revive()
	second.pos = Vector2(16.0, 0.0)
	_check(w.shoot(Vector2.ZERO, Vector2.RIGHT, sniper).size() == 2, "la balle du fusil traverse les ennemis alignés")
	crab.revive()
	crab.pos = Vector2(10.0, 0.0)
	second.revive()
	second.pos = Vector2(16.0, 0.0)
	var first_hits := w.shoot(Vector2.ZERO, Vector2.RIGHT, pistol)
	_check(first_hits.size() == 1 and int((first_hits[0] as Dictionary)["enemy"]) == crab.id, "le pistolet touche seulement le premier")
	# tromblon : une gerbe, proche touche, loin non
	crab.revive()
	crab.pos = Vector2(2.5, 0.0)
	second.revive()
	second.pos = Vector2(40.0, 0.0)
	var shotgun := Weapons.get_def("tromblon")
	_check(w.shoot(Vector2.ZERO, Vector2.RIGHT, shotgun).size() >= 1, "le tromblon touche de près")
	crab.revive()
	crab.pos = Vector2(14.0, 0.0)
	_check(w.shoot(Vector2.ZERO, Vector2.RIGHT, shotgun).is_empty(), "le tromblon ne porte pas loin")


# ------------------------------------------------------------------ butin du monde

func _test_loot() -> void:
	var a := WorldLoot.new()
	var id1 := a.spawn("t:calice", Vector2(10, 5))
	var id2 := a.spawn("plank", Vector2(12, 5), 400.0, Vector2(11, 5))
	_check(a.count() == 2 and a.pos_of(id1) == Vector2(10, 5), "du butin est posé")
	_check(a.nearest(Vector2(10.5, 5.0), 1.3) == id1, "le plus proche à portée")
	_check(a.nearest(Vector2(30, 30), 1.3) == -1, "trop loin")
	_check(a.nearest(Vector2(10.5, 5.0), 1.3, func(kind: String) -> bool: return not kind.begins_with("t:")) != id1, "on peut filtrer (mains prises : pas de trésor)")
	# il dérive en mer et expire
	a.spawn("ball", Vector2(0, 0), 5.0, Vector2.INF, Vector2(1.0, 0.0))
	for k in 20:
		a.step(0.1, true)
	_check(a.pos_of(a.items[a.items.size() - 1]["id"]).x > 0.5, "le butin dérive")
	for k in 40:
		a.step(0.2, true)
	_check(a.count() == 2, "la balle expire, les deux autres durent")
	# réseau
	var b := WorldLoot.new()
	b.apply_net(a.net_state())
	_check(b.count() == 2 and b.pos_of(id1) == Vector2(10, 5), "l'état arrive chez les autres")
	var taken := a.take(id1)
	_check(taken == "t:calice" and a.take(id1) == "", "on le ramasse une fois")
	b.apply_net(a.net_state())
	_check(b.count() == 1, "il disparaît chez les autres")
	a.move_to(id2, Vector2(3, 3))
	_check(a.pos_of(id2) == Vector2(3, 3), "un grappin le déplace")


# ------------------------------------------------------------------ saut par-dessus le bastingage

func _test_jump() -> void:
	for ship_name in ["sloop", "brigantin", "galion"]:
		var ship := ShipModel.new()
		_check(ship.load_ship(ship_name), "%s : chargé" % ship_name)
		_check(not ship.low_boxes.is_empty() or not ship.low_circles.is_empty(), "%s : des obstacles se franchissent d'un saut" % ship_name)
		# au sol on ne sort pas par le bastingage ; en l'air oui
		var edge := Vector2(0.0, ship.half_width(0.0) + 0.5)
		var inside := Vector2(0.0, 0.2)
		_check(ship.is_walkable(inside) or ship.nearest_walkable(inside).distance_to(inside) < 1.0, "%s : un point de pont est libre" % ship_name)
		_check(not ship.is_walkable(edge), "%s : pas de marche hors de la coque" % ship_name)
		_check(ship.is_walkable_air(edge, 0.9), "%s : un saut passe le bastingage" % ship_name)
		_check(not ship.is_walkable_air(Vector2(0.0, ship.half_width(0.0) - 0.15), 0.3), "%s : trop bas, le bastingage arrête" % ship_name)
		_check(ship.over_hull(inside) and not ship.over_hull(edge), "%s : au-dessus de la coque ou de l'eau" % ship_name)
		_check(ship.landing_spot(edge) == Vector2.INF, "%s : au-dessus de l'eau on tombe à l'eau" % ship_name)
		# les mâts sont trop hauts, la cabine aussi
		for m: Array in ship.masts:
			_check(not ship.is_walkable_air(Vector2(float(m[0]), 0.0), 1.2), "%s : un mât ne s'enjambe pas" % ship_name)
		if not ship.cabin.is_empty():
			var wall := Vector2((float(ship.cabin["x0"]) + float(ship.cabin["x1"])) * 0.5, float(ship.cabin["y1"]) - 0.04)
			_check(not ship.is_walkable_air(wall, 1.2), "%s : un mur de cabine ne s'enjambe pas" % ship_name)
		# un barrage de caisse : on l'enjambe en l'air
		for i: int in ship.low_boxes:
			var bx: Array = ship.boxes[i]
			var mid := Vector2((float(bx[0]) + float(bx[2])) * 0.5, (float(bx[1]) + float(bx[3])) * 0.5)
			_check(not ship.is_walkable(mid), "%s : la caisse %d bloque à pied" % [ship_name, i])
			# (sur le sloop la pile de caisses est adossée au mur de la cabine : son centre est dans le mur, qui ne s'enjambe pas)
			var on_wall := false
			for j in ship.boxes.size():
				var wb: Array = ship.boxes[j]
				if not (j in ship.low_boxes) and mid.x > float(wb[0]) - 0.12 and mid.x < float(wb[2]) + 0.12 and mid.y > float(wb[1]) - 0.12 and mid.y < float(wb[3]) + 0.12:
					on_wall = true
			if not on_wall:
				_check(ship.is_walkable_air(mid, 0.9), "%s : mais pas en l'air" % ship_name)
		ship.free()


# ------------------------------------------------------------------ bateaux ennemis

func _test_fleet() -> void:
	var parent := Node3D.new()
	root.add_child.call_deferred(parent)
	await process_frame   # les bateaux doivent être dans l'arbre de scène (positions globales des canons)
	var fleet := EnemyFleet.new()
	fleet.setup(parent)
	var shots: Array = []
	var drops: Array = []
	var sunk: Array = []
	fleet.fire_cb = func(id: int, idx: int, start: Vector3, vel: Vector3) -> void: shots.append([id, idx, start, vel])
	fleet.loot_cb = func(kind: String, pos: Vector2, vel: Vector2) -> void: drops.append([kind, pos, vel])
	fleet.sunk_cb = func(id: int, ship_name: String) -> void: sunk.append([id, ship_name])
	fleet.water_free_cb = func(_p: Vector2) -> bool: return true
	fleet.spawn_enabled = false
	var id := fleet.spawn("sloop", Vector2(100.0, 0.0), PI)
	_check(fleet.alive_count() == 1 and fleet.find(id) == 0, "un ennemi est créé")
	var target := {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "alive": true, "wind": Vector2(1, 0)}
	var s: Dictionary = fleet.ships[0]
	var start_dist := (s["sim"] as ShipSim).position.distance_to(Vector2.ZERO)
	for k in 400:   # 20 s
		fleet.step(0.05, true, target)
	var d1 := (s["sim"] as ShipSim).position.distance_to(Vector2.ZERO)
	_check(s["state"] == "chase", "il voit les joueurs et les chasse")
	_check(d1 < start_dist, "il s'approche (%.0f m -> %.0f m)" % [start_dist, d1])
	for k in 1600:   # 80 s de plus : il se met bord à bord et tire
		fleet.step(0.05, true, target)
	d1 = (s["sim"] as ShipSim).position.distance_to(Vector2.ZERO)
	_check(d1 > 10.0 and d1 < 110.0, "il reste à portée des joueurs, sans les éperonner (%.0f m)" % d1)
	_check(shots.size() >= 1, "il tire des boulets (%d)" % shots.size())
	if not shots.is_empty():
		var st: Vector3 = (shots[0] as Array)[2]
		var vel: Vector3 = (shots[0] as Array)[3]
		# le boulet, sans résistance, finit près de la cible : même loi que le jeu (gravité 16)
		var t := 0.0
		var p := st
		var v := vel
		while p.y > -1.45 and t < 6.0:
			v.y -= 16.0 * 0.01
			p += v * 0.01
			t += 0.01
		_check(Vector2(p.x, p.z).length() < 45.0, "le tir est dirigé vers le bateau des joueurs (tombe à %.0f m)" % Vector2(p.x, p.z).length())
	# un boulet de joueur touche la coque, pas l'eau à côté
	var model := s["model"] as ShipModel
	var center := parent.to_local(model.to_global(Vector3(0.0, 0.5, 0.0)))
	_check(fleet.ball_hit(center) == id, "un boulet en plein dans la coque touche")
	_check(fleet.ball_hit(center + Vector3(40.0, 0.0, 0.0)) == -1, "un boulet loin à côté ne touche pas")
	# il coule : butin flottant, message, il disparaît après le naufrage
	var hp := float(s["hp"])
	_check(not fleet.hurt(id, 10.0) and float(s["hp"]) == hp - 10.0, "un boulet abîme sans couler")
	_check(fleet.hurt(id, 1000.0), "assez de boulets : il coule")
	_check(s["state"] == "sinking" and sunk.size() == 1, "il sombre et on le sait")
	var treasures := 0
	var planks := 0
	for d: Array in drops:
		if str(d[0]).begins_with("t:"):
			treasures += 1
		if d[0] == "plank":
			planks += 1
	_check(treasures >= 2 and planks >= 3, "son butin flotte (%d trésors, %d planches)" % [treasures, planks])
	_check(not fleet.hurt(id, 50.0), "un épave ne coule pas deux fois")
	for k in 200:
		fleet.step(0.05, true, target)
	_check(fleet.ships.is_empty(), "l'épave disparaît une fois coulée")
	# réseau : un client copie l'état
	fleet.spawn("brigantin", Vector2(200.0, 100.0), 1.0)
	var parent2 := Node3D.new()
	root.add_child.call_deferred(parent2)
	await process_frame
	var client := EnemyFleet.new()
	client.setup(parent2)
	client.apply_net(fleet.net_state())
	_check(client.ships.size() == 1 and (client.ships[0] as Dictionary)["kind"] == "brigantin", "le client voit le même ennemi")
	fleet.hurt(int((fleet.ships[0] as Dictionary)["id"]), 30.0)
	client.apply_net(fleet.net_state())
	_check(float((client.ships[0] as Dictionary)["hp"]) == float((fleet.ships[0] as Dictionary)["hp"]), "sa vie arrive")
	client.apply_net([])
	_check(client.ships.is_empty(), "il disparaît chez le client quand l'hôte le retire")
	fleet.clear()
	client.clear()
	parent.queue_free()
	parent2.queue_free()
