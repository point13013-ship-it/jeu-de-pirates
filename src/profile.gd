class_name Profile
extends RefCounted
## Ce qui suit le joueur d'une partie à l'autre : son or, l'état de ses quêtes, ses provisions (planches et boulets
## achetés au Magasin Général) et les pièces de tenue achetées chez le tailleur. Sauvegardé dans user://profil.json.
## `persistent` à faux : tout reste en mémoire (essais automatiques, pour ne jamais écraser la vraie sauvegarde).

const PATH := "user://profil.json"
const START_PLANKS := 4
const START_BALLS := 8

var gold := 0
var contracts: Array = []     ## les contrats du tableau des quêtes (13/11) : {kind, need, have, reward, base}
var instrument := "accordeon"  ## l'instrument de musique choisi : accordeon, violon ou tambour (13/11)
var flint := 0                ## silex en poche (13/11) : à usage unique, sert à couper ses liens
var hidden := ""              ## l'emplacement caché : « flint » ou vide ; on y accède même ligoté
var tool := "compass"         ## l'instrument en poche : « compass » (boussole) ou « spyglass » (longue-vue) ; on l'échange à bord
var quests: Dictionary = {}   ## id de quête -> "active" ou "done" (absent : pas encore proposée)
var planks := START_PLANKS    ## planches en réserve (une prise à l'étagère de la cale en consomme une)
var balls := START_BALLS      ## boulets dans le sac (13/11 : 10 au plus, GameConfig.BAG_MAX)
var ship_planks := 30         ## planches dans le coffre du bateau (13/11 : stock commun à l'équipage, tenu par l'hôte)
var ship_bullets := 40        ## balles dans le coffre du bateau (13/11 : toutes les munitions y ont une réserve de base)
var ship_shells := 24         ## cartouches dans le coffre du bateau
var ship_balls := 40          ## boulets dans le coffre du bateau
var owned: Array = []         ## tenues possédées, « catégorie:variante » (ex. « hat:tricorn »)
var ship_skin: Dictionary = {}   ## skin du bateau (voiles, coque, pavillon) : voir ShipSkin ; vide = modèle d origine
var ships: Array = ["sloop"]       ## bateaux possédés (le sloop est offert) ; achetés au chantier naval
var ship := "sloop"                ## le bateau du joueur : celui de sa dernière sortie
var discovered: Array = []         ## îles repérées (identifiants de data/islands.json) : elles apparaissent sur la carte
var berry := ""                    ## la baie des dieux que le pirate porte (id de data/berries.json) ; vide = aucun pouvoir
var known_spells: Array = []       ## sorts déjà lancés (« baie:emplacement ») : leur nom n'est plus « ??? »
var berries: Dictionary = {}       ## baies des dieux ramassées et gardées dans le sac, pas encore mangées : id de baie -> nombre
var weapons: Array = ["sabre"]     ## armes possédées (data/weapons.json) ; le sabre est offert
var weapon := "sabre"              ## l'arme en main
var weapon2 := ""                   ## l'arme secondaire (clic droit) ; vide : la première autre arme possédée
var skins_owned: Array = []          ## skins d'armes possédés, « arme:id » (voir WeaponSkins) ; « classique » est toujours à nous
var skin_worn: Dictionary = {}      ## arme -> skin posé dessus (absent : classique)
var bullets := START_BULLETS       ## balles (pistolet, fusil de précision)
var shells := START_SHELLS         ## cartouches (tromblon)
var captured: Array = []           ## îles capturées (identifiants de data/islands.json) : plus d'ennemis ni de coffres qui reviennent (voir Outpost)
var reputation := 0                ## points de réputation de pirate (voir Reputation) : ils débloquent des skins de bateau
var cabins: Dictionary = {}        ## cabanes bâties : id d'île -> {"at": [x, z], "stash": [trésors rangés dans le coffre]}
var persistent := true

const START_BULLETS := 12
const START_SHELLS := 6


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
		ship_planks = int(d.get("ship_planks", 30))
		ship_balls = int(d.get("ship_balls", 40))
		ship_bullets = int(d.get("ship_bullets", 40))
		ship_shells = int(d.get("ship_shells", 24))
		var o: Variant = d.get("owned", [])
		owned = (o as Array).duplicate() if o is Array else []
		var sk: Variant = d.get("ship_skin", {})
		ship_skin = (sk as Dictionary).duplicate() if sk is Dictionary else {}
		var sh: Variant = d.get("ships", ["sloop"])
		ships = (sh as Array).duplicate() if sh is Array and not (sh as Array).is_empty() else ["sloop"]
		ship = str(d.get("ship", "sloop"))
		var dis: Variant = d.get("discovered", [])
		discovered = (dis as Array).duplicate() if dis is Array else []
		berry = str(d.get("berry", ""))
		var ks: Variant = d.get("known_spells", [])
		known_spells = (ks as Array).duplicate() if ks is Array else []
		var bs: Variant = d.get("berries", {})
		berries = (bs as Dictionary).duplicate() if bs is Dictionary else {}
		var ws: Variant = d.get("weapons", ["sabre"])
		weapons = (ws as Array).duplicate() if ws is Array and not (ws as Array).is_empty() else ["sabre"]
		weapon = str(d.get("weapon", "sabre"))
		weapon2 = str(d.get("weapon2", ""))
		var so: Variant = d.get("skins_owned", [])
		skins_owned = (so as Array).duplicate() if so is Array else []
		var sw: Variant = d.get("skin_worn", {})
		skin_worn = (sw as Dictionary).duplicate() if sw is Dictionary else {}
		if not weapons.has(weapon):
			weapon = "sabre"
		bullets = int(d.get("bullets", START_BULLETS))
		shells = int(d.get("shells", START_SHELLS))
		var cp: Variant = d.get("captured", [])
		captured = (cp as Array).duplicate() if cp is Array else []
		var cb: Variant = d.get("cabins", {})
		cabins = (cb as Dictionary).duplicate(true) if cb is Dictionary else {}
		reputation = maxi(int(d.get("reputation", 0)), 0)
		tool = "spyglass" if str(d.get("tool", "compass")) == "spyglass" else "compass"
		flint = maxi(int(d.get("flint", 0)), 0)
		instrument = str(d.get("instrument", "accordeon"))
		var ct: Variant = d.get("contracts", [])
		contracts = (ct as Array).duplicate(true) if ct is Array else []
		if not (instrument in ["accordeon", "violon", "tambour"]):
			instrument = "accordeon"
		hidden = "flint" if str(d.get("hidden", "")) == "flint" else ""


func save() -> void:
	if not persistent:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"gold": gold, "quests": quests, "planks": planks, "balls": balls, "ship_planks": ship_planks, "ship_balls": ship_balls, "ship_bullets": ship_bullets, "ship_shells": ship_shells, "owned": owned, "ship_skin": ship_skin, "ships": ships, "ship": ship, "discovered": discovered, "berry": berry, "known_spells": known_spells, "berries": berries, "weapons": weapons, "weapon": weapon, "weapon2": weapon2, "skins_owned": skins_owned, "skin_worn": skin_worn, "bullets": bullets, "shells": shells, "captured": captured, "cabins": cabins, "reputation": reputation, "tool": tool, "flint": flint, "hidden": hidden, "instrument": instrument, "contracts": contracts}, "\t"))


## Gagne `n` points de réputation. Renvoie {from, to, rank_from, rank_to} (pour l'animation de progression), ou {} si rien n'a changé.
func add_reputation(n: int) -> Dictionary:
	if n <= 0:
		return {}
	var before := reputation
	reputation += n
	save()
	return {"from": before, "to": reputation, "rank_from": Reputation.rank_of(before), "rank_to": Reputation.rank_of(reputation)}


## Le rang actuel (numéro).
func rank() -> int:
	return Reputation.rank_of(reputation)


## Prend l'arme `id` en main principale (clic gauche). Si c'était l'arme secondaire, elle prend l'ancienne arme principale.
func set_main_weapon(id: String) -> void:
	if id == weapon:
		return
	if id == weapon2:
		weapon2 = weapon
	weapon = id


## Fait de l'arme possédée `id` l'arme secondaire (clic droit). Si c'était l'arme principale, elles échangent leur place.
func set_secondary_weapon(id: String) -> void:
	if not weapons.has(id) or id == weapon2 or (id == weapon and weapons.size() < 2):
		return
	if id == weapon:
		weapon = secondary_weapon()
	weapon2 = id


## L'arme du clic droit : celle choisie si on la possède encore, sinon la première autre arme du sac, sinon l'arme principale.
func secondary_weapon() -> String:
	if weapon2 != "" and weapon2 != weapon and weapons.has(weapon2):
		return weapon2
	for w: Variant in weapons:
		if str(w) != weapon:
			return str(w)
	return weapon


## Ajoute (ou retire, n < 0) des baies `id` au sac.
func add_berry(id: String, n: int = 1) -> void:
	var left := int(berries.get(id, 0)) + n
	if left <= 0:
		berries.erase(id)
	else:
		berries[id] = left
	save()


## Prend une munition (« bullets » ou « shells ») ; faux s'il n'y en a plus.
func take_ammo(kind: String) -> bool:
	if kind == "bullets" and bullets > 0:
		bullets -= 1
	elif kind == "shells" and shells > 0:
		shells -= 1
	else:
		return false
	save()
	return true


func ammo_count(kind: String) -> int:
	return bullets if kind == "bullets" else (shells if kind == "shells" else 0)


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


## Le skin posé sur l'arme `w` (« classique » par défaut ou si on ne le possède plus).
func skin_of(w: String) -> String:
	var s := str(skin_worn.get(w, WeaponSkins.CLASSIC))
	return s if s == WeaponSkins.CLASSIC or skins_owned.has(WeaponSkins.key(w, s)) else WeaponSkins.CLASSIC


func owns_skin(w: String, s: String) -> bool:
	return s == WeaponSkins.CLASSIC or skins_owned.has(WeaponSkins.key(w, s))


## Les skins qu'on peut poser sur l'arme `w` : classique, puis ceux qu'on possède.
func skins_for(w: String) -> Array:
	var out: Array = [WeaponSkins.CLASSIC]
	for id in WeaponSkins.ids_of(w):
		if skins_owned.has(WeaponSkins.key(w, str(id))):
			out.append(str(id))
	return out


## Gagne un skin (« arme:id ») et le pose tout de suite. Faux si on l'avait déjà.
func gain_skin(k: String) -> bool:
	if skins_owned.has(k):
		return false
	skins_owned.append(k)
	var p := k.split(":")
	if p.size() == 2:
		skin_worn[p[0]] = p[1]
	save()
	return true
