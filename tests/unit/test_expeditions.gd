extends SceneTree
## Tests des quêtes d'expédition : accepter fixe le cap sur l'île, y poser le pied passe la quête à « prête », le donneur
## (et lui seul) la récompense, et une livraison ordinaire n'est pas touchée.
## Lancer : godot --headless --path . -s tests/unit/test_expeditions.gd

var _failed := 0


func _initialize() -> void:
	var p := Profile.new()
	p.persistent = false
	var q := QuestLog.new(p)
	var islands := IslandWorld.read_json(IslandWorld.ISLANDS_PATH)
	var ids: Array = []
	for isl: Dictionary in islands["islands"]:
		ids.append(str(isl["id"]))
	var expeditions: Array = []
	for id: String in q.defs:
		if q.is_expedition(id):
			expeditions.append(id)
	_check(expeditions.size() >= 3, "au moins trois expéditions")
	for id: String in expeditions:
		_check(str(q.defs[id]["island"]) in ids, "%s : l'île existe" % id)
		_check(q.defs[id]["giver"] == q.defs[id]["target"], "%s : on revient voir le donneur" % id)
		for key in ["offer", "accepted", "active", "ready", "turn_in", "done"]:
			_check(q.defs[id].has(key), "%s : texte « %s »" % [id, key])
	var id: String = expeditions[0]
	var giver: String = q.defs[id]["giver"]
	var isl_id: String = q.defs[id]["island"]
	_check(q.current_island() == "", "aucun cap sans quête")
	_check(q.talk(giver, [])["offer"] == id, "le donneur propose l'expédition")
	q.accept(id)
	_check(q.current_island() == isl_id, "le cap est sur l'île de la quête")
	_check(q.talk(giver, [])["turn_in"] == "", "pas de récompense avant d'avoir vu l'île")
	_check(q.reach_island("autre_ile").is_empty(), "une autre île ne compte pas")
	_check(q.reach_island(isl_id) == [id], "poser le pied sur l'île accomplit l'expédition")
	_check(q.current_island() == "", "plus de cap une fois l'île atteinte")
	_check(q.reach_island(isl_id).is_empty(), "accomplie une seule fois")
	_check(q.talk(giver, [])["turn_in"] == id, "le donneur récompense au retour")
	var gold := p.gold
	_check(q.complete(id) == int(q.defs[id]["reward"]) and p.gold == gold + int(q.defs[id]["reward"]), "la récompense est versée")
	_check(q.state_of(id) == "done", "quête terminée")
	_check(q.complete(id) == 0, "on ne touche pas deux fois")
	# les livraisons ne changent pas
	var d := q.talk("barnabe", [])
	_check(d["offer"] == "tonnelet", "la livraison est toujours proposée")
	q.accept("tonnelet")
	_check(q.talk("mathurin", [])["turn_in"] == "tonnelet", "la livraison se rend au destinataire")
	_check(q.current_island() == "", "une livraison ne fixe pas de cap")
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
		print("ÉCHEC : ", what)
