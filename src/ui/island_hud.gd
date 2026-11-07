class_name IslandHud
extends Control
## Ce que le joueur voit en explorant : ses points de vie (cœurs, visibles seulement à terre ou blessé), la flèche vers
## l'île choisie sur la carte (avec le nom et la distance), et un voile rouge quand il est touché.

var hp := 6
var hp_max := 6
var show_hearts := false
var dest_name := ""
var dest_dist := 0.0
var dest_angle := 0.0      ## angle de la flèche, 0 = vers le haut de l'écran, dans le sens des aiguilles d'une montre
var dest_visible := false
var flash := 0.0           ## 0..1 : voile rouge
var blink := false         ## cœurs qui clignotent (invulnérable)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if flash > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.05, 0.05, 0.38 * flash))
	if show_hearts:
		for i in hp_max:
			var c := Vector2(30 + i * 30, 108)
			var full := i < hp
			var col := Color(0.9, 0.12, 0.16) if full else Color(0.2, 0.1, 0.12, 0.8)
			if blink and full and int(Time.get_ticks_msec() / 90) % 2 == 0:
				col = Color(1, 0.7, 0.7)
			_heart(c, 11.0, col)
	if dest_visible:
		var font := get_theme_default_font()
		var c := Vector2(size.x * 0.5, 58)
		draw_circle(c, 30.0, Color(0.05, 0.03, 0.1, 0.7))
		draw_arc(c, 30.0, 0, TAU, 32, Color(0.85, 0.68, 0.3), 2.0)
		var d := Vector2(sin(dest_angle), -cos(dest_angle))
		var n := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([c + d * 24.0, c - d * 10.0 + n * 13.0, c - d * 4.0, c - d * 10.0 - n * 13.0]), Color(1.0, 0.82, 0.3))
		var text := "%s — %d m" % [dest_name, int(dest_dist)]
		draw_string(font, Vector2(c.x - 200, c.y + 50), text, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, Color(1, 0.95, 0.8))


func _heart(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(-r * 0.5, -r * 0.25), r * 0.58, col)
	draw_circle(c + Vector2(r * 0.5, -r * 0.25), r * 0.58, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.05, -r * 0.1), c + Vector2(r * 1.05, -r * 0.1), c + Vector2(0, r * 1.05)]), col)
