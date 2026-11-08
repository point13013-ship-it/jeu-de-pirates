class_name Crafting
extends RefCounted
## Fabrication : ce que le pirate peut assembler avec ce qu'il a dans le sac (data/crafting.json). Pour l'instant : le radeau à voile,
## fait de planches, pour ne jamais rester prisonnier d'une île. Le jeu (sailing_game.gd) pose l'objet fabriqué dans le monde.

const PATH := "res://data/crafting.json"
const ITEM_NAMES := {"plank": ["planche", "planches"], "ball": ["boulet", "boulets"]}

static var _cache: Dictionary = {}


static func _data() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_cache = parsed
	return _cache


## Les recettes dans l'ordre d'affichage.
static func order() -> Array:
	return (_data().get("order", []) as Array).duplicate()


static func get_def(id: String) -> Dictionary:
	var rec: Dictionary = _data().get("recipes", {})
	return rec.get(id, {})


static func recipe_name(id: String) -> String:
	return str(get_def(id).get("name", id))


## Le coût : { « plank »: 6 }.
static func cost_of(id: String) -> Dictionary:
	var c: Variant = get_def(id).get("cost", {})
	return (c as Dictionary).duplicate() if c is Dictionary else {}


## Combien le profil possède de `item` (« plank » ou « ball »).
static func have(profile: Profile, item: String) -> int:
	return profile.planks if item == "plank" else (profile.balls if item == "ball" else 0)


## Ce qui manque pour fabriquer `id` : { item: manquant }, vide si tout y est.
static func missing(profile: Profile, id: String) -> Dictionary:
	var out := {}
	var cost := cost_of(id)
	for item: String in cost:
		var lack := int(cost[item]) - have(profile, item)
		if lack > 0:
			out[item] = lack
	return out


static func can_afford(profile: Profile, id: String) -> bool:
	return not get_def(id).is_empty() and missing(profile, id).is_empty()


## Retire le coût du profil. Faux (et rien de retiré) s'il manque quelque chose.
static func pay(profile: Profile, id: String) -> bool:
	if not can_afford(profile, id):
		return false
	var cost := cost_of(id)
	for item: String in cost:
		if item == "plank":
			profile.planks -= int(cost[item])
		elif item == "ball":
			profile.balls -= int(cost[item])
	profile.save()
	return true


## « 6 planches », « 1 planche et 2 boulets ».
static func cost_text(id: String) -> String:
	var parts: Array = []
	var cost := cost_of(id)
	for item: String in cost:
		var n := int(cost[item])
		var names: Array = ITEM_NAMES.get(item, [item, item])
		parts.append("%d %s" % [n, names[0] if n == 1 else names[1]])
	return " et ".join(parts)
