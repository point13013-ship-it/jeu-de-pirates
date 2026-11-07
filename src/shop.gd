class_name Shop
extends RefCounted
## Les règles d'une boutique (data/shops.json) : ce qui est en vente, ce que ça coûte, et l'achat lui-même.
## Deux sortes : « supply » (planches et boulets qui vont dans les réserves du profil) et « wear » (pièces de tenue
## du tailleur : payées une fois, on les remet ensuite gratuitement). Aucune interface ici : voir ShopMenu.

var title := ""
var kind := ""
var items: Array = []
var profile: Profile
var look: Dictionary           ## apparence du joueur (modifiée par un achat de tenue)


static func load_defs() -> Dictionary:
	var f := FileAccess.open("res://data/shops.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _init(p_profile: Profile, def: Dictionary, p_look: Dictionary) -> void:
	profile = p_profile
	title = str(def.get("title", "Boutique"))
	kind = str(def.get("kind", "supply"))
	items = ShipSkin.items() if kind == "skin" else def.get("items", [])
	look = p_look.duplicate(true)


static func _key(item: Dictionary) -> String:
	return "%s:%s" % [item["cat"], item["variant"]]


func _worn(item: Dictionary) -> bool:
	if kind == "ships":
		return profile.ship == str(item["ship"])
	if kind == "skin":
		return str(ShipSkin.sanitize(profile.ship_skin)[item["cat"]]) == str(item["variant"])
	return str((look.get("parts", {}) as Dictionary).get(item["cat"], "")) == str(item["variant"])


## Une ligne du menu : {label, desc, right (texte à droite), enabled}.
func row(i: int) -> Dictionary:
	var it: Dictionary = items[i]
	if kind == "ships":
		if _worn(it):
			return {"label": str(it["label"]), "desc": str(it["desc"]), "right": "ton bateau", "enabled": false}
		if profile.ships.has(str(it["ship"])):
			return {"label": str(it["label"]), "desc": str(it["desc"]), "right": "prendre", "enabled": true}
		return {"label": str(it["label"]), "desc": str(it["desc"]), "right": "%d or" % int(it["price"]), "enabled": profile.gold >= int(it["price"])}
	if kind == "skin":
		var label := ShipSkin.label_of(str(it["cat"]), str(it["variant"]))
		var cat_label := ShipSkin.category_label(str(it["cat"]))
		if _worn(it):
			return {"label": label, "desc": cat_label, "right": "posé", "enabled": false}
		if int(it["price"]) == 0 or profile.owned.has(_key(it)):
			return {"label": label, "desc": cat_label, "right": "poser", "enabled": true}
		return {"label": label, "desc": cat_label, "right": "%d or" % int(it["price"]), "enabled": profile.gold >= int(it["price"])}
	if kind == "wear":
		var label := PirateLook.variant_label(str(it["cat"]), str(it["variant"]))
		var cat_label := str(PirateLook.catalog().get("parts", {}).get(it["cat"], {}).get("label", it["cat"]))
		if _worn(it):
			return {"label": label, "desc": cat_label, "right": "porté", "enabled": false}
		if profile.owned.has(_key(it)):
			return {"label": label, "desc": cat_label, "right": "porter", "enabled": true}
		return {"label": label, "desc": cat_label, "right": "%d or" % int(it["price"]), "enabled": profile.gold >= int(it["price"])}
	var stock := str(it["stock"])
	var full: bool = int(profile.get(stock)) + int(it["qty"]) > int(it["max"])
	return {"label": str(it["label"]), "desc": str(it["desc"]), "right": "%d or" % int(it["price"]), "enabled": not full and profile.gold >= int(it["price"])}


## Réserves affichées en bas du menu.
func stock_text() -> String:
	if kind != "supply":
		return ""
	return "En réserve : %d planches, %d boulets" % [profile.planks, profile.balls]


## Achète (ou remet) l'article `i`. Renvoie {ok, msg, look_changed}.
func activate(i: int) -> Dictionary:
	var it: Dictionary = items[i]
	if kind == "ships":
		return _activate_ship(it)
	if kind == "skin":
		return _activate_skin(it)
	if kind == "wear":
		return _activate_wear(it)
	var stock := str(it["stock"])
	if int(profile.get(stock)) + int(it["qty"]) > int(it["max"]):
		return {"ok": false, "msg": "Ta cale est déjà pleine de ça.", "look_changed": false}
	if profile.gold < int(it["price"]):
		return {"ok": false, "msg": "Pas assez d'or.", "look_changed": false}
	profile.gold -= int(it["price"])
	profile.set(stock, int(profile.get(stock)) + int(it["qty"]))
	profile.save()
	return {"ok": true, "msg": "Acheté : %s" % str(it["label"]), "look_changed": false}


## Chantier naval : on achète un bateau une fois, puis on le prend (ou le reprend) gratuitement. Le jeu change de
## bateau si `ship_changed` est vrai (`ship` : son identifiant).
func _activate_ship(it: Dictionary) -> Dictionary:
	var id := str(it["ship"])
	if _worn(it):
		return {"ok": false, "msg": "C'est déjà ton bateau.", "look_changed": false, "ship_changed": false}
	if not profile.ships.has(id):
		if profile.gold < int(it["price"]):
			return {"ok": false, "msg": "Pas assez d'or.", "look_changed": false, "ship_changed": false}
		profile.gold -= int(it["price"])
		profile.ships.append(id)
	profile.ship = id
	profile.save()
	return {"ok": true, "msg": "Ton bateau : %s" % str(it["label"]), "look_changed": false, "ship_changed": true, "ship": id}


## Voilerie : on paie une fois, on repose ensuite gratuitement. Le skin posé est celui du profil.
func _activate_skin(it: Dictionary) -> Dictionary:
	var key := _key(it)
	var label := ShipSkin.label_of(str(it["cat"]), str(it["variant"]))
	if _worn(it):
		return {"ok": false, "msg": "C'est déjà posé.", "look_changed": false, "skin_changed": false}
	if int(it["price"]) > 0 and not profile.owned.has(key):
		if profile.gold < int(it["price"]):
			return {"ok": false, "msg": "Pas assez d'or.", "look_changed": false, "skin_changed": false}
		profile.gold -= int(it["price"])
		profile.owned.append(key)
	var skin := ShipSkin.sanitize(profile.ship_skin)
	skin[it["cat"]] = str(it["variant"])
	profile.ship_skin = skin
	profile.save()
	return {"ok": true, "msg": "Posé : %s" % label, "look_changed": false, "skin_changed": true}


func _activate_wear(it: Dictionary) -> Dictionary:
	var key := _key(it)
	var label := PirateLook.variant_label(str(it["cat"]), str(it["variant"]))
	if _worn(it):
		return {"ok": false, "msg": "Tu portes déjà ça.", "look_changed": false}
	if not profile.owned.has(key):
		if profile.gold < int(it["price"]):
			return {"ok": false, "msg": "Pas assez d'or.", "look_changed": false}
		profile.gold -= int(it["price"])
		profile.owned.append(key)
	# la pièce qu'on quitte reste à nous : on pourra la remettre sans payer
	var current := str((look["parts"] as Dictionary).get(it["cat"], "none"))
	var old_key := "%s:%s" % [it["cat"], current]
	if current != "none" and not profile.owned.has(old_key):
		profile.owned.append(old_key)
	(look["parts"] as Dictionary)[it["cat"]] = str(it["variant"])
	profile.save()
	return {"ok": true, "msg": "Tu enfiles : %s" % label, "look_changed": true}
