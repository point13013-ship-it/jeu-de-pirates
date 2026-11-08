class_name BerryBook
extends RefCounted
## Le livre des baies des dieux (data/berries.json) : nom, couleur et les 4 sorts de chaque baie.
## Un pirate ne porte qu'une baie ; ses sorts se lancent avec les touches 1 à 4.

const PATH := "res://data/berries.json"
const SLOTS := 4
const KINDS := ["bolt", "nova", "cone", "dash", "pull", "heal", "shield"]

static var _cache: Dictionary = {}


static func all() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_cache = (parsed as Dictionary).get("berries", {})
	return _cache


static func exists(id: String) -> bool:
	return all().has(id)


static func berry_name(id: String) -> String:
	return str((all().get(id, {}) as Dictionary).get("name", "?"))


static func color_of(id: String) -> Color:
	return Color.html(str((all().get(id, {}) as Dictionary).get("color", "#ffffff")))


## Le sort `slot` (0 à 3) de la baie `id`, ou un dictionnaire vide.
static func spell(id: String, slot: int) -> Dictionary:
	var spells: Array = (all().get(id, {}) as Dictionary).get("spells", [])
	if slot < 0 or slot >= spells.size():
		return {}
	return spells[slot]


## Clé qui retient qu'un sort a déjà été lancé (son nom est alors révélé).
static func spell_key(id: String, slot: int) -> String:
	return "%s:%d" % [id, slot]
