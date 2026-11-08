class_name SailHud
extends Control
## Le cadran du vent : le bateau vu de dessus, étrave en haut. La flèche bleue montre où souffle le vent, la vergue
## crème l'orientation actuelle des voiles, le repère vert l'orientation idéale pour ce vent. Dessous, le rendement.

const SIZE := 132.0
const BACK := Color(0.05, 0.03, 0.1, 0.72)
const RING := Color(0.88, 0.66, 0.24, 0.9)
const HULL := Color(0.62, 0.42, 0.24)
const WIND := Color(0.45, 0.82, 1.0)
const YARD := Color(1.0, 0.95, 0.78)
const GOOD := Color(0.45, 0.95, 0.5)
const MID := Color(1.0, 0.82, 0.3)
const BAD := Color(1.0, 0.38, 0.3)

var wind_rel := 0.0      ## rad : où souffle le vent par rapport à l'étrave (0 = vers l'étrave)
var trim := 0.0          ## rad : orientation actuelle des vergues
var optimal := 0.0       ## rad : orientation idéale
var efficiency := 1.0    ## 0..1 : rendement du réglage
var sails_up := true     ## voiles hissées : sans voile, pas de vergues à régler
var active := false      ## quelqu'un est au mât : le cadran s'agrandit un peu
var _font: Font


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE + 26.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func set_state(p_wind: float, p_trim: float, p_opt: float, p_eff: float, p_up: bool, p_active: bool) -> void:
	if is_equal_approx(p_wind, wind_rel) and is_equal_approx(p_trim, trim) and is_equal_approx(p_opt, optimal) \
			and is_equal_approx(p_eff, efficiency) and p_up == sails_up and p_active == active:
		return
	wind_rel = p_wind
	trim = p_trim
	optimal = p_opt
	efficiency = p_eff
	sails_up = p_up
	active = p_active
	queue_redraw()


## Direction d'écran (y vers le bas) d'un angle relatif à l'étrave, étrave en haut : même sens que Vector2.rotated.
static func dial_dir(angle: float) -> Vector2:
	return Vector2(0.0, -1.0).rotated(angle)


func _draw() -> void:
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	var r := SIZE * 0.5 - 4.0
	draw_circle(c, SIZE * 0.5, BACK)
	draw_arc(c, r, 0.0, TAU, 48, RING, 2.0)
	# l'étrave en haut : un petit repère
	draw_line(c + Vector2(0, -r), c + Vector2(0, -r + 7.0), RING, 3.0)
	# le bateau vu de dessus
	var hull := PackedVector2Array([c + Vector2(0, -26), c + Vector2(9, -8), c + Vector2(8, 22), c + Vector2(-8, 22), c + Vector2(-9, -8)])
	draw_colored_polygon(hull, HULL)
	draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[4], hull[0]]), Color(0.2, 0.12, 0.06), 1.5)
	# le vent : une flèche qui traverse le cadran vers où il souffle
	var wd := dial_dir(wind_rel)
	var w0 := c - wd * (r - 6.0)
	var w1 := c + wd * (r - 6.0)
	draw_line(w0, w1, WIND, 3.0)
	var side := Vector2(-wd.y, wd.x)
	draw_colored_polygon(PackedVector2Array([w1, w1 - wd * 11.0 + side * 6.0, w1 - wd * 11.0 - side * 6.0]), WIND)
	if sails_up:
		# la vergue : perpendiculaire à la normale de voile ; le repère vert marque l'idéal
		var yard := dial_dir(trim + PI * 0.5)
		var ideal := dial_dir(optimal + PI * 0.5)
		draw_line(c - ideal * 24.0, c + ideal * 24.0, Color(GOOD, 0.55), 2.0)
		draw_circle(c + ideal * 24.0, 3.0, GOOD)
		draw_circle(c - ideal * 24.0, 3.0, GOOD)
		draw_line(c - yard * 22.0, c + yard * 22.0, YARD, 5.0 if active else 4.0)
	var col := GOOD if efficiency > 0.85 else (MID if efficiency > 0.55 else BAD)
	var text := "Voiles : %d %%" % int(efficiency * 100.0) if sails_up else "Voiles affalées"
	draw_string(_font, Vector2(2, SIZE + 18.0), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 15, col)
