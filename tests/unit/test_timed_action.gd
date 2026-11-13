extends SceneTree
## Tests des actions longues (lot 2, règle commune) : durée réglée, avancement, interruption si l'on bouge, si l'on glisse trop
## loin ou si l'on prend un coup, et les deux temps de l'écopage.
## Lancer : godot --headless --path . -s tests/unit/test_timed_action.gd

var _failed := 0


func _initialize() -> void:
	_check("durée de l'ancre : 2,5 à 3,5 s (12/11 : -20 %)", TimedAction.duration_of("anchor") >= 2.5 and TimedAction.duration_of("anchor") <= 3.5)
	_check("durée d'une réparation : 2 à 3 s", TimedAction.duration_of("repair") >= 2.0 and TimedAction.duration_of("repair") <= 3.0)
	_check("durée d'un seau : environ 1,2 s (13/11 : écope plus vive)", absf(TimedAction.duration_of("bail") - 1.2) < 0.3)
	_check("durée pour relever un allié : 4 s", is_equal_approx(TimedAction.duration_of("revive"), 4.0))
	# une action menée jusqu'au bout
	var a := TimedAction.create("anchor", "Lever l'ancre", 3.5, Vector2(1, 2))
	var done := false
	var frames := 0
	while not done and frames < 1000:
		done = a.step(1.0 / 60.0, Vector2(1, 2), false, false)
		frames += 1
	_check("l'ancre se lève en 3,5 s (%d images)" % frames, done and absf(frames / 60.0 - 3.5) < 0.05)
	_check("… et ne s'arrête qu'une fois", not a.step(0.1, Vector2(1, 2), false, false))
	# interruptions
	var b := TimedAction.create("repair", "", 2.5, Vector2.ZERO)
	b.step(0.5, Vector2.ZERO, false, false)
	b.step(0.1, Vector2.ZERO, true, false)
	_check("appuyer sur une direction l'interrompt", b.cancelled and not b.done)
	var c := TimedAction.create("repair", "", 2.5, Vector2.ZERO)
	c.step(0.5, Vector2(0.05, 0.0), false, false)
	_check("le pont qui tangue (petit glissement) ne l'interrompt pas", not c.cancelled)
	c.step(0.1, Vector2(0.5, 0.0), false, false)
	_check("s'éloigner l'interrompt", c.cancelled)
	var d := TimedAction.create("revive", "", 4.0, Vector2.ZERO)
	d.step(1.0, Vector2.ZERO, false, true)
	_check("un coup reçu l'interrompt", d.cancelled)
	# écopage : remplir puis vider
	var e := TimedAction.create("bail", "", 1.5, Vector2.ZERO)
	e.step(0.3, Vector2.ZERO, false, false)
	_check("au début on remplit le seau", e.bail_phase() == "fill")
	e.step(0.9, Vector2.ZERO, false, false)
	_check("ensuite on le vide", e.bail_phase() == "pour")
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)
