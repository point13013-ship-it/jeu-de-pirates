class_name PauseMenu
extends Control
## Le menu de la touche Échap, posé sur la partie (elle continue : à plusieurs, on ne met pas le jeu en pause) : reprendre,
## rappeler l'invitation, sortir ou ranger la boussole, retourner au menu principal, quitter.

signal resume
signal show_invite
signal show_quests
signal toggle_compass
signal unstick_ship
signal tow_ship
signal back_to_menu
signal quit_game

const WOOD := Color("3a2415")
const WOOD_LIGHT := Color("5a3820")
const GOLD := Color("e0a93c")
const CREAM := Color("fff1d6")

var _invite_button: Button
var _compass_button: Button
var _back_button: Button
var _volumes: VolumePanel
var _open := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.03, 0.96)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = GOLD
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 20
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	panel.add_child(columns)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	columns.add_child(box)
	_volumes = VolumePanel.new()   # à droite : les volumes (musique, ambiance, effets)
	columns.add_child(_volumes)
	var title := Label.new()
	title.text = "Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	box.add_child(_button("Reprendre   (Échap)", func() -> void: resume.emit()))
	_invite_button = _button("Inviter un ami   (I)", func() -> void: show_invite.emit())
	box.add_child(_invite_button)
	box.add_child(_button("Journal de quêtes   (J)", func() -> void: show_quests.emit()))
	_compass_button = _button("Boussole   (B)", func() -> void: toggle_compass.emit())
	box.add_child(_compass_button)
	box.add_child(_button("Débloquer le bateau   (T, T)", func() -> void: unstick_ship.emit()))
	box.add_child(_button("Ramener le bateau au port", func() -> void: tow_ship.emit()))
	_back_button = _button("Retour au menu principal", func() -> void: back_to_menu.emit())
	box.add_child(_back_button)
	box.add_child(_button("Quitter le jeu", func() -> void: quit_game.emit()))


func is_open() -> bool:
	return _open


## `hosting` : l'hôte voit « Inviter un ami » ; `compass_on` : la boussole est sortie ; `online` : une partie en ligne est en cours
## (on prévient que quitter la coupe).
func open(hosting: bool, compass_on: bool, online: bool) -> void:
	_open = true
	visible = true
	_volumes.refresh()
	_invite_button.visible = hosting
	_compass_button.text = "Ranger la boussole   (B)" if compass_on else "Sortir la boussole   (B)"
	_back_button.text = "Retour au menu principal  (quitte la partie en ligne)" if online else "Retour au menu principal"


func close() -> void:
	_open = false
	visible = false


func refresh_compass(compass_on: bool) -> void:
	_compass_button.text = "Ranger la boussole   (B)" if compass_on else "Sortir la boussole   (B)"


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for state: String in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = WOOD if state == "normal" else (WOOD_LIGHT if state == "hover" else Color("7a4c28"))
		s.set_corner_radius_all(6)
		s.set_border_width_all(2)
		s.border_color = GOLD if state != "normal" else Color("8a6a3a")
		s.content_margin_left = 14
		s.content_margin_right = 14
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(action)
	return b
