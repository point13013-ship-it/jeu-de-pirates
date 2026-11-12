extends SceneTree
## Tests des voiles : la hauteur d'une voile se lit dans son nom (seuls les chiffres juste après « sail_z »), et sur les trois
## bateaux aucune voile n'est lue plus haut que le mât (sinon elle s'envole quand on cargue : bug du second foc, 13/11/2026).
## Lancer : godot --headless --path . -s tests/unit/test_sails.gd

var _failed := 0


func _initialize() -> void:
	_check_near("nom simple", ShipModel.sail_top("sail_z661"), 6.61)
	_check_near("nom avec suffixe", ShipModel.sail_top("sail_z873_jib"), 8.73)
	_check_near("suffixe avec un chiffre", ShipModel.sail_top("sail_z743_jib2"), 7.43)
	_check_near("rustine", ShipModel.sail_top("sail_z1008_patcha"), 10.08)
	for ship_name in ["sloop", "brigantin", "galion"]:
		var ship := ShipModel.new()
		_check_true("%s : chargé" % ship_name, ship.load_ship(ship_name))
		var max_h := float(ship.meta.get("max_height", 12.0))
		for e: Dictionary in ship._sails:
			var n := String((e["node"] as Node).name)
			_check_true("%s : %s lue à %.2f, sous le haut du mât (%.2f)" % [ship_name, n, float(e["top"]), max_h],
					float(e["top"]) > 0.5 and float(e["top"]) <= max_h + 0.01)
		ship.free()
	print("RÉSULTAT : %d échec(s)" % _failed)
	quit(1 if _failed > 0 else 0)


func _check_true(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)


func _check_near(name: String, got: float, want: float) -> void:
	_check_true("%s : %.2f (attendu %.2f)" % [name, got, want], absf(got - want) < 0.005)
