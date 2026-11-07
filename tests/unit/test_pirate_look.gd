extends SceneTree
## Tests de l'apparence des pirates (src/character/) : catalogue, correction, hasard reproductible, directions.
## Lancer : godot --headless --path . -s tests/unit/test_pirate_look.gd

var _failed := 0


func _initialize() -> void:
	var cat := PirateLook.catalog()
	_check_true("le catalogue est chargé", not cat.is_empty() and cat.has("order"))
	var look := PirateLook.default_look()
	_check_true("le look par défaut est valide", PirateLook.sanitize(look) == look)
	var broken := {"parts": {"hair": "inexistant", "hat": "none"}, "colors": {"skin": "pas une couleur"}}
	var fixed := PirateLook.sanitize(broken)
	_check_true("une pièce inconnue est remplacée", PirateLook.variants("hair").has(fixed["parts"]["hair"]))
	_check_true("une couleur invalide est remplacée", Color.html_is_valid(fixed["colors"]["skin"]))
	_check_true("une pièce facultative peut être retirée", fixed["parts"]["hat"] == "none")
	_check_true("même graine, même pirate", PirateLook.key(PirateLook.random_look(42)) == PirateLook.key(PirateLook.random_look(42)))
	_check_true("graines différentes, pirates différents", PirateLook.key(PirateLook.random_look(1)) != PirateLook.key(PirateLook.random_look(2)))
	var json := PirateLook.key(look)
	_check_true("aller-retour JSON", PirateLook.key(JSON.parse_string(json)) == json)
	_check_true("chaque pièce obligatoire n'a pas « none »", not PirateLook.variants("eyes").has("none"))
	_check_true("chaque pièce facultative a « none »", PirateLook.variants("hat")[0] == "none")
	for c: String in cat["order"]:
		for v: String in cat["parts"][c]["variants"]:
			_check_true("libellé de %s-%s" % [c, v], PirateLook.variant_label(c, v) != "")
	_check_true("direction : vers la caméra", PirateSprite.direction_of(Vector2(0, 1)) == 0)
	_check_true("direction : droite", PirateSprite.direction_of(Vector2(1, 0)) == 2)
	_check_true("direction : haut", PirateSprite.direction_of(Vector2(0, -1)) == 4)
	_check_true("direction : gauche", PirateSprite.direction_of(Vector2(-1, 0)) == 6)
	_check_true("direction : bas-droite", PirateSprite.direction_of(Vector2(1, 1)) == 1)
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _check_true(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)
