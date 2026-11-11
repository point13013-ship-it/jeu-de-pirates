extends SceneTree
## Tests de la réputation : rangs, gains, déblocage des skins de bateau à la voilerie.
## Lancer : godot --headless --path . -s tests/unit/test_reputation.gd

var _failed := 0


func _initialize() -> void:
	_test_ranks()
	_test_profile()
	_test_shop()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _test_ranks() -> void:
	_check("0 point : premier rang", Reputation.rank_of(0) == 0 and Reputation.rank_name(0) == "Mousse")
	_check("seuil exact : rang atteint", Reputation.rank_of(Reputation.points_for(3)) == 3)
	_check("juste sous le seuil : rang précédent", Reputation.rank_of(Reputation.points_for(3) - 1) == 2)
	_check("au-delà du dernier seuil : rang max", Reputation.is_max(99999))
	_check("progression à mi-chemin", absf(Reputation.progress((Reputation.points_for(1) + Reputation.points_for(2)) / 2) - 0.5) < 0.05)
	_check("les seuils montent", Reputation.points_for(2) > Reputation.points_for(1) and Reputation.points_for(6) > Reputation.points_for(5))
	_check("les gains existent", Reputation.gain("quest") > 0.0 and Reputation.gain("enemy_ship") > 0.0 and Reputation.gain("treasure_per_gold") > 0.0)


func _test_profile() -> void:
	var p := Profile.new()
	p.persistent = false
	_check("rien gagné : rien à animer", p.add_reputation(0).is_empty() and p.reputation == 0)
	var info := p.add_reputation(Reputation.points_for(1))
	_check("passage de rang annoncé", int(info["rank_from"]) == 0 and int(info["rank_to"]) == 1 and p.rank() == 1)
	var info2 := p.add_reputation(1)
	_check("gain sans changement de rang", int(info2["rank_from"]) == int(info2["rank_to"]) and int(info2["to"]) == p.reputation)


func _test_shop() -> void:
	var defs := Shop.load_defs()
	var p := Profile.new()
	p.persistent = false
	var shop := Shop.new(p, defs["ariane"], {})
	var idx := -1
	var low := -1
	for i in shop.items.size():
		if shop.items[i]["cat"] == "figurehead" and shop.items[i]["variant"] == "dragon":
			idx = i
		if shop.items[i]["cat"] == "sail" and shop.items[i]["variant"] == "natural":
			low = i
	_check("la proue dragon est au catalogue, réservée à un rang", idx >= 0 and int(shop.items[idx]["rank"]) > 0)
	_check("verrouillée sans la réputation", not shop.row(idx)["enabled"] and not shop.activate(idx)["ok"])
	_check("un skin libre reste posable", low >= 0 and shop.row(low)["right"] != "")
	p.reputation = Reputation.points_for(int(shop.items[idx]["rank"]))
	_check("débloquée au bon rang", shop.row(idx)["enabled"])
	var res := shop.activate(idx)
	_check("posée gratuitement une fois débloquée", res["ok"] and ShipSkin.sanitize(p.ship_skin)["figurehead"] == "dragon" and p.gold == 0)
	_check("chaque rang a au moins une récompense sauf les deux premiers", not ShipSkin.unlocked_at(2).is_empty() and not ShipSkin.unlocked_at(6).is_empty())
	for m: String in ["dragon", "lion", "eagle", "goldskull"]:
		_check("modèle de proue %s présent" % m, ResourceLoader.exists("res://assets/models/ship/figurehead_%s.glb" % m))


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  ÉCHEC %s" % label)
