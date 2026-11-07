class_name Profile
extends RefCounted
## Ce qui suit le joueur d'une partie à l'autre : son or et l'état de ses quêtes. Sauvegardé dans
## user://profil.json. `persistent` à faux : tout reste en mémoire (essais automatiques, pour ne jamais écraser
## la vraie sauvegarde).

const PATH := "user://profil.json"

var gold := 0
var quests: Dictionary = {}   ## id de quête -> "active" ou "done" (absent : pas encore proposée)
var persistent := true


func load_file() -> void:
	if not persistent:
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		gold = int((parsed as Dictionary).get("gold", 0))
		var q: Variant = (parsed as Dictionary).get("quests", {})
		quests = (q as Dictionary).duplicate() if q is Dictionary else {}


func save() -> void:
	if not persistent:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"gold": gold, "quests": quests}, "\t"))
