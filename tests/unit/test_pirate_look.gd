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
	_test_palette_flood()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


## Bug 1.4 : la palette « pirates » du filtre saturée par d'anciens looks (éditeur de personnage, aperçus) ne doit plus faire
## perdre ses couleurs au pirate du joueur quand il change de tenue ou d'arme : elle est refaite à partir des pirates affichés.
func _test_palette_flood() -> void:
	for i in 80:   # beaucoup d'essais dans l'éditeur : avant, la palette restait pleine pour toute la partie
		PirateSprite.register_colors(PirateLook.random_look(1000 + i))
	_check_true("(la palette est remplie par les essais : %d couleurs)" % PirateSprite.palette_colors.size(), PirateSprite.palette_colors.size() >= 300)
	var me := PirateSprite.new()
	me.palette_first = true
	var npc := PirateSprite.new()
	npc.look = PirateLook.random_look(7)
	var look := PirateLook.random_look(4242)
	look["colors"]["skin"] = "#000000"
	look["colors"]["shirt"] = "#123456"
	me.look = PirateLook.sanitize(look)   # (sans set_look : pas de feuilles à composer dans un test sans écran)
	me.held_weapon = "sabre"
	me.held_skin = "cerisier"
	PirateSprite._palette_dirty = true
	_check_true("la palette est refaite après un changement", PirateSprite.refresh_palette())
	var missing := 0
	var cat := PirateLook.catalog()
	for c: String in cat["order"]:
		for lay: Dictionary in cat["parts"][c]["layers"].get(me.look["parts"][c], []):
			var spec: String = lay["color"]
			var tint := Color.html(spec if spec.begins_with("#") else me.look["colors"][spec])
			for t: float in cat.get("tones", [1.0]):
				var col := PirateSprite.shade(tint, roundf(t * 255.0) / 255.0)
				if not PirateSprite.palette_colors.has(Color.from_rgba8(col.r8, col.g8, col.b8)):
					missing += 1
	_check_true("toutes les couleurs de mon pirate sont dans la palette (manquantes : %d)" % missing, missing == 0)
	for c: Color in WeaponArt.colors_of("sabre", "cerisier"):
		if not PirateSprite.palette_colors.has(Color.from_rgba8(c.r8, c.g8, c.b8)):
			missing += 1
	_check_true("… et celles de mon arme et de son skin", missing == 0)
	_check_true("les vieux looks d'essai n'y sont plus (palette petite)", PirateSprite.palette_colors.size() < 200)
	npc.free()
	me.free()
	PirateSprite.refresh_palette()
	_check_true("un pirate disparu libère ses couleurs", PirateSprite.palette_colors.is_empty())


func _check_true(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)
