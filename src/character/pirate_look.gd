class_name PirateLook
extends RefCounted
## Apparence d'un pirate : une variante par pièce (coiffure, barbe, chapeau...) et une couleur par canal
## (peau, cheveux, yeux, manteau...). Le catalogue des pièces vient de data/character_parts.json, écrit par
## tools/art/assemble_pirate.py à partir des rendus Blender.
##
## Un « look » est un Dictionary : {"parts": {catégorie: variante ou "none"}, "colors": {canal: "#rrggbb"}}.

const CATALOG_PATH := "res://data/character_parts.json"
const SAVE_PATH := "user://pirate_look.json"

static var _catalog: Dictionary = {}


## Le catalogue des pièces (chargé une fois).
static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
		if f == null:
			push_error("character_parts.json introuvable : lancer tools/art/assemble_pirate.py")
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		_catalog = parsed if parsed is Dictionary else {}
	return _catalog


static func default_look() -> Dictionary:
	return (catalog().get("default_look", {"parts": {}, "colors": {}}) as Dictionary).duplicate(true)


## Les variantes proposées pour une catégorie, « none » en tête quand la pièce est facultative.
static func variants(category: String) -> Array:
	var part: Dictionary = catalog().get("parts", {}).get(category, {})
	var out: Array = []
	if part.get("optional", false):
		out.append("none")
	out.append_array(part.get("variants", []))
	return out


## Libellé français d'une variante (ou son identifiant s'il n'a pas de libellé).
static func variant_label(category: String, variant: String) -> String:
	if variant == "none":
		return "Aucun"
	return str(catalog().get("labels", {}).get(category, {}).get(variant, variant))


## Complète et corrige un look (pièce inconnue -> celle par défaut, couleur invalide -> celle par défaut).
static func sanitize(look: Dictionary) -> Dictionary:
	var base := default_look()
	var out := {"parts": {}, "colors": {}}
	var parts: Dictionary = look["parts"] if look.get("parts") is Dictionary else {}
	var colors: Dictionary = look["colors"] if look.get("colors") is Dictionary else {}
	for c: String in catalog().get("order", []):
		var v: String = str(parts.get(c, base["parts"].get(c, "none")))
		out["parts"][c] = v if variants(c).has(v) else str(base["parts"].get(c, "none"))
	for ch: String in catalog().get("channels", {}):
		var col: String = str(colors.get(ch, base["colors"].get(ch, "#ffffff")))
		out["colors"][ch] = col if Color.html_is_valid(col) else str(base["colors"].get(ch, "#ffffff"))
	return out


## Un look au hasard, mais reproductible : même graine, même pirate.
static func random_look(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var look := default_look()
	for c: String in catalog().get("order", []):
		var options := variants(c)
		if c == "mark":
			look["parts"][c] = "none" if rng.randf() < 0.75 else options[rng.randi_range(0, options.size() - 1)]
		elif options.size() > 0:
			look["parts"][c] = options[rng.randi_range(0, options.size() - 1)]
	var channels: Dictionary = catalog().get("channels", {})
	for ch: String in channels:
		var palette: Array = channels[ch]["palette"]
		look["colors"][ch] = palette[rng.randi_range(0, palette.size() - 1)]
	return sanitize(look)


## Clé stable d'un look (cache des textures).
static func key(look: Dictionary) -> String:
	return JSON.stringify(sanitize(look), "", true)


static func load_saved() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			return sanitize(parsed)
	return default_look()


static func save(look: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(sanitize(look), "\t", true))
