class_name Weapons
extends RefCounted
## Les armes du pirate (data/weapons.json) : sabre, pistolet, tromblon, fusil de précision. Ici seulement les données ; le jeu
## fait partir les coups (à terre) et IslandWorld.shoot() calcule ce qu'un tir touche.

const PATH := "res://data/weapons.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_data = parsed if parsed is Dictionary else {"order": [], "weapons": {}}
	return _data


## Les identifiants des armes dans l'ordre du catalogue.
static func order() -> Array:
	return data().get("order", [])


static func get_def(id: String) -> Dictionary:
	return (data().get("weapons", {}) as Dictionary).get(id, {})


static func exists(id: String) -> bool:
	return not get_def(id).is_empty()


static func weapon_name(id: String) -> String:
	return str(get_def(id).get("name", id))


static func is_gun(id: String) -> bool:
	return str(get_def(id).get("type", "melee")) == "gun"


## Nom de la munition (« bullets », « shells ») d'une arme à feu, « » pour le sabre.
static func ammo_of(id: String) -> String:
	return str(get_def(id).get("ammo", ""))


static func ammo_label(ammo: String) -> String:
	return {"bullets": "balles", "shells": "cartouches"}.get(ammo, ammo)


## L'arme suivante dans `owned` après `current` (en boucle), pour la touche X.
static func next_owned(current: String, owned: Array) -> String:
	var ids: Array = []
	for id in order():
		if id in owned:
			ids.append(id)
	if ids.is_empty():
		return "sabre"
	var i := ids.find(current)
	return str(ids[(i + 1) % ids.size()])
