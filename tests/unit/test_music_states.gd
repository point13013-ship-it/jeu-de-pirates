extends SceneTree
## Musique par état (12/11/2026) : les morceaux enregistrés sont trouvés, le combat entre tout de suite et ne s'arrête qu'après
## GameConfig.MUSIC_COMBAT_EXIT s de calme, un changement d'état lance le nouveau thème.
## Lancer : godot --headless --path . -s tests/unit/test_music_states.gd

var _failed := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  ÉCHEC ") + what)
	if not ok:
		_failed += 1


func _initialize() -> void:
	var m := Music.new()
	root.add_child(m)
	await process_frame   # (les lecteurs doivent être dans l'arbre pour jouer)
	m.start()
	for st: String in Music.STATES:
		_check(not m._files_of(st).is_empty(), "%s : %d morceau(x)" % [st, m._files_of(st).size()])
	m.update(0.1, "mer")
	_check(m.current() == "mer", "au large : thème de mer")
	m.update(0.1, "combat")
	_check(m.current() == "combat", "l'ennemi arrive : combat tout de suite")
	# combat en couches : au calme, l'accompagnement seul ; quand ça chauffe, la mélodie entre
	for i in 30:
		m.update(0.1, "combat", 1.0, 0.1)
	_check(m._top_gain < 0.05, "combat léger : mélodie absente (%.2f)" % m._top_gain)
	for i in 30:
		m.update(0.1, "combat", 1.0, 0.9)
	_check(m._top_gain > 0.95, "combat corsé : mélodie pleine (%.2f)" % m._top_gain)
	for i in 50:   # 5 s de calme
		m.update(0.1, "mer")
	_check(m.current() == "combat", "5 s après : toujours le combat (pas de va-et-vient)")
	for i in 60:   # encore 6 s
		m.update(0.1, "mer")
	_check(m.current() == "mer", "après %.0f s de calme : retour à la mer" % GameConfig.MUSIC_COMBAT_EXIT)
	m.update(0.1, "escale")
	_check(m.current() == "escale", "on accoste : thème d'escale")
	var first := String(m._last_file.get("escale", ""))
	m._switch_to("escale", 0.1, 0.1)
	_check(String(m._last_file.get("escale", "")) != first, "jamais deux fois de suite le même morceau")
	m.queue_free()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)
