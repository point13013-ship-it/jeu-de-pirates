extends SceneTree
## Tests du saut libre sur le vrai plan du port : en l'air on franchit le bord du quai (jusqu'à l'eau ou jusqu'au bateau amarré), on passe
## au-dessus des poteaux mais pas à travers les murs des bâtiments ; à pied rien ne change (le bord du quai reste une limite). Et le pont
## du bateau : les obstacles bas s'enjambent plus facilement qu'avant.
## Lancer : godot --headless --path . -s tests/unit/test_air.gd

var _failed := 0


func _initialize() -> void:
	var land := Land.new()
	land.load_meta(_json("res://assets/models/port/port_meta.json"))
	land.load_town(_json("res://data/town.json"))
	_test_quay_edge(land)
	_test_obstacles(land)
	_test_ship_deck()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f != null else {}


## Le bord du quai (z = -0.3 en coordonnées du monde) : à pied, le pirate s'arrête à 0,22 m du bord ; en l'air il le franchit.
func _test_quay_edge(land: Land) -> void:
	var start := Vector2(-3.0, -0.6)   # sur le quai, tout au bord (côté mer : z croissant)
	_check("on se tient sur le quai", land.is_walkable(start))
	var walk := start
	for i in 200:
		var r := land.step(walk, Vector2(0.0, 0.06), 0.0)
		walk = Vector2(r.x, r.y)
	_check("à pied, le bord du quai est une limite", walk.y < -0.3 and land.is_walkable(walk))
	# en l'air, même trajet : on passe le bord et on arrive au-dessus de l'eau
	var air := start
	for i in 60:
		air = land.air_move(air, Vector2(0.0, 0.06), 1.0, 0.0)
	_check("en l'air, on franchit le bord du quai", air.y > 1.0)
	_check("… et on est au-dessus de l'eau", land.is_over_water(air))
	# la zone morte : à 0,1 m du bord, ni marchable ni « vide » — le saut doit pourtant y avancer
	var dead := Vector2(-3.0, -0.35)
	_check("(zone morte au bord : pas marchable)", not land.is_walkable(dead))
	var moved := land.air_move(dead, Vector2(0.0, 0.06), 0.5, 0.0)
	_check("(… mais un saut y avance)", moved.y > dead.y)
	# le ponton avance dans l'eau (x de 14,3 à 17,7) : on le quitte par le côté d'un saut
	var pier := Vector2(15.0, 10.0)
	_check("on se tient sur le ponton", land.is_walkable(pier))
	var side := pier
	for i in 80:
		side = land.air_move(side, Vector2(0.06, 0.0), 1.0, 0.0)
	_check("en l'air, on quitte le ponton par le côté", side.x > 17.7 and land.is_over_water(side))
	_check("… et on le quitte de plus d'un mètre (le bateau amarré est à côté)", side.x - pier.x > 4.0)


func _test_obstacles(land: Land) -> void:
	# un bâtiment : jamais traversé, même en pleine hauteur
	var o: Array = land.obstacles[0]   # [x0, y0, x1, y1] en coordonnées du fichier (z = -y)
	var wall_z := -(float(o[1]) + float(o[3])) * 0.5
	var from := Vector2(float(o[0]) - 1.5, wall_z)
	var p := from
	for i in 120:
		p = land.air_move(p, Vector2(0.06, 0.0), 2.0, 0.0)
	_check("un saut ne traverse pas le mur d'un bâtiment", p.x < float(o[0]) + 0.1)
	# un poteau (cercle de petit rayon) : bloque bas, s'enjambe haut
	var c: Array = land.circles[1]
	var post := Vector2(float(c[0]), -float(c[1]))
	_check("un poteau bloque un saut bas", not land.air_clear(post, 0.1))
	_check("… et s'enjambe à bonne hauteur", land.air_clear(post, Land.LOW_CLEAR + 0.05))
	_check("blocker_at nomme un mur", land.blocker_at(Vector2(float(o[0]) + 0.5, -(float(o[1]) + 0.5))) == "mur")
	_check("blocker_at nomme un objet", land.blocker_at(post) == "objet")
	_check("blocker_at ne voit rien sur le quai dégagé", land.blocker_at(Vector2(0.0, -10.0)) == "")


func _test_ship_deck() -> void:
	var ship := ShipModel.new()
	_check("sloop chargé", ship.load_ship("sloop"))
	# une caisse de 0,7 m de côté : à 0,5 m de hauteur de saut (avant : 0,65) on passe
	var crate := Vector2(float(ship.boxes[8][2]) - 0.06, (float(ship.boxes[8][1]) + float(ship.boxes[8][3])) * 0.5)   # le bord libre de la pile (l'autre touche le mur de la cabine)
	_check("la caisse du pont est basse (enjambable)", 8 in ship.low_boxes)
	_check("à 0,3 m de haut, la caisse bloque", not ship.is_walkable_air(crate, 0.3))
	_check("à 0,55 m de haut, on passe au-dessus de la caisse", ship.is_walkable_air(crate, 0.55))
	_check("à 0,4 m on passe déjà le plat-bord", ship.is_walkable_air(Vector2(0.0, ship.half_width(0.0) + 0.1), 0.4))
	# la cabine reste un mur
	var wall := Vector2((float(ship.boxes[0][0]) + float(ship.boxes[0][2])) * 0.5, 0.0)   # le mur arrière de la cabine
	_check("le mur de la cabine ne s'enjambe pas, même au sommet du saut", not ship.is_walkable_air(wall, 1.5))
	ship.free()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)
