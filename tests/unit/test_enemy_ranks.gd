extends SceneTree
## Lot 5 : rangs des navires ennemis (résistance, rareté, bateau), réparations limitées par les planches, révélation sur la carte,
## et soins des mobs. Sans affichage (la flotte n'a pas de nœud racine : pas de modèles).
## Lancer : godot --headless --path . -s tests/unit/test_enemy_ranks.gd

var _failed := 0


func _initialize() -> void:
	var fleet := EnemyFleet.new()
	# résistance : +25 % et plus selon le rang
	var id1 := fleet.spawn("sloop", Vector2(500, 500), 0.0, -1, 1)
	var id4 := fleet.spawn("galion", Vector2(800, 500), 0.0, -1, 4)
	var s1: Dictionary = fleet.ships[fleet.find(id1)]
	var s4: Dictionary = fleet.ships[fleet.find(id4)]
	_check("rang 1 : coque +25 %% (%.0f)" % float(s1["hp"]), is_equal_approx(float(s1["hp"]), 70.0 * 1.25))
	_check("rang 4 : bien plus résistant (%.0f)" % float(s4["hp"]), float(s4["hp"]) > float(s1["hp"]) * 3.0)
	_check("ennemis plus lents (vitesse max %.1f)" % (s1["sim"] as ShipSim).max_speed, (s1["sim"] as ShipSim).max_speed < 9.0 * 0.82)
	# rareté : sur 4000 tirages, le rang 4 est rare et le rang 1 le plus courant
	var counts := [0, 0, 0, 0, 0]
	for k in 4000:
		counts[fleet._roll_rank()] += 1
	_check("rang 1 le plus courant (%d)" % counts[1], counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > counts[4])
	_check("rang 4 rare (%d / 4000)" % counts[4], counts[4] < 400 and counts[4] > 50)
	# réparations : seulement au calme, et pas plus que les planches
	fleet.hurt(id1, 40.0)
	var hp_hit := float(s1["hp"])
	fleet._survive(s1, 1.0)
	_check("pas de réparation juste après un coup", is_equal_approx(float(s1["hp"]), hp_hit))
	for k in 200:
		fleet._survive(s1, 0.5)
	var repaired := float(s1["hp"]) - hp_hit
	_check("au calme, l'équipage répare (+%.0f)" % repaired, repaired > 0.0)
	_check("… autant de planches qu'il en a (2 au rang 1)", repaired <= 2.0 * GameConfig.ENEMY_REPAIR_HP + 0.01 and int(s1["planks"]) == 0)
	# révélation sur la carte
	_check("pas révélé au départ", fleet.revealed().is_empty())
	fleet.reveal(id4)
	_check("révélé quand il nous touche", fleet.revealed().size() == 1)
	s4["reveal_t"] = 0.0
	_check("… puis caché après le délai", fleet.revealed().is_empty())
	# soins d'un mob : blessé et à l'écart, il mange une ration
	var cfg := {"hp": 10, "speed": 1.0, "aggro": 5.0, "leash": 10.0, "reach": 1.0, "windup": 0.5, "damage": 1, "cooldown": 1.0, "scale": 1.0, "gold": [1, 2]}
	var mob := IslandEnemy.create(1, "skeleton", 0, Vector2.ZERO, cfg)
	mob.wander_t = 1000.0   # (il ne se promène pas : le monde du test est vide)
	mob.hp = 2
	var world := IslandWorld.new()
	for k in 10:
		mob.step(0.5, [], world, RandomNumberGenerator.new())
	_check("le mob blessé s'est soigné (PV %d)" % mob.hp, mob.hp > 2 and mob.food == GameConfig.MOB_FOOD - 1)
	mob.hp = 2
	mob.food = 0
	mob.wander_t = 1000.0   # (il ne se promène pas : le monde du test est vide)
	mob.wander_to = mob.pos
	for k in 10:
		mob.step(0.5, [], world, RandomNumberGenerator.new())
	_check("sans ration, il ne se soigne plus", mob.hp == 2)
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)
