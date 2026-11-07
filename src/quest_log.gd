class_name QuestLog
extends RefCounted
## Les quêtes de livraison : un PNJ confie un objet, le joueur le porte à un autre PNJ, qui le récompense en or.
## Toute l'histoire est dans data/quests.json. L'état (proposée, en cours, rendue) vit dans le profil du joueur.

const PATH := "res://data/quests.json"

var defs: Dictionary = {}
var profile: Profile
var names: Dictionary = {}    ## id de PNJ -> nom affiché (rempli par le jeu)


func _init(p_profile: Profile) -> void:
	profile = p_profile
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			defs = (parsed as Dictionary).get("quests", {})


## "new" (pas encore proposée), "active" ou "done".
func state_of(id: String) -> String:
	return str(profile.quests.get(id, "new"))


## Ce que dit le PNJ `npc_id` au joueur : {lines, offer, turn_in}. `offer` : id d'une quête à proposer (le joueur
## accepte ou refuse après la dernière phrase) ; `turn_in` : id d'une quête qu'on rend (récompense à la fin).
## Un objet à livrer passe avant tout ; sinon la quête de ce PNJ selon son état ; sinon ses phrases ordinaires.
func talk(npc_id: String, generic: Array) -> Dictionary:
	for id: String in defs:
		var q: Dictionary = defs[id]
		if q["target"] == npc_id and state_of(id) == "active":
			return {"lines": q["turn_in"], "offer": "", "turn_in": id}
	for id: String in defs:
		var q: Dictionary = defs[id]
		if q["giver"] != npc_id:
			continue
		match state_of(id):
			"new":
				return {"lines": q["offer"], "offer": id, "turn_in": ""}
			"active":
				return {"lines": q["active"], "offer": "", "turn_in": ""}
			"done":
				return {"lines": q["done"], "offer": "", "turn_in": ""}
	return {"lines": generic, "offer": "", "turn_in": ""}


## Le joueur accepte : la quête est en cours. Renvoie ce que dit le PNJ en remettant l'objet.
func accept(id: String) -> Array:
	if not defs.has(id) or state_of(id) != "new":
		return []
	profile.quests[id] = "active"
	profile.save()
	return defs[id]["accepted"]


## La quête est rendue : le joueur touche sa récompense. Renvoie le montant (0 si rien à rendre).
func complete(id: String) -> int:
	if not defs.has(id) or state_of(id) != "active":
		return 0
	profile.quests[id] = "done"
	var reward := int(defs[id]["reward"])
	profile.gold += reward
	profile.save()
	return reward


## Les quêtes en cours.
func active_ids() -> Array:
	var out: Array = []
	for id: String in defs:
		if state_of(id) == "active":
			out.append(id)
	return out


## Une ligne par quête en cours, pour le suivi à l'écran.
func tracker_text() -> String:
	var lines: Array[String] = []
	for id: String in active_ids():
		var q: Dictionary = defs[id]
		lines.append("%s : porter %s à %s" % [q["title"], q["item"], names.get(q["target"], str(q["target"]))])
	return "\n".join(lines)
