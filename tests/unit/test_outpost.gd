extends SceneTree
## Tests de la capture d'île et de la cabane : une île n'est vaincue que sans ennemi vivant ni coffre fermé ; une île capturée ne
## se repeuple plus ; la capture et la cabane se retiennent dans le profil (et se relisent) ; le coffre de la cabane range et
## rend les trésors ; la cabane trouve une place plate, sur la terre, loin du décor ; elle coûte des planches.
## Lancer : godot --headless --path . -s tests/unit/test_outpost.gd

var _failed := 0


func _initialize() -> void:
	_test_cleared()
	_test_held_stays_empty()
	_test_profile()
	_test_stash()
	_test_spots()
	_test_recipe()
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


func _profile() -> Profile:
	var p := Profile.new()
	p.persistent = false   # (jamais écraser la vraie sauvegarde)
	return p


## Tue tous les ennemis de l'île `i` et ouvre tous ses coffres.
func _clear(w: IslandWorld, i: int) -> void:
	for en_id: int in (w.islands[i] as Dictionary)["enemies"]:
		w.enemies[en_id].hurt(9999, Vector2.ZERO, 0.0)
	for ch_id: int in (w.islands[i] as Dictionary)["chests"]:
		w.open_chest(ch_id)


func _test_cleared() -> void:
	var w := _world()
	var i := -1
	for k in w.islands.size():
		if not (w.islands[k] as Dictionary)["enemies"].is_empty() and not (w.islands[k] as Dictionary)["chests"].is_empty():
			i = k
			break
	_check(i >= 0, "il y a une île avec des ennemis et des coffres")
	if i < 0:
		return
	_check(not w.is_cleared(i), "une île intacte n'est pas vaincue")
	for en_id: int in (w.islands[i] as Dictionary)["enemies"]:
		w.enemies[en_id].hurt(9999, Vector2.ZERO, 0.0)
	_check(not w.is_cleared(i), "ennemis battus mais coffres fermés : pas vaincue")
	for ch_id: int in (w.islands[i] as Dictionary)["chests"]:
		w.open_chest(ch_id)
	_check(w.is_cleared(i), "ennemis battus et coffres ouverts : vaincue")


func _test_held_stays_empty() -> void:
	var w := _world()
	var i := 0
	_clear(w, i)
	var id := str((w.islands[i] as Dictionary)["id"])
	w.held[id] = true
	for en_id: int in (w.islands[i] as Dictionary)["enemies"]:
		w.enemies[en_id].timer = 0.0
	for ch_id: int in (w.islands[i] as Dictionary)["chests"]:
		(w.chests[ch_id] as Dictionary)["timer"] = 0.0
	w.step(1.0, [])   # personne alentour : sans capture, tout reviendrait
	_check(w.enemies_alive(i) == 0, "île capturée : les ennemis ne reviennent pas")
	_check(w.chests_left(i) == 0, "île capturée : les coffres restent ouverts")
	var w2 := _world()
	_clear(w2, i)
	for en_id: int in (w2.islands[i] as Dictionary)["enemies"]:
		w2.enemies[en_id].timer = 0.0
	w2.step(1.0, [])
	_check(w2.enemies_alive(i) > 0, "île non capturée : les ennemis reviennent (témoin du test)")


func _test_profile() -> void:
	var p := _profile()
	_check(not Outpost.is_captured(p, "crabes"), "rien de capturé au départ")
	_check(Outpost.capture(p, "crabes"), "première capture : vrai")
	_check(not Outpost.capture(p, "crabes"), "seconde capture : faux (déjà prise)")
	_check(Outpost.is_captured(p, "crabes"), "l'île est capturée")
	_check(not Outpost.has_cabin(p, "crabes") and Outpost.cabin_pos(p, "crabes") == Vector2.INF, "pas de cabane au départ")
	Outpost.build_cabin(p, "crabes", Vector2(112.5, 141.0))
	_check(Outpost.has_cabin(p, "crabes"), "la cabane est bâtie")
	_check(Outpost.cabin_pos(p, "crabes").is_equal_approx(Vector2(112.5, 141.0)), "la cabane garde sa place")
	# aller-retour par le JSON (ce que fait save/load)
	var back: Variant = JSON.parse_string(JSON.stringify({"captured": p.captured, "cabins": p.cabins}))
	var q := _profile()
	q.captured = (back as Dictionary)["captured"]
	q.cabins = (back as Dictionary)["cabins"]
	_check(Outpost.is_captured(q, "crabes") and Outpost.cabin_pos(q, "crabes").is_equal_approx(Vector2(112.5, 141.0)), "capture et cabane survivent à l'enregistrement")


func _test_stash() -> void:
	var p := _profile()
	var tk := "t:" + str((Treasure.defs()[0] as Dictionary)["id"])
	var bk := "b:" + str(BerryBook.all().keys()[0])
	_check(Outpost.deposit(p, "crabes", "plank", 5) == 0, "sans cabane : on ne range rien")
	Outpost.build_cabin(p, "crabes", Vector2.ZERO)
	_check(Outpost.items_of(p, "crabes").is_empty() and Outpost.stash_text(p, "crabes").contains("vide"), "coffre neuf : vide")
	_check(Outpost.withdraw(p, "crabes", "plank", 5) == 0, "coffre vide : rien à reprendre")
	_check(Outpost.deposit(p, "crabes", "n_importe_quoi", 1) == 0, "un objet inconnu est refusé")
	_check(Outpost.deposit(p, "crabes", "t:inconnu", 1) == 0, "un trésor inconnu est refusé")
	_check(Outpost.deposit(p, "crabes", "plank", 0) == 0 and Outpost.deposit(p, "crabes", "plank", -3) == 0, "une quantité nulle ou négative est refusée")
	# on y met de tout : trésor, baie, planches, boulets, munitions, or
	_check(Outpost.deposit(p, "crabes", tk, 1) == 1, "on range un trésor")
	_check(Outpost.deposit(p, "crabes", bk, 2) == 2, "… des baies")
	_check(Outpost.deposit(p, "crabes", "plank", 20) == 20 and Outpost.deposit(p, "crabes", "plank", 5) == 5, "… des planches (en deux fois)")
	for k: String in ["ball", "bullets", "shells", "gold"]:
		_check(Outpost.deposit(p, "crabes", k, 7) == 7, "… et « %s »" % k)
	_check(Outpost.count_of(p, "crabes", "plank") == 25, "les planches s'additionnent")
	_check(Outpost.items_of(p, "crabes").size() == 7, "sept sortes d'objets dans le coffre")
	_check(Outpost.stash_text(p, "crabes").contains("25 Planches"), "le texte donne les quantités")
	# reprendre : jamais plus que ce qu'il y a
	_check(Outpost.withdraw(p, "crabes", "plank", 10) == 10 and Outpost.count_of(p, "crabes", "plank") == 15, "on reprend dix planches")
	_check(Outpost.withdraw(p, "crabes", "plank", 99) == 15 and Outpost.count_of(p, "crabes", "plank") == 0, "… puis ce qui reste, pas plus")
	_check(not Outpost.items_of(p, "crabes").has("plank"), "une ligne vide disparaît")
	_check(Outpost.withdraw(p, "crabes", tk, 1) == 1 and Outpost.withdraw(p, "crabes", tk, 1) == 0, "un trésor ne se reprend qu'une fois")
	_check(Outpost.items_of(p, "autre").is_empty(), "le coffre d'une autre île est vide")
	# le coffre est partagé : l'état part chez les invités et s'y lit à l'identique
	var guest := _profile()
	Outpost.import_state(guest, Outpost.export_state(p))
	_check(Outpost.count_of(guest, "crabes", "gold") == 7 and Outpost.count_of(guest, "crabes", bk) == 2, "l'invité voit le contenu du coffre")
	_check(Outpost.cabin_pos(guest, "crabes") == Outpost.cabin_pos(p, "crabes"), "… et la cabane au même endroit")
	Outpost.deposit(guest, "crabes", "gold", 1)
	_check(Outpost.count_of(p, "crabes", "gold") == 7, "la copie de l'invité est indépendante de l'originale")
	_check(Outpost.step_of("gold") > Outpost.step_of(tk) and Outpost.step_of(tk) == 1, "l'or se range par paquets, les trésors un par un")


func _test_spots() -> void:
	var w := _world()
	for i in w.islands.size():
		var isl: Dictionary = w.islands[i]
		var name := str(isl["name"])
		var f := Outpost.flag_pos(w, i)
		_check(w.sdf(i, f) > 0.0, "%s : le drapeau est sur la terre ferme" % name)
		var spot := Outpost.cabin_spot(w, i, f)
		if spot == Vector2.INF:
			continue   # une toute petite île peut ne pas avoir de place : la partie le dit au joueur
		_check(w.sdf(i, spot) >= Outpost.CABIN_HALF + 0.6, "%s : la cabane est à l'intérieur des terres" % name)
		_check(spot.distance_to(f) >= 1.5, "%s : la cabane n'écrase pas le drapeau" % name)
		for ch_id: int in isl["chests"]:
			_check(spot.distance_to((w.chests[ch_id] as Dictionary)["pos"]) >= Outpost.CABIN_HALF, "%s : la cabane n'écrase pas un coffre" % name)
		for b: Vector3 in isl["blockers_c"]:
			_check(spot.distance_to(Vector2(b.x, b.y)) >= b.z, "%s : la cabane n'écrase pas un obstacle" % name)


func _test_recipe() -> void:
	var cost := int(Crafting.cost_of("cabin").get("plank", 0))
	_check(cost > int(Crafting.cost_of("raft")["plank"]), "la cabane coûte plus cher que le radeau")
	var p := _profile()
	p.planks = cost - 1
	_check(not Crafting.can_afford(p, "cabin"), "une planche de moins : impossible")
	p.planks = cost
	_check(Crafting.pay(p, "cabin") and p.planks == 0, "le coût est retiré")
