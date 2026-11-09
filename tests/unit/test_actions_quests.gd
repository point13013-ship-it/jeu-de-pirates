extends SceneTree
## Tests des animations de tir et de pouvoir du pirate (feuilles présentes, catalogue, lecture une seule fois puis retour au
## repos) et du journal de quêtes (une carte par quête, états, pied de page).
## Lancer : godot --headless --path . -s tests/unit/test_actions_quests.gd

var _failed := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	var cat := PirateLook.catalog()
	for a: String in PirateSprite.ACTION_FPS:
		_check(cat["anims"].has(a) and int(cat["anims"][a]) >= 3, "%s : dans le catalogue (%s images)" % [a, str(cat["anims"].get(a, "?"))])
		var dir := PirateSprite.SHEET_DIR + a
		_check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)) and ResourceLoader.exists(dir + "/hands-bare.skin.png"), "%s : feuilles dessinées" % a)
	for w in ["pistolet", "tromblon", "fusil", "sabre"]:
		_check(cat["parts"]["weapon"]["layers"].has(w), "arme « %s » dans le catalogue" % w)
		_check(ResourceLoader.exists(PirateSprite.SHEET_DIR + "%s_%s/weapon-%s.metal.png" % ["slash" if w == "sabre" else "shoot", w, w]), "arme « %s » : feuille du canon" % w)
	_check(not cat["order"].has("weapon"), "l'arme n'est pas dans l'apparence éditable du joueur")
	# lecture d'une action : une fois, puis retour au repos
	var sprite := PirateSprite.new()
	root.add_child(sprite)
	# (pas de rendu en mode sans écran : on met des feuilles vides à la bonne taille, la composition est vue en jeu)
	for a: String in PirateSprite.ACTION_FPS:
		sprite._textures[a] = ImageTexture.create_from_image(Image.create(64 * int(cat["anims"][a]), 72 * 8, false, Image.FORMAT_RGBA8))
	sprite._textures["idle"] = ImageTexture.create_from_image(Image.create(64 * 4, 72 * 8, false, Image.FORMAT_RGBA8))
	await process_frame
	sprite.play_action("shoot_pistolet", Vector2(1, 0))
	_check(sprite.anim == "shoot_pistolet" and sprite.direction == 2, "tir vers l'est : bonne animation et direction")
	var frames_seen: Dictionary = {}
	for k in 60:
		sprite.drive(0.02, Vector2.ZERO, false, false, Vector2.ZERO)
		frames_seen[sprite.frame % 3] = true
		if sprite.anim != "shoot_pistolet":
			break
	_check(frames_seen.size() == 3, "les trois images du tir sont jouées")
	_check(sprite.anim == "idle", "après le tir, retour au repos")
	sprite.play_action("cast", Vector2(0, 1))
	_check(sprite.anim == "cast" and sprite.direction == 0, "pouvoir lancé face à la caméra")
	sprite.free()
	# le journal de quêtes
	var p := Profile.new()
	p.persistent = false
	var q := QuestLog.new(p)
	var panel := QuestPanel.new()
	root.add_child(panel)
	await process_frame
	panel.open(q, func(id: String) -> String: return id)
	_check(panel.is_open() and panel._list.get_child_count() == 1, "journal vide : un message")
	var ids := q.defs.keys()
	p.quests[ids[0]] = "active"
	p.quests[ids[1]] = "done"
	panel.open(q, func(id: String) -> String: return id)
	await process_frame
	_check(panel._list.get_child_count() == 3, "une quête en cours, un séparateur, une terminée (%d)" % panel._list.get_child_count())
	_check("En cours : 1" in panel._footer.text and "Terminées : 1" in panel._footer.text, "pied de page : " + panel._footer.text)
	panel.close()
	_check(not panel.is_open(), "le journal se ferme")
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)
