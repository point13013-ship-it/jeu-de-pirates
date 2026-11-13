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
	# 13/11 : au calme la musique respire : du silence au début de la partie, puis le thème de mer entre tout doucement
	m.update(0.1, "mer")
	_check(m.current() == "", "début de partie : d'abord le silence")
	for i in int(GameConfig.MUSIC_FIRST_GAP_MAX * 10.0) + 5:
		m.update(0.1, "mer")
	_check(m.current() == "mer", "puis le thème de mer")
	_check(m._swell < 0.7, "il entre bas (montée %.2f)" % m._swell)
	for i in int(GameConfig.MUSIC_SWELL_TIME * 10.0) + 5:
		m._cut_at = INF
		m.update(0.1, "mer")
	_check(m._swell > 0.99, "et monte jusqu'à son volume")
	m._cut_at = m._played   # un morceau écourté s'éteint, puis le silence
	m.update(0.1, "mer")
	_check(m.current() == "" and m._gap >= GameConfig.MUSIC_GAP_MIN, "morceau écourté : fondu, puis un long silence")
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
	_check(m.current() == "", "après %.0f s de calme : le combat s'éteint, silence" % GameConfig.MUSIC_COMBAT_EXIT)
	for i in int(GameConfig.MUSIC_CHANGE_GAP_MAX * 10.0) + 5:
		m.update(0.1, "mer")
	_check(m.current() == "mer", "puis le thème de mer revient")
	m.update(0.1, "escale")
	_check(m.current() == "", "on accoste : la mer s'éteint, pas d'enchaînement immédiat")
	for i in int(GameConfig.MUSIC_CHANGE_GAP_MAX * 10.0) + 5:
		m.update(0.1, "escale")
	_check(m.current() == "escale", "puis le thème d'escale")
	var first := String(m._last_file.get("escale", ""))
	m._switch_to("escale", 0.1, 0.1)
	_check(String(m._last_file.get("escale", "")) != first, "jamais deux fois de suite le même morceau")
	m.queue_free()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)
