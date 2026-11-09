class_name IslandLore
extends RefCounted
## Les textes des trouvailles des îles (data/lore.json) : un message en bouteille, un journal de pirate, un naufragé.
## Le choix se fait d'après la graine de l'objet : le même pour tous les joueurs, d'une partie à l'autre.

const PATH := "res://data/lore.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = IslandWorld.read_json(PATH)
	return _data


static func _pick(list: Array, seed_value: int) -> Dictionary:
	if list.is_empty():
		return {}
	return list[absi(hash(seed_value * 31 + 7)) % list.size()]


## Le message de la bouteille : {title, lines, map (bool), gold}. `target_name` : l'île d'un message « map » (nom), ou "" si aucune.
static func bottle(seed_value: int, target_name: String) -> Dictionary:
	var d := data()
	var entry := _pick(d.get("bottles", []), seed_value)
	var lines: Array = (entry.get("lines", []) as Array).duplicate()
	var is_map := bool(entry.get("map", false))
	if is_map and target_name == "":
		# plus d'île à révéler : on choisit un message ordinaire
		var plain: Array = []
		for e: Dictionary in d.get("bottles", []):
			if not bool(e.get("map", false)):
				plain.append(e)
		entry = _pick(plain, seed_value)
		lines = (entry.get("lines", []) as Array).duplicate()
		is_map = false
	if is_map:
		for k in lines.size():
			lines[k] = str(lines[k]) % target_name if "%s" in str(lines[k]) else lines[k]
	return {"title": str(d.get("bottle_title", "Message dans une bouteille")), "lines": lines, "map": is_map,
			"gold": _gold(d.get("bottle_gold", [0, 0]), seed_value)}


static func journal(seed_value: int) -> Dictionary:
	var d := data()
	var entry := _pick(d.get("journals", []), seed_value)
	return {"title": str(d.get("journal_title", "Journal de bord")), "lines": entry.get("lines", []), "map": false,
			"gold": _gold(d.get("journal_gold", [0, 0]), seed_value + 5)}


## Le naufragé : {name, lines, look_parts}.
static func castaway(seed_value: int) -> Dictionary:
	var d := data()
	var names: Array = d.get("castaway_names", ["Naufragé"])
	var lines: Array = d.get("castaway_lines", [["Bonjour."]])
	var hats: Array = d.get("castaway_hat", ["straw"])
	var beards: Array = d.get("castaway_beard", ["long"])
	var h := absi(hash(seed_value * 17 + 3))
	return {"name": str(names[h % names.size()]), "lines": lines[(h / 3) % lines.size()],
			"parts": {"hat": str(hats[(h / 5) % hats.size()]), "beard": str(beards[(h / 7) % beards.size()])}}


static func _gold(range_value: Array, seed_value: int) -> int:
	var lo := int(range_value[0])
	var hi := int(range_value[1])
	if hi <= lo:
		return lo
	return lo + absi(hash(seed_value * 13 + 1)) % (hi - lo + 1)
