class_name Reputation
extends RefCounted
## La réputation de pirate : des points (Profile.reputation) et des rangs (data/reputation.json). Les rangs débloquent
## des skins de bateau. Cette classe ne fait que lire le catalogue et convertir points <-> rang.

const PATH := "res://data/reputation.json"

static var _data: Dictionary = {}
static var path := PATH   ## (les essais peuvent la détourner)


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_data = parsed if parsed is Dictionary else {"ranks": [{"name": "Mousse", "at": 0}], "gains": {}}
	return _data


static func ranks() -> Array:
	return data()["ranks"]


## Le montant d'un gain (« quest », « enemy_ship »…), 0 s'il n'existe pas.
static func gain(key: String) -> float:
	return float((data().get("gains", {}) as Dictionary).get(key, 0.0))


## Le numéro du rang (0 = le premier) atteint avec `points`.
static func rank_of(points: int) -> int:
	var r := 0
	var list := ranks()
	for i in list.size():
		if points >= int((list[i] as Dictionary)["at"]):
			r = i
	return r


static func rank_name(rank: int) -> String:
	var list := ranks()
	return str((list[clampi(rank, 0, list.size() - 1)] as Dictionary)["name"])


## Les points qu'il faut pour atteindre le rang `rank`.
static func points_for(rank: int) -> int:
	var list := ranks()
	return int((list[clampi(rank, 0, list.size() - 1)] as Dictionary)["at"])


static func is_max(points: int) -> bool:
	return rank_of(points) >= ranks().size() - 1


## Avancement dans le rang courant, de 0 à 1 (1 au dernier rang).
static func progress(points: int) -> float:
	var r := rank_of(points)
	if is_max(points):
		return 1.0
	var a := points_for(r)
	var b := points_for(r + 1)
	return clampf(float(points - a) / float(maxi(b - a, 1)), 0.0, 1.0)
