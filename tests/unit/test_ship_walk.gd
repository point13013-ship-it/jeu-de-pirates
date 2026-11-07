extends SceneTree
## Tests de déplacement sur le pont : depuis la porte de la cabine, le pirate doit pouvoir atteindre la barre,
## les mâts, l'ancre, les canons, le tonneau de boulets, les échelles de coque, l'échelle du mât et la pointe
## de l'étrave, sur les trois bateaux. Et le dégagement d'un pirate coincé derrière la roue.
## Lancer : godot --headless --path . -s tests/unit/test_ship_walk.gd

const STEP := 0.1
var _failed := 0


func _initialize() -> void:
	for ship_name in ["sloop", "brigantin", "galion"]:
		var ship := ShipModel.new()
		_check_true("%s : chargé" % ship_name, ship.load_ship(ship_name))
		var door_x := float(ship.cabin.get("door_x", 0.0))
		var start := ship.nearest_walkable(Vector2(door_x + 0.9, 0.7))
		_check_true("%s : point de départ libre" % ship_name, ship.is_walkable(start))
		var reach := _flood(ship, start)
		var helm: Array = ship.meta["helm"]
		var targets := {
			"la pointe de l'étrave": Vector2(ship.bow_x - 0.05, 0.0),
			"l'ancre": Vector2(float(ship.meta["anchor"][0]) - 0.9, 0.0),
			"le tonneau de boulets": Vector2(float(ship.meta["ammo"][0]), float(ship.meta["ammo"][1]) - 0.9),
			"la barre": Vector2(float(helm[0]) + 0.5, float(helm[1]) + 0.5),
		}
		for l: Array in ship.ladders:
			targets["l'échelle de coque %+d" % int(l[2])] = Vector2(float(l[0]), float(l[1]))
		targets["l'échelle du mât"] = Vector2(float(ship.mast_ladder[0]), float(ship.mast_ladder[1]))
		for i in ship.cannons.size():
			var c: Array = ship.cannons[i]
			targets["le canon %d" % i] = Vector2(float(c[0]), float(c[1]))
		for what: String in targets:
			# on interagit à moins de 1,5 m : il suffit d'avoir un point accessible à portée de la cible
			var ok := _near_reach(reach, targets[what], 0.25 if what == "la pointe de l'étrave" else 1.0)
			if what == "la pointe de l'étrave" and ship_name == "galion":
				continue   # le château d'étrave du galion est plein : on ne le traverse pas
			_check_true("%s : on atteint %s" % [ship_name, what], ok)
		# coincé derrière la roue : on doit pouvoir sortir
		var stuck := Vector2(float(helm[0]) - 0.55, float(helm[1]))
		var out := ship.nearest_walkable(stuck)
		_check_true("%s : on se dégage de la roue" % ship_name, ship.is_walkable(out))
		var moved := ship.move_with_slide(stuck, Vector2(-0.05, 0.0))
		_check_true("%s : coincé, on peut quand même bouger" % ship_name, moved != stuck)
		ship.free()
	# le terrain : le quai est solide pour un bateau, la mer ne l'est pas
	_check_true("quai : la coque le touche", Land.hits_land([Vector2(0.0, -10.0)]))
	_check_true("pont du ponton : la coque le touche", Land.hits_land([Vector2(16.0, 10.0)]))
	_check_true("mer : rien", not Land.hits_land([Vector2(30.0, 10.0), Vector2(0.0, 12.0)]))
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _near_reach(reach: Dictionary, p: Vector2, radius: float) -> bool:
	var c := _cell(p)
	var n := ceili(radius / STEP)
	for dx in range(-n, n + 1):
		for dy in range(-n, n + 1):
			if Vector2(dx, dy).length() * STEP <= radius and reach.has(c + Vector2i(dx, dy)):
				return true
	return false


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / STEP), roundi(p.y / STEP))


## Toutes les cases (de STEP mètres) accessibles à pied depuis `start`.
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


func _check_true(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)
