extends SceneTree
## Tests du choix du poste visé sur le pont (E, R) : chaque poste doit pouvoir être visé à coup sûr depuis un point
## accessible (en lui faisant face), et ne doit JAMAIS l'être quand on regarde ailleurs ou qu'on est trop loin.
## Lancer : godot --headless --path . -s tests/unit/test_interact_target.gd

const STEP := 0.1
const SailingScript := preload("res://src/sailing_game.gd")
var _failed := 0


func _initialize() -> void:
	for ship_name in ["sloop", "brigantin", "galion"]:
		var ship := ShipModel.new()
		_check_true("%s : chargé" % ship_name, ship.load_ship(ship_name))
		var posts := _posts(ship)
		var start := ship.nearest_walkable(Vector2(float(ship.cabin.get("door_x", 0.0)) + 0.9, 0.7))
		var reach := _flood(ship, start)
		for post: Dictionary in posts:
			var label := "%s : %s %s" % [ship_name, post["kind"], post["pos"]]
			var p: Dictionary = SailingScript.INTERACT_PARAMS[post["kind"]]
			var found := false
			var wrong_when_back := false
			for c: Vector2i in reach:
				var pos := Vector2(c.x * STEP, c.y * STEP)
				var to: Vector2 = (post["pos"] as Vector2) - pos
				if to.length() > float(p["reach"]) or to.length() < 0.25:
					continue
				# en lui faisant face : il doit être choisi, tel quel et pas un voisin
				if SailingScript.pick_target(posts, pos, to.normalized(), {}) == post:
					found = true
				# le dos tourné : il ne doit pas être visé (sauf cône ouvert : l'écoutille)
				if float(p["cone"]) > 0.3 and SailingScript.pick_target(posts, pos, -to.normalized(), {}) == post:
					wrong_when_back = true
			_check_true("%s : visable en lui faisant face" % label, found)
			_check_true("%s : pas visé le dos tourné" % label, not wrong_when_back)
		# la stabilité : le poste déjà visé est gardé face à un voisin à peine meilleur
		ship.free()
	# loin de tout : rien
	_check_true("loin de tout : aucun poste", SailingScript.pick_target([{"kind": "anchor", "pos": Vector2(9.0, 9.0)}], Vector2.ZERO, Vector2(1, 0), {}).is_empty())
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


## Les postes du pont comme sailing_game les déclare (barre, mâts, échelles, ancre, tonneau de boulets, canons).
func _posts(ship: ShipModel) -> Array:
	var out: Array = []
	var helm: Array = ship.meta["helm"]
	out.append({"kind": "helm", "pos": Vector2(float(helm[0]), float(helm[1]))})
	for m: Array in ship.masts:
		out.append({"kind": "mast", "pos": Vector2(float(m[0]), 0.0)})
	for l: Array in ship.ladders:
		out.append({"kind": "ladder", "pos": Vector2(float(l[0]), float(l[1]))})
	out.append({"kind": "mastladder", "pos": Vector2(float(ship.mast_ladder[0]), float(ship.mast_ladder[1]))})
	var anchor: Array = ship.meta["anchor"]
	out.append({"kind": "anchor", "pos": Vector2(float(anchor[0]), float(anchor[1]))})
	var ammo: Array = ship.meta["ammo"]
	out.append({"kind": "ammo", "pos": Vector2(float(ammo[0]), float(ammo[1]))})
	for i in ship.cannons.size():
		var c: Array = ship.cannons[i]
		out.append({"kind": "cannon", "pos": Vector2(float(c[0]), float(c[1])), "index": i})
	return out


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / STEP), roundi(p.y / STEP))


## Toutes les cases (de STEP) accessibles à pied depuis `start`.
func _flood(ship: ShipModel, start: Vector2) -> Dictionary:
	var seen := {_cell(start): true}
	var todo: Array[Vector2i] = [_cell(start)]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if seen.has(n):
				continue
			if ship.is_walkable(Vector2(n.x * STEP, n.y * STEP)):
				seen[n] = true
				todo.append(n)
	return seen


func _check_true(what: String, cond: bool) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_failed += 1
		print("  ÉCHEC %s" % what)
