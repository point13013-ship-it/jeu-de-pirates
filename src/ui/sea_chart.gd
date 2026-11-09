class_name SeaChart
extends Control
## La carte des mers, sur la table de la cabine : le port, les îles repérées (nom, danger, trésors restants), le bateau
## et son cap. Les îles pas encore vues apparaissent comme une rumeur « ? » avec une position approximative.
## Un clic sur une île fixe le cap (flèche et distance en haut de l'écran) ; R efface le cap ; E ou Échap ferment.

signal destination_chosen(index: int)   ## indice de l'île choisie, ou -1 pour effacer
signal closed

const SAND := Color(0.93, 0.82, 0.56)
const SAND_D := Color(0.78, 0.64, 0.38)
const GRASS := Color(0.55, 0.68, 0.36)
const INK := Color(0.28, 0.17, 0.09)
const INK_L := Color(0.45, 0.3, 0.17)
const PORT_RECT := Rect2(-62.0, -52.0, 104.0, 82.0)   ## le port en gros : x, z, largeur, hauteur

var world: IslandWorld
var discovered: Array = []
var ship_pos := Vector2.ZERO
var ship_dir := Vector2(1, 0)
var destination := -1
var _open := false
var _hover := -1
var _map_rect := Rect2()
var _scale := 1.0
var _origin := Vector2.ZERO   ## monde (x, z) au coin haut-gauche de la carte
var _time := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func is_open() -> bool:
	return _open


func open() -> void:
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hover = -1
	queue_redraw()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func key(code: int) -> void:
	if code == KEY_E or code == KEY_ESCAPE or code == KEY_M:
		close()
	elif code == KEY_R:
		destination = -1
		destination_chosen.emit(-1)
		queue_redraw()


func _process(delta: float) -> void:
	if _open:
		_time += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseMotion:
		_hover = _island_at_screen((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit := _island_at_screen(mb.position)
			if hit >= 0:
				destination = hit
				destination_chosen.emit(hit)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			destination = -1
			destination_chosen.emit(-1)
	accept_event()


## Position de la rumeur d'une île inconnue : décalée de façon fixe, pour ne pas donner l'emplacement exact.
func rumor_pos(i: int) -> Vector2:
	var isl: Dictionary = world.islands[i]
	var h := hash(str(isl["id"]))
	var a := float(h % 628) / 100.0
	return (isl["center"] as Vector2) + Vector2.from_angle(a) * 22.0


func shown_pos(i: int) -> Vector2:
	return (world.islands[i]["center"] as Vector2) if world.islands[i]["id"] in discovered else rumor_pos(i)


## Une île tirée au hasard n'apparaît sur la carte qu'une fois repérée (pas de rumeur : le monde est trop grand) ; celles du
## fichier sont toujours là, en rumeur tant qu'on ne les a pas vues.
func _listed(i: int) -> bool:
	var isl: Dictionary = world.islands[i]
	return not bool(isl.get("proc", false)) or isl["id"] in discovered


func _island_at_screen(sp: Vector2) -> int:
	var best := -1
	var best_d := 1e9
	for i in world.islands.size():
		if not _listed(i):
			continue
		var known: bool = world.islands[i]["id"] in discovered
		var radius_px := maxf((float(world.islands[i]["radius"]) if known else 40.0) * _scale, 22.0)
		var d := _to_screen(shown_pos(i)).distance_to(sp)
		if d < radius_px and d < best_d:
			best_d = d
			best = i
	return best


func _layout() -> void:
	var margin := Vector2(70, 44)
	var panel := Rect2(margin, size - margin * 2.0)
	_map_rect = panel.grow_individual(-26, -64, -26, -50)
	# la carte couvre le port et toutes les îles, avec de l'air autour
	var lo := Vector2(PORT_RECT.position)
	var hi := PORT_RECT.end
	for k in world.islands.size():
		if not _listed(k):
			continue
		var isl: Dictionary = world.islands[k]
		var c: Vector2 = isl["center"]
		var r: float = float(isl["radius"]) + 54.0
		lo = Vector2(minf(lo.x, c.x - r), minf(lo.y, c.y - r))
		hi = Vector2(maxf(hi.x, c.x + r), maxf(hi.y, c.y + r))
	var span := hi - lo
	_scale = minf(_map_rect.size.x / span.x, _map_rect.size.y / span.y)
	_origin = lo - (_map_rect.size / _scale - span) * 0.5


func _to_screen(w: Vector2) -> Vector2:
	return _map_rect.position + (w - _origin) * _scale


func _draw() -> void:
	if not _open or world == null:
		return
	_layout()
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.05, 0.62))
	var panel := Rect2(Vector2(70, 44), size - Vector2(140, 88))
	draw_rect(panel.grow(6), INK)
	draw_rect(panel, Color(0.87, 0.76, 0.52))
	# taches de vieux papier
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 26:
		var p := panel.position + Vector2(rng.randf() * panel.size.x, rng.randf() * panel.size.y)
		draw_circle(p, rng.randf_range(14.0, 60.0), Color(0.78, 0.64, 0.4, 0.09))
	# la mer
	draw_rect(_map_rect, Color(0.62, 0.77, 0.74, 0.55))
	draw_rect(_map_rect, INK_L, false, 2.0)
	_draw_grid()
	# le port
	var pr := Rect2(_to_screen(PORT_RECT.position), PORT_RECT.size * _scale)
	draw_rect(pr, SAND_D)
	draw_rect(pr.grow(-3), SAND)
	draw_string(font, pr.position + Vector2(0, pr.size.y * 0.5 + 6), "PORT", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 15, INK)
	# les îles
	for i in world.islands.size():
		if not _listed(i):
			continue
		if world.islands[i]["id"] in discovered:
			_draw_island(i, font)
		else:
			_draw_rumor(i, font)
	_draw_route()
	_draw_ship()
	_draw_compass(font)
	draw_string(font, panel.position + Vector2(0, 38), "CARTE DES MERS", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 28, INK)
	var hint := "Clic : fixer le cap sur une île      R / clic droit : effacer le cap      E ou Échap : replier la carte"
	draw_string(font, Vector2(panel.position.x, panel.end.y - 16), hint, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 15, INK)
	if _hover >= 0:
		_draw_tooltip(_hover, font)


func _draw_grid() -> void:
	var font := get_theme_default_font()
	var step := 100.0
	var x := ceilf(_origin.x / step) * step
	while _to_screen(Vector2(x, 0)).x < _map_rect.end.x:
		var sx := _to_screen(Vector2(x, 0)).x
		if sx > _map_rect.position.x:
			draw_line(Vector2(sx, _map_rect.position.y), Vector2(sx, _map_rect.end.y), Color(0.3, 0.2, 0.1, 0.16), 1.0)
		x += step
	var z := ceilf(_origin.y / step) * step
	while _to_screen(Vector2(0, z)).y < _map_rect.end.y:
		var sy := _to_screen(Vector2(0, z)).y
		if sy > _map_rect.position.y:
			draw_line(Vector2(_map_rect.position.x, sy), Vector2(_map_rect.end.x, sy), Color(0.3, 0.2, 0.1, 0.16), 1.0)
			draw_string(font, Vector2(_map_rect.position.x + 6, sy - 3), "%d m" % int(z), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.2, 0.1, 0.5))
		z += step


func _draw_island(i: int, font: Font) -> void:
	var isl: Dictionary = world.islands[i]
	var lobes: Array = isl["lobes"]
	var center := _to_screen(isl["center"])
	# à cette échelle une île ne ferait que quelques pixels : on l'agrandit pour qu'elle se lise
	var k := maxf(1.0, 34.0 / (float(isl["radius"]) * _scale))
	var rad_px := float(isl["radius"]) * _scale * k
	for l: Vector3 in lobes:
		draw_circle(center + (_to_screen(Vector2(l.x, l.y)) - center) * k, (l.z + 2.2) * _scale * k, SAND_D)
	for l: Vector3 in lobes:
		draw_circle(center + (_to_screen(Vector2(l.x, l.y)) - center) * k, l.z * _scale * k, SAND)
	for l: Vector3 in lobes:
		draw_circle(center + (_to_screen(Vector2(l.x, l.y)) - center) * k, maxf(l.z - 2.6, 1.0) * _scale * k, GRASS)
	# les coffres encore fermés : une croix rouge à leur place
	for ch_id: int in isl["chests"]:
		var ch: Dictionary = world.chests[ch_id]
		var sp := center + (_to_screen(ch["pos"]) - center) * k
		if ch["open"]:
			draw_circle(sp, 3.0, Color(0.4, 0.3, 0.2, 0.7))
		else:
			var s := 5.0
			draw_line(sp + Vector2(-s, -s), sp + Vector2(s, s), Color(0.75, 0.1, 0.08), 3.0)
			draw_line(sp + Vector2(-s, s), sp + Vector2(s, -s), Color(0.75, 0.1, 0.08), 3.0)
	draw_string(font, Vector2(center.x - 120, center.y + rad_px + 20.0), str(isl["name"]), HORIZONTAL_ALIGNMENT_CENTER, 240, 16, INK)
	if destination == i:
		_draw_flag(center - Vector2(0, rad_px * 0.4))


func _draw_rumor(i: int, font: Font) -> void:
	var c := _to_screen(rumor_pos(i))
	var r := 40.0 * _scale
	var segs := 18
	for k in segs:
		if k % 2 == 0:
			var a0 := TAU * k / segs
			var a1 := TAU * (k + 1) / segs
			draw_arc(c, r, a0, a1, 6, Color(0.3, 0.2, 0.1, 0.6), 2.0)
	draw_string(font, c + Vector2(-20, 14), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 40, Color(0.3, 0.2, 0.1, 0.75))
	draw_string(font, c + Vector2(-60, r + 18), "Terre inconnue", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.3, 0.2, 0.1, 0.65))
	if destination == i:
		_draw_flag(c - Vector2(0, 10))


func _draw_flag(at: Vector2) -> void:
	draw_line(at, at + Vector2(0, -34), INK, 3.0)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -34), at + Vector2(24, -27), at + Vector2(0, -20)]), Color(0.78, 0.1, 0.1))


func _draw_route() -> void:
	if destination < 0:
		return
	var a := _to_screen(ship_pos)
	var b := _to_screen(shown_pos(destination))
	var d := b - a
	var len := d.length()
	if len < 1.0:
		return
	var dir := d / len
	var t := fmod(_time * 30.0, 16.0)
	while t < len:
		draw_line(a + dir * t, a + dir * minf(t + 8.0, len), Color(0.75, 0.1, 0.08, 0.9), 3.0)
		t += 16.0


func _draw_ship() -> void:
	var c := _to_screen(ship_pos)
	var d := ship_dir.normalized() if ship_dir.length() > 0.01 else Vector2(1, 0)
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([c + d * 16.0, c - d * 11.0 + n * 8.0, c - d * 6.0, c - d * 11.0 - n * 8.0])
	draw_colored_polygon(pts, Color(0.1, 0.2, 0.5))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.95, 0.92, 0.8), 2.0)


func _draw_compass(font: Font) -> void:
	# la rose des vents : le nord est en haut de la carte, l'est à droite (comme les coordonnées du monde : x vers l'est, z vers le sud)
	var c := Vector2(_map_rect.end.x - 78, _map_rect.end.y - 78)
	var r := 36.0
	draw_circle(c, r, Color(0.9, 0.8, 0.58, 0.85))
	draw_arc(c, r, 0.0, TAU, 40, INK, 2.0)
	for k in 16:   # graduations : plus longues aux quatre points cardinaux
		var a := TAU * float(k) / 16.0
		var dir := Vector2(sin(a), -cos(a))
		draw_line(c + dir * (r - (8.0 if k % 4 == 0 else 4.0)), c + dir * r, INK, 1.5)
	var red := Color(0.75, 0.12, 0.1)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r + 3), c + Vector2(7, 0), c + Vector2(-7, 0)]), red)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, r - 3), c + Vector2(7, 0), c + Vector2(-7, 0)]), INK)
	draw_colored_polygon(PackedVector2Array([c + Vector2(r - 3, 0), c + Vector2(0, 7), c + Vector2(0, -7)]), INK)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r + 3, 0), c + Vector2(0, 7), c + Vector2(0, -7)]), INK)
	draw_circle(c, 3.0, Color(0.9, 0.8, 0.58))
	# les quatre lettres, avec un liseré clair pour rester lisibles sur la carte
	for spec: Array in [["N", Vector2(0, -r - 8)], ["S", Vector2(0, r + 21)], ["E", Vector2(r + 16, 6)], ["W", Vector2(-r - 16, 6)]]:
		var pos: Vector2 = c + (spec[1] as Vector2) + Vector2(-9, 0)
		draw_string_outline(font, pos, str(spec[0]), HORIZONTAL_ALIGNMENT_CENTER, 18, 17, 4, Color(0.95, 0.88, 0.7))
		draw_string(font, pos, str(spec[0]), HORIZONTAL_ALIGNMENT_CENTER, 18, 17, red if spec[0] == "N" else INK)


func _draw_tooltip(i: int, font: Font) -> void:
	var isl: Dictionary = world.islands[i]
	var known: bool = isl["id"] in discovered
	var lines: Array[String] = []
	if known:
		lines.append(str(isl["name"]))
		lines.append(str(isl["blurb"]))
		var danger: int = isl["danger"]
		lines.append("Danger : " + ("paisible" if danger == 0 else "%s" % "I".repeat(danger) + " / III"))
		lines.append("Ennemis en vie : %d   Coffres fermés : %d / %d" % [world.enemies_alive(i), world.chests_left(i), (isl["chests"] as Array).size()])
	else:
		lines.append("Terre inconnue")
		lines.append("Une rumeur parle d'une île par ici…")
		lines.append("Approche-toi pour la repérer.")
	lines.append("Distance : %d m" % int(ship_pos.distance_to(shown_pos(i))))
	var w := 380.0
	var h := 28.0 + lines.size() * 21.0
	var at := _to_screen(shown_pos(i)) + Vector2(30, -h * 0.5)
	at.x = clampf(at.x, _map_rect.position.x + 8.0, _map_rect.end.x - w - 8.0)
	at.y = clampf(at.y, _map_rect.position.y + 8.0, _map_rect.end.y - h - 8.0)
	draw_rect(Rect2(at, Vector2(w, h)), Color(0.12, 0.07, 0.04, 0.94))
	draw_rect(Rect2(at, Vector2(w, h)), Color(0.85, 0.68, 0.3), false, 2.0)
	for k in lines.size():
		var col := Color(1.0, 0.85, 0.45) if k == 0 else Color(1.0, 0.95, 0.85)
		draw_string(font, at + Vector2(12, 24 + k * 21), lines[k], HORIZONTAL_ALIGNMENT_LEFT, w - 24, 16 if k == 0 else 14, col)
