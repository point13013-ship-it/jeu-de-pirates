extends SceneTree
## Ville v3 (data/town_plan.json) : le plan est cohérent et les collisions qui en sont tirées tiennent.
## godot --headless --path . -s tests/unit/test_town_v3.gd

var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("ÉCHEC ", what)


func _corners(b: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var c := Vector2(float(b["x"]), float(b["y"]))
	for v: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		out.append(c + Vector2(v.x * float(b["w"]) * 0.5, v.y * float(b["d"]) * 0.5).rotated(float(b["ang"])))
	return out


## Plus petite distance entre les murs de deux bâtiments (0 s'ils se touchent).
func _gap(a: Dictionary, b: Dictionary) -> float:
	var pa := _corners(a)
	var pb := _corners(b)
	if not Geometry2D.intersect_polygons(PackedVector2Array(pa), PackedVector2Array(pb)).is_empty():
		return 0.0
	var best := INF
	for i in 4:
		for j in 4:
			var pts := Geometry2D.get_closest_points_between_segments(pa[i], pa[(i + 1) % 4], pb[j], pb[(j + 1) % 4])
			best = minf(best, pts[0].distance_to(pts[1]))
	return best


func _initialize() -> void:
	var f := FileAccess.open("res://data/town_plan.json", FileAccess.READ)
	var plan: Dictionary = JSON.parse_string(f.get_as_text())
	var land := Land.new()
	land.load_plan(plan)
	var lv: Array = []
	for l: Dictionary in plan["levels"]:
		lv.append({"id": str(l["id"]), "poly": Land._poly(l["poly"]), "h": float(l["h"]), "solid": true})
	for r: Dictionary in plan["ramps"]:
		lv.append({"id": str(r["id"]), "ramp": [float(r["a"][0]), float(r["a"][1]), float(r["b"][0]), float(r["b"][1]), float(r["width"])],
				"h0": float(r["h0"]), "h1": float(r["h1"]), "solid": true})
	land.load_town({"levels": lv, "interiors": []})

	# le sol : le quai et le bout du grand ponton portent, la mer non
	_check(land.walk_height(Vector2(0.0, -6.0), 0.0) == 0.0, "on tient debout sur la place du débarcadère")
	_check(land.walk_height(Vector2(0.0, 30.0), 0.0) == 0.0, "on tient debout au bout du grand ponton")
	_check(land.is_over_water(Vector2(20.0, 25.0)), "le bassin est de l'eau")
	_check(Land.hits_land([Vector2(0.0, -20.0)]) and not Land.hits_land([Vector2(20.0, 25.0)]), "la terre arrête les bateaux, le bassin non")

	# les murs : on ne traverse aucun bâtiment fermé ; une tente se traverse
	for b: Dictionary in plan["buildings"]:
		var c := Vector2(float(b["x"]), -float(b["y"]))
		var open: bool = str(b["mode"]) in ["tente", "comptoir", "halle", "jardin"]
		if not open:
			_check(not land.is_walkable(c), "on ne marche pas dans %s" % str(b["id"]))

	# de la place pour circuler (retour de Jimmy, 13/11) : jamais moins de 2,8 m entre deux bâtiments fermés, et aucun mur sur une rue
	var solid: Array = []
	for b4: Dictionary in plan["buildings"]:
		if not (str(b4["mode"]) in ["tente", "comptoir", "halle", "jardin"]):
			solid.append(b4)
	for i in solid.size():
		for j in range(i + 1, solid.size()):
			var gap := _gap(solid[i], solid[j])
			_check(gap >= 2.8, "%s et %s sont à %.1f m l'un de l'autre (2,8 m au moins)" % [str(solid[i]["id"]), str(solid[j]["id"]), gap])
	for b5: Dictionary in solid:
		for s4: Dictionary in plan["streets"]:
			var pts: Array = s4["pts"]
			for k2 in pts.size() - 1:
				var a3 := Vector2(float(pts[k2][0]), float(pts[k2][1]))
				var b6 := Vector2(float(pts[k2 + 1][0]), float(pts[k2 + 1][1]))
				for c3: Vector2 in _corners(b5):
					var dist := Geometry2D.get_closest_point_to_segment(c3, a3, b6).distance_to(c3) - float(s4["width"]) * 0.5
					_check(dist > 0.3, "%s empiète sur la rue %s (%.1f m)" % [str(b5["id"]), str(s4["id"]), dist])

	# chaque habitant est sur un sol praticable, pas dans un mur
	for id: String in plan["npcs"]:
		var p: Array = plan["npcs"][id]
		var w := Vector2(float(p[0]), -float(p[1]))
		_check(land.surface_below(w, 50.0) != Land.NO_SURFACE, "%s a un sol sous les pieds" % id)

	# les services de chaque retour sont à moins de 35 m du bateau (milieu du grand ponton)
	var boat := Vector2(0.0, -float(plan["dock"]["y"]))
	for id2: String in ["corbin", "petronille"]:
		var p2: Array = plan["npcs"][id2]
		var d := Vector2(float(p2[0]), -float(p2[1])).distance_to(boat)
		_check(d < 35.0, "%s est à moins de 35 m du bateau (%.1f m)" % [id2, d])

	# chaque rampe monte de 0 à sa terrasse, à pied, et on en redescend
	for r2: Dictionary in plan["ramps"]:
		var a := Vector2(float(r2["a"][0]), -float(r2["a"][1]))
		var b2 := Vector2(float(r2["b"][0]), -float(r2["b"][1]))
		var dir := (b2 - a).normalized()
		var pos := a - dir * 1.0
		var h := 0.0
		for k in 400:
			var s := land.step(pos, dir * 0.08, h)
			pos = Vector2(s.x, s.y)
			h = s.z
			if pos.distance_to(a) > a.distance_to(b2) + 2.0:
				break
		_check(absf(h - float(r2["h1"])) < 0.05, "%s : on arrive en haut (hauteur %.2f)" % [str(r2["id"]), h])
		for k in 400:
			var s2 := land.step(pos, -dir * 0.08, h)
			pos = Vector2(s2.x, s2.y)
			h = s2.z
		_check(absf(h) < 0.05, "%s : on redescend (hauteur %.2f)" % [str(r2["id"]), h])

	# on ne saute pas du bas sur la terrasse à pied : son mur arrête
	var up := Vector2(5.0, -77.0)   # le parvis de l'église, sur la haute ville
	_check(land.walk_height(up, 0.0) == Land.NO_SURFACE and land.walk_height(up, 3.0) == 3.0, "la haute ville est à 3 m, pas au niveau de la rue")

	# sortie de l'eau : par une échelle ou par la grève, pas ailleurs
	var lad: Array = plan["ladders"][0]
	_check(land.can_exit_water(Vector2(float(lad[0]), -float(lad[1]) - 0.5), 2.0), "on sort de l'eau au pied d'une échelle")
	_check(not land.can_exit_water(Vector2(-13.5, -0.6), 2.0), "on ne sort pas de l'eau loin d'une échelle")
	var sand: Array = plan["sand"][2]
	_check(land.can_exit_water(Vector2(float(sand[0]), -float(sand[1]) + 2.0), 2.0), "on sort de l'eau par la grève")
	# aucun point du quai n'est à plus de 12 m d'une échelle
	var quay: Array = []
	for s3: Dictionary in plan["streets"]:
		if str(s3["id"]) == "quai":
			quay = s3["pts"]
	for q: Array in quay:
		var best := INF
		for l2: Array in plan["ladders"]:
			best = minf(best, Vector2(float(l2[0]), float(l2[1])).distance_to(Vector2(float(q[0]), float(q[1]))))
		_check(best < 12.0, "une échelle à moins de 12 m du quai en (%.0f, %.0f) : %.1f m" % [float(q[0]), float(q[1]), best])

	print("RÉSULTAT : tout passe" if _fails == 0 else "RÉSULTAT : %d échec(s)" % _fails)
	quit(1 if _fails > 0 else 0)
