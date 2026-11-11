extends SceneTree
## Tests : armes principale/secondaire (clic gauche/droit), pseudo, taille de l'interface, pointe de l'étrave (on n'y tombe pas).
## Lancer : godot --headless --path . -s tests/unit/test_controls_pseudo.gd

var _failed := 0


func _initialize() -> void:
	_test_weapons()
	_test_pseudo()
	_test_display()
	_test_bow()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _test_weapons() -> void:
	var p := Profile.new()
	p.persistent = false
	_check("une seule arme : la secondaire est la principale", p.secondary_weapon() == "sabre")
	p.weapons.append("pistolet")
	_check("sans choix : la première autre arme", p.secondary_weapon() == "pistolet")
	p.set_secondary_weapon("pistolet")
	_check("pistolet en secondaire", p.weapon == "sabre" and p.secondary_weapon() == "pistolet")
	p.set_main_weapon("pistolet")
	_check("prendre la secondaire en principale les échange", p.weapon == "pistolet" and p.secondary_weapon() == "sabre")
	p.set_secondary_weapon("pistolet")
	_check("mettre la principale en secondaire les échange", p.weapon == "sabre" and p.secondary_weapon() == "pistolet")
	p.set_secondary_weapon("fusil")
	_check("une arme non possédée est refusée", p.secondary_weapon() == "pistolet")
	p.weapons.erase("pistolet")
	_check("secondaire perdue : retour à l'arme principale", p.secondary_weapon() == "sabre")


func _test_pseudo() -> void:
	_check("espaces retirés", PlayerName.clean("  Jack  ") == "Jack")
	_check("longueur limitée", PlayerName.clean("ABCDEFGHIJKLMNOPQRSTUVWXYZ").length() == PlayerName.MAX_LENGTH)
	_check("caractères de contrôle retirés", PlayerName.clean("Ja\nck\t") == "Jack")
	_check("pseudo vide accepté", PlayerName.clean("   ") == "")
	PlayerName.path = "user://pseudo_test.json"
	PlayerName.set_name_value("Barbe Rouge")
	_check("pseudo gardé", PlayerName.value == "Barbe Rouge")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerName.path))


func _test_display() -> void:
	DisplaySettings.path = "user://affichage_test.json"
	DisplaySettings.set_hud_scale(5.0)
	_check("échelle de l'interface bornée en haut", is_equal_approx(DisplaySettings.hud_scale, DisplaySettings.HUD_MAX))
	DisplaySettings.set_hud_scale(0.1)
	_check("échelle de l'interface bornée en bas", is_equal_approx(DisplaySettings.hud_scale, DisplaySettings.HUD_MIN))
	DisplaySettings.set_hud_scale(1.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DisplaySettings.path))


## Partout où l'on peut marcher sur le pont compte comme coque : jamais de chute sans saut, même à la pointe de l'étrave.
func _test_bow() -> void:
	for name in ["sloop", "brigantin", "galion"]:
		var ship := ShipModel.new()
		if not ship.load_ship(name):
			_check("%s : modèle chargé" % name, false)
			continue
		var bad := 0
		var x := -ship.length * 0.5
		while x <= ship.bow_x:
			var y := -ship.beam * 0.5
			while y <= ship.beam * 0.5:
				var q := Vector2(x, y)
				if ship.is_walkable(q) and not ship.over_hull(q):
					bad += 1
				y += 0.05
			x += 0.05
		_check("%s : tout point de marche est sur la coque (%d écarts)" % [name, bad], bad == 0)
		ship.free()


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  ÉCHEC %s" % label)
