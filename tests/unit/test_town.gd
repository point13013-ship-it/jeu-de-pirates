extends SceneTree
## Tests de la ville : marcher sur la terrasse de la taverne, monter ses marches, entrer, monter l'escalier
## jusqu'à la galerie ; ne pas pouvoir sauter d'un étage à l'autre ; chaque PNJ et chaque chemin de promeneur est
## sur un sol praticable ; les quêtes de livraison de bout en bout.
## Lancer : godot --headless --path . -s tests/unit/test_town.gd

var _failed := 0


func _initialize() -> void:
	var land := _load_land()
	_test_walk(land)
	_test_npcs(land)
	_test_quests()
	_test_buying()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f != null else {}


func _load_land() -> Land:
	var land := Land.new()
	land.load_meta(_json("res://assets/models/port/port_meta.json"))
	land.load_town(_json("res://data/town.json"))
	return land


## Marche de `from` (x, y du fichier du port) vers `to` par petits pas ; renvoie (x, y, hauteur) à l'arrivée ou
## au blocage. Le monde de jeu est (x, -y).
func _walk(land: Land, from: Vector3, to: Vector2) -> Vector3:
	var pos := Vector2(from.x, -from.y)
	var h := from.z
	var goal := Vector2(to.x, -to.y)
	for i in 2000:
		var d := goal - pos
		if d.length() < 0.03:
			break
		var r := land.step(pos, d.normalized() * minf(0.05, d.length()), h)
		var np := Vector2(r.x, r.y)
		if np.distance_to(pos) < 0.0005:
			break   # bloqué
		pos = np
		h = r.z
	return Vector3(pos.x, -pos.y, h)


func _test_walk(land: Land) -> void:
	# du pavé de la place, par les marches du milieu, sur la terrasse, puis par la porte dans la salle
	var on_street := _walk(land, Vector3(-11.0, 18.0, 0.0), Vector2(-11.0, 19.0))
	_check_near("sur la place, au sol", on_street.z, 0.0)
	var up_steps := _walk(land, on_street, Vector2(-11.0, 22.0))
	_check_near("les marches mènent à la terrasse (hauteur 0,45)", up_steps.z, 0.45)
	_check_true("on arrive sur la terrasse", up_steps.y > 21.9)
	var door := _walk(land, up_steps, Vector2(-11.0, 24.6))
	_check_true("on passe la porte", door.y > 24.4)
	_check_near("dans la salle, à hauteur du sol", door.z, 0.45)
	_check_eq("la salle est un intérieur", land.interior_at(Vector2(door.x, -door.y)), 0)
	_check_eq("la terrasse n'en est pas un", land.interior_at(Vector2(-11.0, -22.0)), -1)
	# dans la salle on peut revenir dehors par la porte
	var back := _walk(land, door, Vector2(-11.0, 21.5))
	_check_true("et ressortir par la porte", back.y < 21.7 and back.z > 0.4)
	# l'escalier mène à la galerie
	var foot := _walk(land, door, Vector2(-5.5, 24.8))
	_check_near("au pied de l'escalier", foot.z, 0.45)
	var top := _walk(land, foot, Vector2(-5.5, 31.0))
	_check_near("en haut de l'escalier : la galerie (3,5 m)", top.z, 3.5)
	_check_true("on est à la galerie", top.y > 30.5)
	# et en redescendant
	var down := _walk(land, top, Vector2(-5.5, 24.8))
	_check_near("on redescend au sol de la salle", down.z, 0.45)
	# on ne saute pas d'un étage à l'autre : depuis la salle, tout droit vers la galerie, on est arrêté
	var blocked := _walk(land, Vector3(-8.5, 28.0, 0.45), Vector2(-8.5, 32.0))
	_check_true("sous la galerie, on passe au sol", blocked.y > 31.0 and blocked.z < 0.5)
	var on_gallery := _walk(land, top, Vector2(-8.5, 32.0))
	_check_near("sur la galerie, on reste à l'étage", on_gallery.z, 3.5)
	# la terrasse n'est accessible que par les marches
	var side := _walk(land, Vector3(-15.0, 19.5, 0.0), Vector2(-15.0, 23.0))
	_check_true("pas de passage direct sur la terrasse par le côté", side.y < 20.4 and side.z < 0.1)
	# le bar est un obstacle, le comptoir aussi côté salle
	var bar := _walk(land, Vector3(-13.0, 29.8, 0.45), Vector2(-13.0, 33.0))
	_check_true("le comptoir arrête", bar.y < 31.5)
	_test_relief(land)
	_test_shops(land)
	# marches de côté
	var west := _walk(land, Vector3(-20.5, 22.4, 0.0), Vector2(-17.0, 22.4))
	_check_near("marches de l'ouest : on monte", west.z, 0.45)
	var east := _walk(land, Vector3(-4.0, 22.4, 0.45), Vector2(-2.0, 22.4))
	_check_near("marches de l'est : on descend", east.z, 0.0)


func _test_npcs(land: Land) -> void:
	var cfg := _json("res://data/npcs.json")
	var seen := {}
	for d: Dictionary in cfg["npcs"]:
		seen[d["id"]] = true
		var p := Vector2(float(d["pos"][0]), -float(d["pos"][1]))
		_check_near("%s : sol praticable à sa hauteur" % d["id"], land.walk_height(p, float(d["h"])), float(d["h"]))
	_check_eq("les 10 habitants sont là (l'armurier s'ajoute)", seen.size(), 10)
	for w: Dictionary in cfg["wanderers"]:
		var path: Array = w["path"]
		var ok := true
		for i in path.size():
			var a := Vector2(float(path[i][0]), -float(path[i][1]))
			var b := Vector2(float(path[(i + 1) % path.size()][0]), -float(path[(i + 1) % path.size()][1]))
			var n := int(a.distance_to(b) / 0.4) + 1
			for k in n + 1:
				if land.walk_height(a.lerp(b, float(k) / float(n)), 0.0) != 0.0:
					ok = false
		_check_true("promeneur %s : son chemin est libre" % w["id"], ok)


func _test_quests() -> void:
	var profile := Profile.new()
	profile.persistent = false
	var log := QuestLog.new(profile)
	_check_true("quêtes lues", log.defs.size() >= 2)
	var generic := ["Bonjour."]
	_check_eq("un passant dit ses phrases ordinaires", log.talk("passant", generic)["lines"], generic)
	var t := log.talk("barnabe", generic)
	_check_eq("le tavernier propose le tonnelet", t["offer"], "tonnelet")
	_check_true("sa proposition a plusieurs phrases", (t["lines"] as Array).size() >= 2)
	_check_eq("on ne peut pas rendre ce qu'on n'a pas", log.complete("tonnelet"), 0)
	_check_true("accepter donne la phrase de remise", not log.accept("tonnelet").is_empty())
	_check_eq("la quête est en cours", log.state_of("tonnelet"), "active")
	_check_true("accepter deux fois ne fait rien", log.accept("tonnelet").is_empty())
	_check_eq("le tavernier rappelle la quête", log.talk("barnabe", generic)["offer"], "")
	var turn := log.talk("mathurin", generic)
	_check_eq("le charpentier prend la livraison", turn["turn_in"], "tonnelet")
	_check_true("le suivi parle de la quête", log.tracker_text().contains("Mathurin") or log.tracker_text().contains("tonnelet"))
	_check_eq("récompense versée", log.complete("tonnelet"), 40)
	_check_eq("l'or est dans le profil", profile.gold, 40)
	_check_eq("la quête est rendue", log.state_of("tonnelet"), "done")
	_check_eq("elle ne se rend pas deux fois", log.complete("tonnelet"), 0)
	_check_eq("le tavernier a une phrase de fin", log.talk("barnabe", generic)["lines"], log.defs["tonnelet"]["done"])
	_check_eq("le suivi est vide", log.tracker_text(), "")
	_check_eq("l'autre quête reste proposée", log.talk("ysolde", generic)["offer"], "lettre")
	log.accept("lettre")
	_check_eq("la voilière prend la lettre", log.talk("ariane", generic)["turn_in"], "lettre")
	_check_eq("65 pièces", log.complete("lettre"), 65)
	_check_eq("or total", profile.gold, 105)
	_check_eq("le veilleur des remparts propose la longue-vue", log.talk("hector", generic)["offer"], "longue_vue")
	log.accept("longue_vue")
	_check_eq("Pétronille la reçoit", log.talk("petronille", generic)["turn_in"], "longue_vue")
	_check_eq("80 pièces", log.complete("longue_vue"), 80)
	_check_eq("or total avec la longue-vue", profile.gold, 185)
	# aucune quête ne renvoie à un PNJ qui n'existe pas
	var cfg := _json("res://data/npcs.json")
	var ids := {}
	for d: Dictionary in cfg["npcs"]:
		ids[d["id"]] = true
	for id: String in log.defs:
		_check_true("quête %s : donneur et destinataire existent" % id, ids.has(log.defs[id]["giver"]) and ids.has(log.defs[id]["target"]))


func _check_true(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)


func _check_eq(name: String, got: Variant, want: Variant) -> void:
	if got == want:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s : obtenu %s, attendu %s" % [name, str(got), str(want)])


func _check_near(name: String, got: float, want: float) -> void:
	if absf(got - want) < 0.01:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s : obtenu %f, attendu %f" % [name, got, want])


## Les achats : provisions du Magasin Général, tenues du tailleur, réserves du profil.
func _test_buying() -> void:
	var defs := Shop.load_defs()
	var npc_ids := {}
	for d: Dictionary in _json("res://data/npcs.json")["npcs"]:
		npc_ids[d["id"]] = true
	for id: String in defs:
		_check_true("boutique %s : son vendeur existe" % id, npc_ids.has(id))
	for it: Dictionary in defs["gaspard"]["items"]:
		_check_true("tailleur : %s/%s existe dans le catalogue" % [it["cat"], it["variant"]], PirateLook.variants(str(it["cat"])).has(str(it["variant"])))
	var profile := Profile.new()
	profile.persistent = false
	profile.gold = 100
	var store := Shop.new(profile, defs["petronille"], PirateLook.default_look())
	_check_true("une planche s'achète", bool(store.activate(0)["ok"]))
	_check_eq("planches en réserve", profile.planks, Profile.START_PLANKS + 1)
	_check_eq("or après la planche", profile.gold, 92)
	_check_true("une caisse de boulets s'achète", bool(store.activate(3)["ok"]))
	_check_eq("boulets en réserve", profile.balls, Profile.START_BALLS + 6)
	_check_eq("or après la caisse", profile.gold, 65)
	profile.planks = 12
	var full := store.activate(0)
	_check_true("pas plus que la cale ne peut porter", not bool(full["ok"]) and profile.gold == 65 and profile.planks == 12)
	profile.gold = 0
	_check_true("sans or, rien ne s'achète", not bool(store.activate(2)["ok"]) and profile.balls == Profile.START_BALLS + 6)
	_check_true("prendre une planche la retire de la réserve", profile.take_supply("plank") and profile.planks == 11)
	profile.balls = 0
	_check_true("sans boulet on ne peut pas en prendre", not profile.take_supply("ball"))
	# tailleur
	profile.gold = 100
	var look := PirateLook.default_look()
	look["parts"]["hat"] = "none"
	var tailor := Shop.new(profile, defs["gaspard"], look)
	var idx := {}
	for i in tailor.items.size():
		idx["%s:%s" % [tailor.items[i]["cat"], tailor.items[i]["variant"]]] = i
	var r := tailor.activate(idx["hat:tricorn"])
	_check_true("le tricorne s'achète et se porte", bool(r["ok"]) and bool(r["look_changed"]) and tailor.look["parts"]["hat"] == "tricorn")
	_check_eq("or après le tricorne", profile.gold, 40)
	_check_true("la tenue du joueur d'origine n'a pas bougé", look["parts"]["hat"] == "none")
	tailor.activate(idx["hat:bandana"])
	_check_eq("or après le bandana", profile.gold, 20)
	var again := tailor.activate(idx["hat:tricorn"])
	_check_true("on remet une pièce possédée gratuitement", bool(again["ok"]) and profile.gold == 20 and tailor.look["parts"]["hat"] == "tricorn")
	_check_true("on ne rachète pas ce qu'on porte", not bool(tailor.activate(idx["hat:tricorn"])["ok"]))
	profile.gold = 0
	_check_true("sans or, pas de tenue", not bool(tailor.activate(idx["hat:straw"])["ok"]) and tailor.look["parts"]["hat"] == "tricorn")
	# la pièce quittée reste à nous
	profile.gold = 100
	var look2 := PirateLook.default_look()
	look2["parts"]["hat"] = "cap"
	var tailor2 := Shop.new(profile, defs["gaspard"], look2)
	tailor2.activate(idx["hat:bicorn"])
	_check_true("le calot qu'on portait est à nous", profile.owned.has("hat:cap"))
	# chantier naval : bateaux
	profile.gold = 200
	var yard := Shop.new(profile, defs["mathurin"], PirateLook.default_look())
	_check_eq("on commence avec le sloop", profile.ships, ["sloop"])
	_check_true("le sloop est déjà le bateau du joueur", not bool(yard.activate(0)["ok"]))
	_check_true("sans l'or, pas de galion", not bool(yard.activate(2)["ok"]) and profile.ship == "sloop" and profile.gold == 200)
	var rb := yard.activate(1)
	_check_true("le brigantin s'achète et devient le bateau", bool(rb["ok"]) and bool(rb["ship_changed"]) and rb["ship"] == "brigantin" and profile.ship == "brigantin")
	_check_eq("or après le brigantin", profile.gold, 50)
	_check_true("on reprend le sloop gratuitement", bool(yard.activate(0)["ok"]) and profile.gold == 50 and profile.ship == "sloop")
	_check_true("et le brigantin sans repayer", bool(yard.activate(1)["ok"]) and profile.gold == 50)
	for it: Dictionary in defs["mathurin"]["items"]:
		var f := FileAccess.file_exists("res://assets/models/ship/%s.glb" % it["ship"])
		_check_true("chantier : le modèle %s existe" % it["ship"], f)
	# voilerie : skins de bateau
	var sails := Shop.new(profile, defs["ariane"], PirateLook.default_look())
	var sidx := {}
	for i in sails.items.size():
		sidx["%s:%s" % [sails.items[i]["cat"], sails.items[i]["variant"]]] = i
	_check_eq("skin d'origine : voiles naturelles", ShipSkin.sanitize(profile.ship_skin)["sail"], "natural")
	_check_true("d'origine : rien à poser", not bool(sails.activate(sidx["sail:natural"])["ok"]))
	profile.gold = 60
	var rs := sails.activate(sidx["sail:red"])
	_check_true("les voiles carmin s'achètent et se posent", bool(rs["ok"]) and bool(rs["skin_changed"]) and profile.ship_skin["sail"] == "red")
	_check_eq("or après les voiles", profile.gold, 10)
	_check_true("on revient à la toile gratuitement", bool(sails.activate(sidx["sail:natural"])["ok"]) and profile.gold == 10)
	_check_true("et on remet les carmin sans repayer", bool(sails.activate(sidx["sail:red"])["ok"]) and profile.gold == 10)
	_check_true("sans or, pas de coque neuve", not bool(sails.activate(sidx["hull:navy"])["ok"]) and ShipSkin.sanitize(profile.ship_skin)["hull"] == "ebony")
	_check_eq("un skin inconnu retombe sur l'origine", ShipSkin.sanitize({"sail": "nimporte"})["sail"], "natural")
	var ov := ShipSkin.overrides({"sail": "red", "hull": "ebony", "flag": "black"})
	_check_true("les voiles rouges teintent les trois toiles", ov.has("sail") and ov.has("sail_d") and ov.has("sail_p") and not ov.has("hull"))
	_check_true("le ton foncé est plus sombre que le principal", (ov["sail_d"] as Color).r < (ov["sail"] as Color).r)


## Les boutiques (tailleur, magasin général, voilerie) : on entre par la porte, on est dans l'intérieur de la
## boutique, le comptoir arrête, on ressort par la porte.
func _test_shops(land: Land) -> void:
	# [boutique, abscisse de la porte, y dans la rue, y dedans, abscisse du comptoir, y de sa face avant]
	for c: Array in [["tailleur", -26.0, 4.5, 10.0, -26.0, 11.6], ["magasin", -12.5, 4.5, 10.0, -12.5, 11.4], ["voilerie", 3.5, 22.5, 27.0, 6.3, 28.4]]:
		var idx := -1
		for i in land.interiors.size():
			if land.interiors[i]["id"] == c[0]:
				idx = i
		_check_true("%s : l'intérieur existe" % c[0], idx >= 0)
		var inside := _walk(land, Vector3(float(c[1]), float(c[2]), 0.0), Vector2(float(c[1]), float(c[3])))
		_check_true("%s : on entre par la porte" % c[0], inside.y > float(c[3]) - 0.2)
		_check_eq("%s : on est dans son intérieur" % c[0], land.interior_at(Vector2(inside.x, -inside.y)), idx)
		_check_near("%s : de plain-pied" % c[0], inside.z, 0.0)
		var aligned := _walk(land, inside, Vector2(float(c[4]), float(c[3])))
		var at_counter := _walk(land, aligned, Vector2(float(c[4]), float(c[5]) + 2.5))
		_check_true("%s : le comptoir arrête" % c[0], at_counter.y < float(c[5]) + 0.1)
		var out := _walk(land, inside, Vector2(float(c[1]), float(c[2])))
		_check_true("%s : on ressort par la porte" % c[0], out.y < float(c[3]) - 3.0)


## Le relief du reste de la ville : parvis de la batterie, jardin en terrasses, remparts par les ruelles à escaliers.
func _test_relief(land: Land) -> void:
	var p1 := _walk(land, Vector3(36.5, 14.5, 0.0), Vector2(36.5, 20.5))
	_check_near("parvis de la batterie : on monte par les marches du sud (1,5 m)", p1.z, 1.5)
	_check_true("parvis : on y est", p1.y > 20.4)
	var p2 := _walk(land, Vector3(29.5, 22.3, 0.0), Vector2(36.0, 22.3))
	_check_near("parvis : marches de l'ouest", p2.z, 1.5)
	var p3 := _walk(land, p1, Vector2(36.5, 14.5))
	_check_near("on redescend du parvis", p3.z, 0.0)
	var p4 := _walk(land, Vector3(30.0, 19.0, 0.0), Vector2(36.0, 19.0))
	_check_true("parvis : pas de passage direct par le côté", p4.z < 0.1 and p4.x < 33.0)
	var g1 := _walk(land, Vector3(-37.0, 14.8, 0.0), Vector2(-37.0, 19.0))
	_check_near("jardin en terrasses : par les marches du sud (0,8 m)", g1.z, 0.8)
	var g2 := _walk(land, Vector3(-31.0, 18.9, 0.0), Vector2(-34.5, 18.9))
	_check_near("jardin : marches de l'est", g2.z, 0.8)
	var r1 := _walk(land, Vector3(-31.0, 35.5, 0.0), Vector2(-31.0, 48.0))
	_check_near("remparts : la ruelle à escaliers monte à 2,4 m", r1.z, 2.4)
	_check_true("remparts : on y arrive", r1.y > 47.5)
	var r2 := _walk(land, r1, Vector2(0.0, 48.0))
	_check_near("remparts : on s'y promène de plain-pied", r2.z, 2.4)
	_check_true("remparts : sur toute la longueur", r2.x > -0.1)
	var r3 := _walk(land, Vector3(-5.0, 47.0, 2.4), Vector2(-5.0, 35.5))
	_check_near("on redescend par l'autre ruelle", r3.z, 0.0)
	var r4 := _walk(land, Vector3(-24.0, 35.5, 0.0), Vector2(-24.0, 48.0))
	_check_true("pas d'accès aux remparts à travers un bâtiment", r4.y < 37.0 and r4.z < 0.1)
	var r5 := _walk(land, Vector3(3.0, 47.0, 2.4), Vector2(3.0, 52.0))
	_check_true("le parapet de la mer n'est pas franchi", r5.y < 51.6)
