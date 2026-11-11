class_name PlayerName
extends RefCounted
## Le pseudo du joueur : choisi dans le menu principal, gardé dans user://pseudo.json (à part du profil : remettre la
## progression à zéro ne l'efface pas) et affiché en petit au-dessus de son pirate, chez lui comme chez les autres joueurs.

const PATH := "user://pseudo.json"
const MAX_LENGTH := 16
static var path := PATH   ## (les essais le détournent pour ne pas toucher au vrai pseudo)

static var value := ""
static var _loaded := false


## Lit le pseudo gardé (une seule fois).
static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		value = clean(str((data as Dictionary).get("name", "")))


## Change et garde le pseudo.
static func set_name_value(v: String) -> void:
	_loaded = true
	value = clean(v)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"name": value}, "\t"))


## Un pseudo propre : sans espaces aux bouts ni caractères de contrôle, pas plus de MAX_LENGTH caractères.
static func clean(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var code := raw.unicode_at(i)
		if code >= 32 and code != 127:
			out += raw[i]
	return out.strip_edges().substr(0, MAX_LENGTH)
