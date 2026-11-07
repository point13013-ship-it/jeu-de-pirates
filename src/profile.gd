class_name Profile
extends RefCounted
## Ce qui suit le joueur d'une partie à l'autre : son or, l'état de ses quêtes, ses provisions (planches et boulets
## achetés au Magasin Général) et les pièces de tenue achetées chez le tailleur. Sauvegardé dans user://profil.json.
## `persistent` à faux : tout reste en mémoire (essais automatiques, pour ne jamais écraser la vraie sauvegarde).

const PATH := "user://profil.json"
const START_PLANKS := 4
const START_BALLS := 8

var gold := 0
var quests: Dictionary = {}   ## id de quête -> "active" ou "done" (absent : pas encore proposée)
var planks := START_PLANKS    ## planches en réserve (une prise à l'étagère de la cale en consomme une)
var balls := START_BALLS      ## boulets en réserve (une prise au tonneau du pont en consomme un)
var owned: Array = []         ## tenues possédées, « catégorie:variante » (ex. « hat:tricorn »)
var ship_skin: Dictionary = {}   ## skin du bateau (voiles, coque, pavillon) : voir ShipSkin ; vide = modèle d origine
var ships: Array = ["sloop"]       ## bateaux possédés (le sloop est offert) ; achetés au chantier naval
var ship := "sloop"                ## le bateau du joueur : celui de sa dernière sortie
var discovered: Array = []         ## îles repérées (identifiants de data/islands.json) : elles apparaissent sur la carte
var persistent := true


func load_file() -> void:
	if not persistent:
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var d := parsed as Dictionary
		gold = int(d.get("gold", 0))
		var q: Variant = d.get("quests", {})
		quests = (q as Dictionary).duplicate() if q is Dictionary else {}
		planks = int(d.get("planks", START_PLANKS))
		balls = int(d.get("balls", START_BALLS))
		var o: Variant = d.get("owned", [])
		owned = (o as Array).duplicate() if o is Array else []
		var sk: Variant = d.get("ship_skin", {})
		ship_skin = (sk as Dictionary).duplicate() if sk is Dictionary else {}
		var sh: Variant = d.get("ships", ["sloop"])
		ships = (sh as Array).duplicate() if sh is Array and not (sh as Array).is_empty() else ["sloop"]
		ship = str(d.get("ship", "sloop"))
		var dis: Variant = d.get("discovered", [])
		discovered = (dis as Array).duplicate() if dis is Array else []


func save() -> void:
	if not persistent:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"gold": gold, "quests": quests, "planks": planks, "balls": balls, "owned": owned, "ship_skin": ship_skin, "ships": ships, "ship": ship, "discovered": discovered}, "\t"))


## Prend une planche ou un boulet en réserve ; faux s'il n'y en a plus.
func take_supply(kind: String) -> bool:
	if kind == "plank" and planks > 0:
		planks -= 1
	elif kind == "ball" and balls > 0:
		balls -= 1
	else:
		return false
	save()
	return true
