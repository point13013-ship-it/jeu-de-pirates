extends SceneTree
## Tests des skins d'armes : catalogue complet (tous en boutique), boutique de Prosper, profil, dessin de l'arme en main.
## Lancer : godot --headless --path . -s tests/unit/test_weapon_skins.gd

var _failed := 0


func _initialize() -> void:
	_test_catalog()
	_test_shop()
	_test_profile()
	_test_art()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _test_catalog() -> void:
	_check("chaque arme a au moins 4 skins", Weapons.order().all(func(w: Variant) -> bool: return WeaponSkins.ids_of(str(w)).size() >= 4))
	var shop_n := 0
	for e: Dictionary in WeaponSkins.all():
		var d := WeaponSkins.def_of(e["weapon"], e["id"])
		_check("%s : palette complète" % e["id"], d["palette"].has("metal") and d["palette"].has("wood") and d["palette"].has("accent") and d["palette"].has("glow"))
		_check("%s : style d'effet connu" % e["id"], WeaponFx.STYLES.has(str(d["fx"]["style"])))
		_check("%s : éclat connu" % e["id"], str(d["flash"]) == "none" or WeaponArt.FLASH.has(str(d["flash"])))
		if WeaponSkins.in_shop(e["weapon"], e["id"]):
			shop_n += 1
	_check("tous les skins s'achètent à la boutique", shop_n == WeaponSkins.all().size() and shop_n >= 16)
	_check("classique : prix 0 et nom", WeaponSkins.price_of("pistolet", "classique") == 0 and WeaponSkins.skin_name("pistolet", "classique") == "Classique")


func _test_shop() -> void:
	var defs := Shop.load_defs()
	_check("Prosper tient la boutique des skins", str(defs.get("prosper", {}).get("kind", "")) == "wskins")
	var p := Profile.new()
	p.persistent = false
	var shop := Shop.new(p, defs["prosper"], {})
	_check("un article par skin", shop.items.size() == WeaponSkins.all().size())
	var armory := Shop.new(p, defs["armand"], {})
	_check("l'armurerie ne vend plus de skins", armory.items.all(func(it: Variant) -> bool: return not (it as Dictionary).has("skin")))
	_check("sans l'arme, pas d'achat", not shop.activate(0)["ok"])
	p.weapons.append("pistolet")
	var idx := -1
	for i in shop.items.size():
		if shop.items[i]["skin"] == "pistolet:corail":
			idx = i
	p.gold = 10
	_check("pas assez d'or : refusé", not shop.activate(idx)["ok"] and not p.owns_skin("pistolet", "corail"))
	p.gold = 500
	_check("achat : or débité, skin posé", shop.activate(idx)["ok"] and p.gold == 500 - WeaponSkins.price_of("pistolet", "corail") and p.skin_of("pistolet") == "corail")
	p.skin_worn["pistolet"] = "classique"
	var gold := p.gold
	_check("le skin possédé se repose gratuitement", shop.activate(idx)["ok"] and p.gold == gold)


func _test_profile() -> void:
	var p := Profile.new()
	p.persistent = false
	_check("au départ : classique", p.skin_of("pistolet") == "classique" and p.skins_for("pistolet") == ["classique"])
	_check("gagner un skin le pose", p.gain_skin("pistolet:corail") and p.skin_of("pistolet") == "corail")
	_check("le même skin deux fois : refusé", not p.gain_skin("pistolet:corail"))
	p.skin_worn["fusil"] = "aurore"
	_check("un skin non possédé n'est pas posé", p.skin_of("fusil") == "classique")
	_check("les skins posables d'une arme", p.skins_for("pistolet") == ["classique", "corail"])


func _test_art() -> void:
	var ok := true
	for w in Weapons.order():
		for skin: String in ["classique"] + WeaponSkins.ids_of(str(w)):
			for anim: String in ["idle", "walk", "jump", "shoot_%s" % w, "slash_%s" % w]:
				if not PirateLook.catalog()["anims"].has(anim):
					continue
				var s := WeaponArt.sheets(str(w), skin, anim)
				if s.is_empty() or not (s["front"] is Image):
					ok = false
	_check("toutes les armes et tous les skins se dessinent", ok)
	_check("pas de dessin quand les mains sont prises", WeaponArt.sheets("pistolet", "classique", "carry_walk").is_empty())
	var s2 := WeaponArt.sheets("pistolet", "classique", "idle")
	_check("la feuille a la taille du pirate", (s2["front"] as Image).get_width() == 4 * 64 and (s2["front"] as Image).get_height() == 8 * 72)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_failed += 1
		printerr("ÉCHEC : ", label)
	else:
		print("ok : ", label)
