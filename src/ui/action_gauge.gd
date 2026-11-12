class_name ActionGauge
extends Control
## La jauge des actions longues (lot 2) : un anneau au centre de l'écran, cerclé de laiton sur fond de bois sombre, qui se remplit
## d'or ; le nom de l'action dessous. Elle apparaît en fondu, et clignote en rouge quand l'action est interrompue.
## Le jeu appelle `show_progress` chaque image tant que l'action dure, `finish` à la fin, `interrupt` si elle est coupée.

const GOLD := Color("e0a93c")
const BRASS := Color("b88a3a")
const WOOD := Color(0.10, 0.06, 0.04, 0.82)
const CREAM := Color("fff1d6")
const RADIUS := 34.0
const WIDTH := 9.0

var _text := ""
var _value := 0.0
var _alpha := 0.0
var _visible_goal := false
var _flash := 0.0          ## 0..1 : éclat doré de fin
var _fail := 0.0           ## 0..1 : rouge d'interruption


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_progress(text: String, value: float) -> void:
	_text = text
	_value = clampf(value, 0.0, 1.0)
	_visible_goal = true
	_fail = 0.0


func finish() -> void:
	_value = 1.0
	_flash = 1.0
	_visible_goal = false


func interrupt() -> void:
	_fail = 1.0
	_visible_goal = false


func hide_now() -> void:
	_visible_goal = false
	_alpha = 0.0


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if _visible_goal else 0.0, delta * (8.0 if _visible_goal else 3.0))
	_flash = maxf(_flash - delta * 2.5, 0.0)
	_fail = maxf(_fail - delta * 2.0, 0.0)
	if _alpha > 0.0 or _flash > 0.0 or _fail > 0.0:
		queue_redraw()


func _draw() -> void:
	var a := maxf(_alpha, maxf(_flash, _fail))
	if a <= 0.01:
		return
	var c := size * 0.5 + Vector2(0.0, 40.0)   # un peu sous le pirate, qui est au centre de la vue
	draw_circle(c, RADIUS + WIDTH * 0.5 + 4.0, Color(WOOD, WOOD.a * a))
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(0.03, 0.02, 0.02, 0.85 * a), WIDTH)
	var fill := GOLD.lerp(Color(1.0, 0.95, 0.7), _flash)
	if _fail > 0.0:
		fill = Color(0.85, 0.2, 0.15)
	if _value > 0.001:
		draw_arc(c, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * _value, 48, Color(fill, a), WIDTH - 2.0)
	draw_arc(c, RADIUS + WIDTH * 0.5 + 1.5, 0.0, TAU, 48, Color(BRASS, a), 2.0)
	draw_arc(c, RADIUS - WIDTH * 0.5 - 1.5, 0.0, TAU, 48, Color(BRASS, 0.7 * a), 1.5)
	if _flash > 0.0:
		draw_arc(c, RADIUS + 10.0 + 14.0 * (1.0 - _flash), 0.0, TAU, 48, Color(1.0, 0.85, 0.35, 0.6 * _flash), 3.0)
	var font := get_theme_default_font()
	var pct := "%d %%" % int(round(_value * 100.0))
	draw_string_outline(font, c + Vector2(-40, 6), pct, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, 5, Color(0.05, 0.03, 0.1, a))
	draw_string(font, c + Vector2(-40, 6), pct, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Color(CREAM, a))
	if _text != "":
		var ty := c.y + RADIUS + WIDTH + 22.0
		draw_string_outline(font, Vector2(c.x - 200.0, ty), _text, HORIZONTAL_ALIGNMENT_CENTER, 400, 17, 6, Color(0.05, 0.03, 0.1, a))
		draw_string(font, Vector2(c.x - 200.0, ty), _text, HORIZONTAL_ALIGNMENT_CENTER, 400, 17, Color(CREAM if _fail <= 0.0 else Color(1.0, 0.6, 0.5), a))
