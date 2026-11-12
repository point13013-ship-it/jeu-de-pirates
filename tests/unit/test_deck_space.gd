extends SceneTree
## Pont praticable (agrandissement des coques, 12/11/2026) : pour chaque bateau, la barre est dans l'axe devant la cabine, les
## couloirs de marche font au moins 1,2 m, et un pirate qui marche tout droit de la barre à l'étrave (par bâbord, par tribord)
## arrive au bout sans rester coincé. Mesures en mètres de jeu.
## Lancer : godot --headless --path . -s tests/unit/test_deck_space.gd

const MIN_LANE_M := 1.2
var _failed := 0


func _initialize() -> void:
	for ship_name: String in ["sloop", "brigantin", "galion"]:
		var m := ShipModel.new()
		_check("%s : modèle chargé" % ship_name, m.load_ship(ship_name))
		var helm: Array = m.meta.get("helm", [0.0, 1.0])
		_check("%s : barre dans l'axe" % ship_name, absf(float(helm[1])) < 0.01)
		_check("%s : barre devant la cabine" % ship_name, float(helm[0]) > float(m.cabin["door_x"]) + 0.8)
		_check("%s : coque agrandie (%.1f m)" % [ship_name, m.length * ShipModel.SCALE], m.length * ShipModel.SCALE > 19.0)
		# couloir le plus étroit entre la barre et l'ancre : à chaque abscisse, la plus longue suite de points libres en travers
		var worst := 99.0
		var worst_x := 0.0
		var x := float(helm[0]) + 0.4
		var x_end := float((m.meta.get("anchor", [m.bow_x - 1.0, 0.0]) as Array)[0]) - 0.5
		while x < x_end:
			var best := 0.0
			var run := 0.0
			var y := -m.half_width(x)
			while y <= m.half_width(x):
				run = run + 0.02 if m.is_walkable(Vector2(x, y)) else 0.0
				best = maxf(best, run)
				y += 0.02
			if best * ShipModel.SCALE < worst:
				worst = best * ShipModel.SCALE
				worst_x = x
			x += 0.05
		_check("%s : couloir le plus étroit %.2f m (à x=%.1f)" % [ship_name, worst, worst_x], worst >= MIN_LANE_M)
		# marcher tout droit vers l'étrave, d'un côté puis de l'autre de la barre, avec glissade
		for side: float in [-1.0, 1.0]:
			var p := Vector2(float(helm[0]) - 0.6, side * 0.5)
			if not m.is_walkable(p):
				p = m.nearest_walkable(p)
			var steps := 0
			while steps < 4000 and p.x < x_end:
				var np := m.move_with_slide(p, Vector2(0.02, 0.0))
				if np.distance_to(p) < 0.001:
					break
				p = np
				steps += 1
			_check("%s : de la barre à l'avant par %s (arrivé à x=%.1f / %.1f)" % [ship_name, "bâbord" if side > 0 else "tribord", p.x, x_end], p.x >= x_end)
		m.free()
	quit(1 if _failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("ok  " if ok else "ÉCHEC ") + label)
	if not ok:
		_failed += 1
