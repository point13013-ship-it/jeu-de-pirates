class_name IslandHud
extends Control
## Ce que le joueur voit en explorant : ses points de vie (cœurs, visibles seulement à terre ou blessé), la flèche vers
## l'île choisie sur la carte (avec le nom et la distance), et un voile rouge quand il est touché.

var hp := 6
var hp_max := 6
var show_hearts := false
var hearts_y := 108.0      ## hauteur des cœurs à l'écran
var dest_name := ""
var dest_dist := 0.0
var dest_angle := 0.0      ## angle de la flèche, 0 = vers le haut de l'écran, dans le sens des aiguilles d'une montre
var dest_visible := false
var flash := 0.0           ## 0..1 : voile rouge
var blink := false         ## cœurs qui clignotent (invulnérable)
var show_spells := false   ## barre des 4 sorts de la baie portée
var berry_name := ""
var berry_color := Color.WHITE
var spells: Array = []     ## [{label, cd}] : cd = part de recharge restante, 0 à 1 ; label « ??? » tant que le sort n'a pas servi


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
			var c := Vector2(30 + i * 30, hearts_y)
			var full := i < hp
			var col := Color(0.9, 0.12, 0.16) if full else Color(0.2, 0.1, 0.12, 0.8)
			if blink and full and int(Time.get_ticks_msec() / 90) % 2 == 0:
				col = Color(1, 0.7, 0.7)
			_heart(c, 11.0, col)
	if show_spells:
		_draw_spells()
	if dest_visible:
		var font := get_theme_default_font()
		# 13/11 : une vraie boussole (elle ne s'affiche que boussole en main) : boîtier de laiton, cadran sombre, graduations,
		# aiguille dorée vers le cap, nom et distance dessous sur deux lignes
		var c := Vector2(size.x * 0.5, 70)
		var brass := Color("DCAE5C")
		draw_circle(c, 40.0, Color("3A2630"))
		draw_circle(c, 35.0, Color("1C1726"))
		draw_arc(c, 40.0, 0, TAU, 48, brass, 3.0)
		draw_arc(c, 34.0, 0, TAU, 48, Color(brass, 0.45), 1.0)
		for k in 16:
			var a := TAU * float(k) / 16.0
			var v := Vector2(sin(a), -cos(a))
			var major := k % 4 == 0
			draw_line(c + v * (27.0 if major else 30.0), c + v * 33.0, Color(brass, 0.9 if major else 0.5), 2.0 if major else 1.0)
		draw_string(font, c + Vector2(-5, -15), "N", HORIZONTAL_ALIGNMENT_LEFT, 20, 12, Color("EFE4CC"))
		var d := Vector2(sin(dest_angle), -cos(dest_angle))
		var n := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([c + d * 30.0, c + n * 6.0, c - n * 6.0]), Color("FFD23F"))
		draw_colored_polygon(PackedVector2Array([c - d * 22.0, c + n * 6.0, c - n * 6.0]), Color("7D7488"))
		draw_circle(c, 4.0, brass)
		draw_string_outline(font, Vector2(c.x - 200, c.y + 60), dest_name, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, 5, Color(0.05, 0.03, 0.1))
		draw_string(font, Vector2(c.x - 200, c.y + 60), dest_name, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, Color("EFE4CC"))
		var dist := "%d m" % int(dest_dist)
		draw_string_outline(font, Vector2(c.x - 200, c.y + 78), dist, HORIZONTAL_ALIGNMENT_CENTER, 400, 13, 4, Color(0.05, 0.03, 0.1))
		draw_string(font, Vector2(c.x - 200, c.y + 78), dist, HORIZONTAL_ALIGNMENT_CENTER, 400, 13, Color("DCAE5C"))


## Les 4 sorts de la baie, en bas à gauche : une case par sort (touche 1 à 4), voile sombre qui descend pendant la recharge.
func _draw_spells() -> void:
	var font := get_theme_default_font()
	var slot := 58.0
	var gap := 8.0
	var x0 := 18.0
	var y0 := size.y - slot - 44.0
	draw_string_outline(font, Vector2(x0, y0 - 10), berry_name, HORIZONTAL_ALIGNMENT_LEFT, 320, 16, 5, Color(0.05, 0.03, 0.1))
	draw_string(font, Vector2(x0, y0 - 10), berry_name, HORIZONTAL_ALIGNMENT_LEFT, 320, 16, berry_color.lightened(0.35))
	for i in spells.size():
		var sp: Dictionary = spells[i]
		var r := Rect2(x0 + i * (slot + gap), y0, slot, slot)
		var ready := float(sp["cd"]) <= 0.0
		draw_rect(r, Color(0.07, 0.05, 0.1, 0.82))
		draw_rect(r.grow(-5.0), Color(berry_color, 0.38 if ready else 0.14))
		var known := str(sp["label"]) != "???"
		var center := r.get_center()
		draw_string(font, center + Vector2(-6, 9), "?" if not known else str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 14, 26, Color(1, 1, 1, 0.9 if ready else 0.4))
		if not ready:
			var h := r.size.y * float(sp["cd"])
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - h), Vector2(r.size.x, h)), Color(0, 0, 0, 0.55))
		draw_rect(r, berry_color if ready else Color(0.4, 0.35, 0.3), false, 2.0)
		draw_string(font, r.position + Vector2(5, 13), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, 20, 12, Color(1, 0.95, 0.8))
		var lp := r.position + Vector2(-8, slot + 16)
		draw_string_outline(font, lp, str(sp["label"]), HORIZONTAL_ALIGNMENT_CENTER, slot + 16, 13, 5, Color(0.05, 0.03, 0.1))
		draw_string(font, lp, str(sp["label"]), HORIZONTAL_ALIGNMENT_CENTER, slot + 16, 13, Color(1, 0.95, 0.85))


func _heart(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(-r * 0.5, -r * 0.25), r * 0.58, col)
	draw_circle(c + Vector2(r * 0.5, -r * 0.25), r * 0.58, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.05, -r * 0.1), c + Vector2(r * 1.05, -r * 0.1), c + Vector2(0, r * 1.05)]), col)
