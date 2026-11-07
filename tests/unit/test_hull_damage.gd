extends SceneTree
## Tests de la coque et de la cale : voies d'eau ouvertes par un choc, planches, écopage, naufrage, état
## envoyé aux clients ; et sur les trois bateaux, depuis le pied de l'échelle on atteint l'étagère à planches,
## le seau et chacune des voies d'eau possibles.
## Lancer : godot --headless --path . -s tests/unit/test_hull_damage.gd

const STEP := 0.1
var _failed := 0


func _initialize() -> void:
	var cfg := HullDamage.load_config()
	_check_true("data/hull.json lu", not cfg.is_empty())
	_test_rules(cfg)
	_test_slots(cfg)
	_test_state(cfg)
	for ship_name in ["sloop", "brigantin", "galion"]:
		_test_hold(cfg, ship_name)
	_test_rocks(cfg)
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _hull(cfg: Dictionary, length: float = 12.6) -> HullDamage:
	var h := HullDamage.new()
	h.configure(cfg, length)
	return h


func _test_rules(cfg: Dictionary) -> void:
	var h := _hull(cfg)
	_check_eq("à neuf : pas de voie d'eau", h.leak_count(), 0)
	_check_eq("un frôlement ne perce rien", h.leaks_for_speed(h.min_impact_speed - 0.1), 0)
	_check_eq("un choc modéré : 1 voie d'eau", h.leaks_for_speed(h.min_impact_speed + 0.1), 1)
	_check_true("un choc violent : plusieurs voies d'eau", h.leaks_for_speed(9.0) > 1)
	_check_true("jamais plus que le maximum", h.leaks_for_speed(99.0) <= h.max_leaks_per_impact)
	var opened := h.add_leaks(0.0, 1, 3)
	_check_eq("3 voies d'eau ouvertes", opened.size(), 3)
	_check_eq("elles sont comptées", h.leak_count(), 3)
	for s: int in opened:
		_check_true("la voie %d est à bâbord" % s, h.slot_side(s) == 1)
	var before := h.water
	h.step(10.0)
	_check_true("l'eau monte avec les voies d'eau", h.water > before)
	_check_near("vitesse de montée = voies x débit x temps", h.water, 3.0 * h.inflow_per_leak * 10.0)
	var full := h.water
	h.bail()
	_check_near("un seau vide la cale de bail_amount", h.water, full - h.bail_amount)
	_check_true("patch : boucher une voie ouverte réussit", h.patch(opened[0]))
	_check_true("patch : la boucher deux fois échoue", not h.patch(opened[0]))
	_check_true("la voie bouchée ne fuit plus", not h.has_leak(opened[0]))
	_check_true("elle garde sa planche", h.is_patched(opened[0]))
	_check_eq("il reste 2 voies d'eau", h.leak_count(), 2)
	_check_true("patch hors limites : refusé", not h.patch(99))
	# une planche ne protège pas d'un nouveau choc au même endroit
	h.add_leaks(h.slot_bx(opened[0]), 1, 1)
	_check_true("le même endroit peut se rouvrir", h.has_leak(opened[0]))
	_check_true("la planche saute", not h.is_patched(opened[0]))
	# vitesse et naufrage
	var dry := _hull(cfg)
	_check_near("cale sèche : pleine vitesse", dry.speed_factor(), 1.0)
	dry.water = dry.sink_water
	_check_near("cale pleine : vitesse réduite", dry.speed_factor(), 1.0 - dry.speed_penalty)
	_check_true("cale pleine : le bateau coule", dry.is_sunk())
	dry.reset()
	_check_true("remis à neuf", dry.leaks == 0 and dry.water == 0.0 and not dry.is_sunk())
	var dry2 := _hull(cfg)
	_check_true("cale sèche : rien à écoper", not dry2.bail())
	dry2.add_leaks(0.0, -1, 1)
	for i in 2000:
		dry2.step(1.0)
	_check_true("l'eau ne dépasse jamais le plafond", dry2.water <= dry2.sink_water)


func _test_slots(cfg: Dictionary) -> void:
	var h := _hull(cfg)
	_check_eq("12 emplacements", h.slot_count(), h.slots_per_side * 2)
	var a := h.slot_for_impact(-1000.0, 1)
	var b := h.slot_for_impact(1000.0, 1)
	_check_eq("un impact tout à l'arrière : le premier emplacement", h.slot_rank(a), 0)
	_check_eq("un impact tout à l'avant : le dernier emplacement", h.slot_rank(b), h.slots_per_side - 1)
	_check_true("tribord : emplacements de l'autre moitié", h.slot_side(h.slot_for_impact(0.0, -1)) == -1)
	var last := -999.0
	for r in h.slots_per_side:
		_check_true("les emplacements avancent vers l'étrave (%d)" % r, h.slot_bx(r) > last)
		last = h.slot_bx(r)
	# flanc plein : l'excédent n'est pas perdu mais n'est pas inventé non plus
	var f := _hull(cfg)
	var all := f.add_leaks(0.0, 1, 99)
	_check_eq("un flanc a au plus %d voies d'eau" % f.slots_per_side, all.size(), f.slots_per_side)
	_check_eq("rien de plus quand il est plein", f.add_leaks(0.0, 1, 2).size(), 0)
	var other := f.add_leaks(0.0, -1, 2)
	_check_eq("l'autre flanc est intact", other.size(), 2)


func _test_state(cfg: Dictionary) -> void:
	var h := _hull(cfg)
	h.add_leaks(0.0, 1, 2)
	h.add_leaks(0.0, -1, 1)
	h.patch(h.slot_for_impact(0.0, 1))
	h.water = 0.37
	var copy := _hull(cfg)
	copy.apply_state(h.leaks, h.patched, h.water)
	_check_true("l'état envoyé aux clients est repris tel quel", copy.leaks == h.leaks and copy.patched == h.patched and copy.water == h.water)
	_check_eq("même nombre de voies d'eau", copy.leak_count(), h.leak_count())


func _test_hold(cfg: Dictionary, ship_name: String) -> void:
	var ship := ShipModel.new()
	_check_true("%s : chargé" % ship_name, ship.load_ship(ship_name))
	var hull := _hull(cfg, ship.length)
	var layout := HoldLayout.new()
	layout.setup(ship.length, ship.hatch_pos().x, hull)
	var start := layout.spawn_pos()
	_check_true("%s : cale : arrivée libre" % ship_name, layout.is_walkable(start))
	var reach := _flood(layout, start)
	for it: Dictionary in layout.items():
		var what: String = it["kind"]
		if what == "hole":
			what = "voie d'eau %d" % int(it["slot"])
		_check_true("%s : cale : on atteint %s" % [ship_name, what], _near_reach(reach, it["pos"] as Vector2, 1.2))
	_check_true("%s : l'échelle est dans la cale" % ship_name, absf(layout.hatch_x) < layout.half_len)
	# les voies d'eau sont dans la cale, sur les pentes
	for s in hull.slot_count():
		var p := layout.hole_pos(s)
		_check_true("%s : voie %d à l'intérieur" % [ship_name, s], absf(p.x) < layout.half_len and absf(p.y) < HoldLayout.FLOOR_HALF + HoldLayout.RUN)
	# le côté bâbord est au fond (z négatif)
	_check_true("%s : bâbord au fond, tribord devant" % ship_name,
			layout.hole_pos(0).y < 0.0 and layout.hole_pos(hull.slots_per_side).y > 0.0)
	# un pirate coincé dans un tonneau peut sortir
	var c: Array = layout.circles[0]
	var stuck := Vector2(float(c[0]), float(c[1]))
	_check_true("%s : coincé dans un tonneau, on peut bouger" % ship_name, layout.move_with_slide(stuck, Vector2(-0.05, 0.0)) != stuck)
	_check_near("fond plat : hauteur nulle", HoldLayout.height_at(0.5), 0.0)
	_check_near("haut de la pente : hauteur maximale", HoldLayout.height_at(10.0), HoldLayout.RISE)
	# sur le pont : un impact sur chaque point du contour trouve un emplacement
	for i in 19:
		var info := ship.contour_hit_info(i)
		var slot := hull.slot_for_impact(float(info["bx"]), int(info["side"]))
		_check_true("%s : contour %d -> emplacement valide" % [ship_name, i], slot >= 0 and slot < hull.slot_count())
	ship.free()


func _test_rocks(cfg: Dictionary) -> void:
	var rocks := SeaRocks.new()
	rocks.load_from(cfg)
	_check_true("des récifs sont définis", rocks.rocks.size() > 0)
	var r: Array = rocks.rocks[0]
	var c := Vector2(float(r[0]), float(r[1]))
	_check_eq("un point au centre du récif le touche", rocks.hit([c]).x, 0)
	_check_eq("un point loin du récif ne le touche pas", rocks.hit([c + Vector2(50.0, 50.0)]).x, -1)
	_check_eq("l'indice du point touché est rendu", rocks.hit([c + Vector2(50.0, 50.0), c]).y, 1)
	# aucun récif ne doit bloquer le port ni l'appontement d'arrivée
	for rock: Array in rocks.rocks:
		var p := Vector2(float(rock[0]), float(rock[1]))
		_check_true("récif (%.0f, %.0f) hors du quai" % [p.x, p.y], not Land.hits_land([p]))
		_check_true("récif (%.0f, %.0f) loin de l'appontement" % [p.x, p.y], p.distance_to(Vector2(23.0, 14.0)) > 12.0)
	var ship := ShipModel.new()
	ship.load_ship("brigantin")
	var pts := ship.hull_points_dense(Vector2.ZERO, 0.0)
	_check_eq("85 points de coque", pts.size(), 85)
	var info := ship.dense_hit_info(0)
	_check_true("le premier point est à tribord, à l'arrière", int(info["side"]) == -1 and float(info["bx"]) < 0.0)
	_check_eq("le point central n'a pas de côté", int(ship.dense_hit_info(2)["side"]), 0)
	ship.free()


func _flood(layout: HoldLayout, start: Vector2) -> Dictionary:
	var seen := {_cell(start): true}
	var todo: Array[Vector2i] = [_cell(start)]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if seen.has(n):
				continue
			if layout.is_walkable(Vector2(n.x * STEP, n.y * STEP)):
				seen[n] = true
				todo.append(n)
	return seen


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


func _check_true(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)


func _check_eq(name: String, got: Variant, want: Variant) -> void:
	if got == want:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s : obtenu %s, attendu %s" % [name, str(got), str(want)])


func _check_near(name: String, got: float, want: float) -> void:
	if absf(got - want) < 0.0001:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s : obtenu %f, attendu %f" % [name, got, want])
