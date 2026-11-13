class_name Hook
extends RefCounted
## Le grappin du bateau : où file le crochet quand on le lance dans une direction, et ce qu'il saisit.
## Il part de `origin` (monde x/z, la bouche du canon à grappin) en ligne droite et s'accroche à la PREMIÈRE chose qu'il touche : un butin, un bateau ennemi,
## un bateau ennemi, un récif, le rivage, un mur, un tonneau, un arbre… Au-delà de RANGE il retombe à l'eau : rien d'accroché.
## Cette fonction est celle du jeu : le joueur la voit en visant (cercle vert ou rouge), l'hôte la rejoue au lancer.

const RANGE := 22.0     ## m : portée du crochet (13/11 : 26)
const STEP := 0.4       ## m entre deux sondages le long du tir
const START := 1.1      ## m : on ne saisit rien plus près que cela (le pirate lui-même, ce qu'il a sous les pieds)
const SPEED := 34.0     ## m/s : vol du crochet
const REEL := 9.0       ## m/s : on ramène un butin

const KIND_NONE := ""
const KIND_FIXED := "land"     ## un point fixe : rivage, rocher, mur, tonneau, arbre…
const KIND_LOOT := "loot"      ## un butin (il suit sa dérive)
const KIND_SHIP := "ship"      ## le bateau des joueurs (le crochet suit le bateau)
const KIND_ENEMY := "enemy"    ## un bateau ennemi

## Codes réseau de l'espèce d'accroche (état du bateau).
const KIND_CODES := ["", "land", "loot", "ship", "enemy"]

const NAMES := {"land": "la terre", "terre": "la terre", "rocher": "un rocher", "mur": "un mur", "objet": "un objet",
		"loot": "du butin", "ship": "ton bateau", "enemy": "un bateau ennemi"}


## Ce que saisit un crochet lancé de `origin` vers `dir`. `probes` (tous facultatifs) sont des Callable(Vector2 monde) :
##  "loot"  -> {id, pos, name}  ou {} ;   "enemy" -> {id, name} ou {} ;
##  "ship"  -> vrai si le point est sur le bateau des joueurs ;   "solid" -> « terre », « rocher », « mur », « objet » ou «  ».
## Renvoie {kind, pos, id, name, dist} ; kind vaut « » si rien n'est à portée (pos : le bout du tir).
static func trace(origin: Vector2, dir: Vector2, probes: Dictionary, max_range: float = RANGE) -> Dictionary:
	var d := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var dist := START
	while dist <= max_range:
		var p := origin + d * dist
		if probes.has("loot"):
			var l: Dictionary = (probes["loot"] as Callable).call(p)
			if not l.is_empty():
				return {"kind": KIND_LOOT, "pos": l.get("pos", p), "id": int(l.get("id", -1)), "name": "du butin", "dist": dist}
		if probes.has("enemy"):
			var e: Dictionary = (probes["enemy"] as Callable).call(p)
			if not e.is_empty():
				return {"kind": KIND_ENEMY, "pos": p, "id": int(e.get("id", -1)), "name": "un bateau ennemi", "dist": dist}
		if probes.has("ship") and bool((probes["ship"] as Callable).call(p)):
			return {"kind": KIND_SHIP, "pos": p, "id": -1, "name": "ton bateau", "dist": dist}
		if probes.has("solid"):
			var s: String = (probes["solid"] as Callable).call(p)
			if s != "":
				return {"kind": KIND_FIXED, "pos": p, "id": -1, "name": str(NAMES.get(s, s)), "dist": dist}
		dist += STEP
	return {"kind": KIND_NONE, "pos": origin + d * max_range, "id": -1, "name": "", "dist": max_range}


## Direction de tir <-> entier (dixièmes de degré) pour l'envoyer à l'hôte dans une requête.
static func dir_code(dir: Vector2) -> int:
	return posmod(roundi(rad_to_deg(dir.angle()) * 10.0), 3600)


static func code_dir(code: int) -> Vector2:
	return Vector2.from_angle(deg_to_rad(float(code) / 10.0))


static func kind_code(kind: String) -> int:
	return maxi(KIND_CODES.find(kind), 0)


static func kind_of_code(code: int) -> String:
	return str(KIND_CODES[clampi(code, 0, KIND_CODES.size() - 1)])
