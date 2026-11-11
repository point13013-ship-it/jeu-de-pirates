class_name WeaponSkins
extends RefCounted
## Les apparences (skins) des armes (data/weapon_skins.json) : couleurs, forme, geste de tir, éclat de bouche et effets du monde.
## Un skin s'identifie par « arme:id » (ex. « pistolet:flibustier ») ; « classique » est l'arme d'origine. Ils s'achètent à l'armurerie
## avec l'or des coffres ; le profil garde ceux qu'on possède et celui qu'on a posé sur chaque arme.

const PATH := "res://data/weapon_skins.json"
const CLASSIC := "classique"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_data = parsed if parsed is Dictionary else {"rarities": {}, "defaults": {}, "skins": {}}
	return _data


static func _skins_of(weapon: String) -> Dictionary:
	return (data().get("skins", {}) as Dictionary).get(weapon, {})


## Les identifiants des skins d'une arme (sans « classique »), dans l'ordre du fichier.
static func ids_of(weapon: String) -> Array:
	return _skins_of(weapon).keys()


static func exists(weapon: String, skin: String) -> bool:
	return skin == CLASSIC or _skins_of(weapon).has(skin)


static func key(weapon: String, skin: String) -> String:
	return "%s:%s" % [weapon, skin]


## Tous les skins d'un seul tenant : [{weapon, id}].
static func all() -> Array:
	var out: Array = []
	for w in Weapons.order():
		for id in ids_of(str(w)):
			out.append({"weapon": str(w), "id": str(id)})
	return out


## La définition complète d'un skin : l'arme d'origine avec, par-dessus, ce que le skin change.
static func def_of(weapon: String, skin: String) -> Dictionary:
	var base: Dictionary = ((data().get("defaults", {}) as Dictionary).get(weapon, {}) as Dictionary).duplicate(true)
	if skin != CLASSIC and _skins_of(weapon).has(skin):
		var over: Dictionary = _skins_of(weapon)[skin]
		for k: String in over:
			if k == "palette":
				var pal: Dictionary = base.get("palette", {}).duplicate()
				pal.merge(over["palette"], true)
				base["palette"] = pal
			else:
				base[k] = over[k]
	else:
		base["name"] = "Classique"
		base["rarity"] = "commun"
		base["price"] = 0
		base["source"] = ""
	return base


static func skin_name(weapon: String, skin: String) -> String:
	return str(def_of(weapon, skin).get("name", skin))


static func rarity_label(weapon: String, skin: String) -> String:
	return str((data().get("rarities", {}) as Dictionary).get(str(def_of(weapon, skin).get("rarity", "commun")), {}).get("label", ""))


static func rarity_color(weapon: String, skin: String) -> Color:
	var hex := str((data().get("rarities", {}) as Dictionary).get(str(def_of(weapon, skin).get("rarity", "commun")), {}).get("color", "#ffffff"))
	return Color.html(hex)


static func price_of(weapon: String, skin: String) -> int:
	return int(def_of(weapon, skin).get("price", 0))


static func in_shop(weapon: String, skin: String) -> bool:
	return str(def_of(weapon, skin).get("source", "")) == "shop" and price_of(weapon, skin) > 0


