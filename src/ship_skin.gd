class_name ShipSkin
extends RefCounted
## L'apparence d'un bateau : une variante par catégorie (voiles, coque, pavillon), décrites dans
## data/ship_skins.json. Un « skin » est un Dictionary {catégorie: id de variante}. Il se pose sur le modèle en
## remplaçant la couleur des matières nommées du glb (« sail », « hull »…) ; la première variante de chaque
## catégorie est celle du modèle d'origine (aucune couleur).

const PATH := "res://data/ship_skins.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_data = parsed if parsed is Dictionary else {"order": [], "categories": {}}
	return _data


static func _variants(cat: String) -> Array:
	return (data()["categories"] as Dictionary).get(cat, {}).get("variants", [])


static func default_variant(cat: String) -> String:
	var v := _variants(cat)
	return str(v[0]["id"]) if not v.is_empty() else ""


static func default_skin() -> Dictionary:
	var out := {}
	for cat: String in data()["order"]:
		out[cat] = default_variant(cat)
	return out


## Corrige un skin reçu ou chargé : catégorie manquante ou variante inconnue -> celle d'origine.
static func sanitize(skin: Dictionary) -> Dictionary:
	var out := default_skin()
	for cat: String in out:
		var id := str(skin.get(cat, ""))
		for v: Dictionary in _variants(cat):
			if v["id"] == id:
				out[cat] = id
	return out


## Tous les articles de la voilerie : [{cat, variant, price}], dans l'ordre du catalogue.
static func items() -> Array:
	var out: Array = []
	for cat: String in data()["order"]:
		for v: Dictionary in _variants(cat):
			out.append({"cat": cat, "variant": v["id"], "price": int(v["price"])})
	return out


static func label_of(cat: String, variant: String) -> String:
	for v: Dictionary in _variants(cat):
		if v["id"] == variant:
			return str(v["label"])
	return variant


static func category_label(cat: String) -> String:
	return str((data()["categories"] as Dictionary).get(cat, {}).get("label", cat))


## Les couleurs à poser : nom de matière -> couleur, pour les catégories qui ne sont pas d'origine.
static func overrides(skin: Dictionary) -> Dictionary:
	var out := {}
	var cats: Dictionary = data()["categories"]
	for cat: String in data()["order"]:
		for v: Dictionary in _variants(cat):
			if v["id"] != skin.get(cat, "") or not v.has("color"):
				continue
			var base := Color.html(str(v["color"]))
			var mats: Dictionary = cats[cat]["mats"]
			for m: String in mats:
				var f := float(mats[m])
				out[m] = Color(clampf(base.r * f, 0.0, 1.0), clampf(base.g * f, 0.0, 1.0), clampf(base.b * f, 0.0, 1.0))
	return out


## Pose le skin sur un modèle de bateau (idempotent : on peut en changer à volonté).
static func apply(root: Node, skin: Dictionary) -> void:
	var over := overrides(sanitize(skin))
	var touched: Dictionary = {}
	for cat: String in data()["order"]:
		for m: String in (data()["categories"] as Dictionary)[cat]["mats"]:
			touched[m] = true
	var cache := {}
	_apply_rec(root, over, touched, cache)


static func _apply_rec(node: Node, over: Dictionary, touched: Dictionary, cache: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null or not touched.has(mat.resource_name):
				continue
			if over.has(mat.resource_name):
				var key: String = mat.resource_name
				if not cache.has(key):
					var dup := mat.duplicate() as BaseMaterial3D
					dup.albedo_color = over[key]
					cache[key] = dup
				mi.set_surface_override_material(s, cache[key])
			else:
				mi.set_surface_override_material(s, null)
	for c in node.get_children():
		_apply_rec(c, over, touched, cache)
