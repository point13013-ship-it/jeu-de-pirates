extends SceneTree
## Tests des baies des dieux : le livre est complet (4 sorts par baie, noms uniques), chaque baie du monde est sur la
## terre ferme, on ne la cueille qu'une fois, celle qu'on lâche reste hors de portée mais ramassable, les sorts
## touchent ce qu'ils doivent toucher (et seulement cela), et l'état réseau fait l'aller-retour.
## Lancer : godot --headless --path . -s tests/unit/test_berries.gd

var _failed := 0


func _initialize() -> void:
	_test_book()
	_test_spots()
	_test_pick_and_drop()
	_test_spells()
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


func _test_book() -> void:
	var all := BerryBook.all()
	_check(all.size() >= 5, "au moins cinq baies")
	var names := {}
	for id: String in all:
		var b: Dictionary = all[id]
		_check(not names.has(b["name"]), "nom de baie unique : %s" % b["name"])
		names[b["name"]] = true
		_check((b["spells"] as Array).size() == BerryBook.SLOTS, "%s : quatre sorts" % id)
		for s: Dictionary in b["spells"]:
			_check(str(s["kind"]) in BerryBook.KINDS, "%s / %s : type de sort connu" % [id, s["name"]])
			_check(float(s["cd"]) > 0.0, "%s / %s : une recharge" % [id, s["name"]])
			var k := str(s["kind"])
			if k in ["bolt", "nova", "cone", "dash", "pull"]:
				_check(int(s["damage"]) > 0, "%s / %s : fait des dégâts" % [id, s["name"]])
			if k == "heal":
				_check(int(s["amount"]) > 0, "%s / %s : soigne" % [id, s["name"]])
			if k == "shield":
				_check(float(s["secs"]) > 0.0, "%s / %s : dure un moment" % [id, s["name"]])
	_check(BerryBook.spell("inconnue", 0).is_empty() and BerryBook.spell("ignis", 9).is_empty(), "sort inexistant : vide")


func _test_spots() -> void:
	var w := _world()
	# les baies sont le plus rare des trésors : trois seulement, sur les îles dangereuses (d'autres, très rarement, sur les îles tirées au hasard)
	_check(w.berry_spots.size() == 3, "trois baies cachées dans le monde du fichier")
	var seen := {}
	for s: Dictionary in w.berry_spots:
		var i := int(s["island"])
		var p: Vector2 = s["pos"]
		var label := "%s en %s" % [s["berry"], p]
		_check(BerryBook.exists(str(s["berry"])), "baie connue : %s" % label)
		_check(w.island_at(p, 0.0) == i and w.walkable(i, p, 0.3), "baie sur la terre ferme : %s" % label)
		_check(not seen.has(p), "deux baies au même endroit : %s" % label)
		seen[p] = true
	# au moins deux îles en cachent (« sur certaines îles, une ou plusieurs »)
	var islands_with := {}
	for s: Dictionary in w.berry_spots:
		islands_with[s["island"]] = true
	_check(islands_with.size() == 3, "chaque baie est sur sa propre île")


func _test_pick_and_drop() -> void:
	var w := _world()
	var s: Dictionary = w.berry_spots[0]
	var p: Vector2 = s["pos"]
	_check(w.nearest_berry(p + Vector2(0.5, 0)) == 0, "la baie est à portée de cueillette")
	_check(w.nearest_berry(p + Vector2(6, 0)) == -1, "trop loin pour la cueillir")
	var id := w.take_berry(0)
	_check(id == str(s["berry"]), "on cueille la bonne baie")
	_check(w.take_berry(0) == "", "une baie ne se cueille qu'une fois")
	_check(w.nearest_berry(p) == -1, "une baie cueillie n'est plus cueillissable")
	# elle repousse chez l'hôte
	w.update_berries(IslandWorld.BERRY_RESPAWN + 1.0, Vector2(1.0e6, 1.0e6), true)
	_check(w.nearest_berry(p) == 0, "la baie repousse après un long moment")
	# lâcher une baie : elle tombe sur la terre, hors de portée du pirate, mais ramassable
	var me := p + Vector2(1.0, 0.0)
	var k := w.drop_berry("nyx", me)
	var d: Dictionary = w.berry_spots[k]
	_check(bool(d["dropped"]) and not d["taken"], "la baie lâchée est au sol")
	_check((d["pos"] as Vector2).distance_to(me) > IslandWorld.BERRY_REACH, "elle tombe hors de portée (pas de rechange immédiat)")
	_check(w.island_at(d["pos"], 0.0) >= 0, "elle tombe sur la terre ferme")
	_check(w.nearest_berry(d["pos"]) == k, "on peut la ramasser")
	_check(w.take_berry(k) == "nyx", "on retrouve la baie lâchée")
	_check(w.nearest_berry(d["pos"]) == -1 and bool(d["taken"]), "une baie lâchée ramassée disparaît")


func _fresh(w: IslandWorld, kind: String) -> IslandEnemy:
	for en in w.enemies:
		if str(en.kind) == kind:
			en.revive()
			en.pos = Vector2(0, 0)
			return en
	return null


func _test_spells() -> void:
	var w := _world()
	var en := _fresh(w, "crab")
	_check(en != null, "il y a un crabe pour essayer")
	if en == null:
		return
	var nova := {"kind": "nova", "radius": 3.0, "damage": 2, "knock": 2.0}
	en.pos = Vector2(2.0, 0.0)
	_check(w.cast(nova, Vector2(10, 0), Vector2.RIGHT).is_empty(), "onde : hors de portée, rien")
	var hits := w.cast(nova, Vector2(0, 0), Vector2.RIGHT)
	_check(hits.size() == 1 and bool(hits[0]["killed"]) and int(hits[0]["gold"]) > 0, "onde : tue un crabe (2 vies) et laisse de l'or")

	en = _fresh(w, "crab")
	en.pos = Vector2(5.0, 0.0)
	var bolt := {"kind": "bolt", "range": 8.0, "width": 0.6, "damage": 1}
	_check(w.cast(bolt, Vector2(0, 3.0), Vector2.RIGHT).is_empty(), "trait : à côté de la ligne, raté")
	_check(w.cast(bolt, Vector2(0, 0), Vector2.LEFT).is_empty(), "trait : derrière le lanceur, raté")
	_check(w.cast(bolt, Vector2(0, 0), Vector2.RIGHT).size() == 1, "trait : sur la ligne, touché")
	_check(w.cast(bolt, Vector2(-4.0, 0), Vector2.RIGHT).is_empty(), "trait : trop court (portée 8 m), raté")

	en = _fresh(w, "crab")
	en.pos = Vector2(2.5, 1.0)
	var cone := {"kind": "cone", "range": 4.0, "arc": 100.0, "damage": 1, "knock": 1.0}
	_check(w.cast(cone, Vector2(0, 0), Vector2.RIGHT).size() == 1, "souffle : devant, touché")
	en = _fresh(w, "crab")
	en.pos = Vector2(0.0, 3.0)
	_check(w.cast(cone, Vector2(0, 0), Vector2.RIGHT).is_empty(), "souffle : sur le côté, raté")

	en = _fresh(w, "crab")
	en.pos = Vector2(3.0, 0.3)
	var dash := {"kind": "dash", "dist": 5.0, "damage": 1}
	_check(w.cast(dash, Vector2(0, 0), Vector2.RIGHT).size() == 1, "ruée : on frappe ce qu'on traverse")
	en = _fresh(w, "crab")
	en.pos = Vector2(7.0, 0.0)
	_check(w.cast(dash, Vector2(0, 0), Vector2.RIGHT).is_empty(), "ruée : au-delà de la distance, raté")

	en = _fresh(w, "crab")
	en.pos = Vector2(4.0, 0.0)
	var pull := {"kind": "pull", "radius": 6.0, "damage": 1, "knock": -2.6}
	_check(w.cast(pull, Vector2(0, 0), Vector2.RIGHT).size() == 1, "aspiration : touche dans le rayon")
	_check(en.knock.x < 0.0, "aspiration : l'ennemi est tiré vers le lanceur, pas repoussé")

	var heal := {"kind": "heal", "amount": 3}
	_check(w.cast(heal, Vector2.ZERO, Vector2.RIGHT).is_empty(), "un soin ne blesse personne")


func _test_net() -> void:
	var a := _world()
	a.take_berry(1)
	a.drop_berry("gaia", a.berry_spots[0]["pos"] + Vector2(1.0, 0.0))
	var b := _world()
	b.apply_net(a.net_state(), true)
	_check(b.berry_spots.size() == a.berry_spots.size(), "la baie lâchée existe aussi chez les autres joueurs")
	_check(bool(b.berry_spots[1]["taken"]), "la baie cueillie l'est aussi chez les autres")
	_check(not bool(b.berry_spots[0]["taken"]), "les autres baies restent là")
	var last: Dictionary = b.berry_spots[b.berry_spots.size() - 1]
	_check(bool(last["dropped"]) and str(last["berry"]) == "gaia", "la baie lâchée garde son nom et son état")
