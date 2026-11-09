extends SceneTree
## Tests de l'équipage squelette des bateaux ennemis : les canons vides sont rechargés par les canonniers (tonneau, puis canon),
## un canon vidé ne se recharge pas tout seul, deux canonniers ne prennent pas le même canon, le masque réseau est fidèle.
## Lancer : godot --headless --path . -s tests/unit/test_enemy_crew.gd

var _failed := 0


func _initialize() -> void:
	for ship_name in ["sloop", "brigantin"]:
		var model := ShipModel.new()
		_check_true("%s : chargé" % ship_name, model.load_ship(ship_name))
		root.add_child(model)
		var cannons := ShipCannons.build(model)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var crew := EnemyCrew.new()
		crew.build(model, cannons, ship_name, rng)
		_check_true("%s : des canonniers à bord" % ship_name, crew.gunners.size() >= 2)
		_check_true("%s : un timonier à la barre" % ship_name, crew.helmsman != null)
		# tout est vidé : sans canonnier, rien ne se recharge
		for i in crew.loaded.size():
			crew.loaded[i] = false
		crew.step(1.0, false)
		_check_true("%s : bateau qui coule, plus de rechargement" % ship_name, crew.mask() == 0)
		# des squelettes au travail : tout est rechargé, et jamais deux sur le même canon au même moment
		var clash := false
		var t := 0.0
		var first_load_t := -1.0
		while t < 60.0 and crew.mask() != (1 << crew.loaded.size()) - 1:
			crew.step(0.05, true)
			t += 0.05
			var seen := {}
			for g: Dictionary in crew.gunners:
				var c := int(g["cannon"])
				if c >= 0:
					if seen.has(c):
						clash = true
					seen[c] = true
			if first_load_t < 0.0 and crew.mask() != 0:
				first_load_t = t
		_check_true("%s : tous les canons rechargés" % ship_name, crew.mask() == (1 << crew.loaded.size()) - 1)
		_check_true("%s : pas de canon chargé avant d'avoir porté un boulet (au moins %.1f s)" % [ship_name, EnemyCrew.GRAB_TIME + EnemyCrew.LOAD_TIME],
				first_load_t >= EnemyCrew.GRAB_TIME + EnemyCrew.LOAD_TIME)
		_check_true("%s : jamais deux canonniers sur le même canon" % ship_name, not clash)
		# un canon qui tire se vide, puis est rechargé
		crew.fired(0)
		_check_true("%s : canon tiré = vide" % ship_name, not crew.loaded[0])
		_check_true("%s : le flanc compte ses canons chargés" % ship_name, crew.loaded_on_side(int((model.cannons[0] as Array)[2])) == crew.loaded.size() / 2 - 1)
		t = 0.0
		while t < 30.0 and not crew.loaded[0]:
			crew.step(0.05, true)
			t += 0.05
		_check_true("%s : le canon tiré est rechargé" % ship_name, crew.loaded[0])
		# le masque : un client le recopie
		var other := EnemyCrew.new()
		other.build(model, ShipCannons.build(model), ship_name, rng)
		other.apply_mask(crew.mask())
		_check_true("%s : masque réseau recopié" % ship_name, other.mask() == crew.mask())
		model.queue_free()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _check_true(what: String, cond: bool) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_failed += 1
		print("  ÉCHEC %s" % what)
