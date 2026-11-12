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
	# (12/11 : refait avec le style commun UiTheme — voile sombre dégradé, panneau de bois et laiton, boutons groupés par usage,
	# la touche de chaque action à droite du bouton)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.panel())
	center.add_child(_panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	_panel.add_child(columns)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	columns.add_child(box)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	_volumes = VolumePanel.new()   # à droite : les volumes (musique, ambiance, effets)
	right.add_child(_volumes)
	box.add_child(UiTheme.label("Pause", 34, UiTheme.BRASS, 6))
	box.add_child(UiTheme.label("La partie continue pour l'équipage", 14, UiTheme.MUTED, 2))
	var resume_b := _button("Reprendre", "Échap", func() -> void: resume.emit())
	resume_b.add_theme_stylebox_override("normal", _brass_style())
	box.add_child(resume_b)
	box.add_child(UiTheme.section("Équipage"))
	_invite_button = _button("Inviter un ami", "I", func() -> void: show_invite.emit())
	box.add_child(_invite_button)
	box.add_child(_button("Journal de quêtes", "J", func() -> void: show_quests.emit()))
	_compass_button = _button("Boussole", "B", func() -> void: toggle_compass.emit())
	box.add_child(_compass_button)
	box.add_child(UiTheme.section("Bateau"))
	box.add_child(_button("Débloquer le bateau", "T, T", func() -> void: unstick_ship.emit()))
	box.add_child(_button("Ramener le bateau au port", "", func() -> void: tow_ship.emit()))
	box.add_child(UiTheme.section("Quitter"))
	_back_button = _button("Retour au menu principal", "", func() -> void: back_to_menu.emit())
	box.add_child(_back_button)
	box.add_child(_button("Quitter le jeu", "", func() -> void: quit_game.emit()))


var _panel: PanelContainer


## Le bouton principal (Reprendre) : laiton plein, pour qu'on le trouve d'un coup d'œil.
func _brass_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.BRASS_DARK
	sb.border_color = UiTheme.BRASS
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb


func is_open() -> bool:
	return _open


## `hosting` : l'hôte voit « Inviter un ami » ; `compass_on` : la boussole est sortie ; `online` : une partie en ligne est en cours
## (on prévient que quitter la coupe).
func open(hosting: bool, compass_on: bool, online: bool) -> void:
	_open = true
	visible = true
	_volumes.refresh()
	_invite_button.visible = hosting
	_compass_button.text = "Ranger la boussole" if compass_on else "Sortir la boussole"
	_back_button.text = "Retour au menu principal (quitte la partie)" if online else "Retour au menu principal"
	UiTheme.appear(_panel)


func close() -> void:
	_open = false
	visible = false


func refresh_compass(compass_on: bool) -> void:
	_compass_button.text = "Ranger la boussole" if compass_on else "Sortir la boussole"


## Un bouton du menu : le texte à gauche, la touche du raccourci à droite (en petit, couleur laiton).
func _button(text: String, hotkey: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380, 42)
	b.focus_mode = Control.FOCUS_NONE
	UiTheme.style_button(b, 18)
	if hotkey != "":
		var k := UiTheme.label(hotkey, 14, UiTheme.BRASS, 2)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		k.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		k.offset_left = -90
		k.offset_right = -14
		k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		k.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(k)
	b.pressed.connect(action)
	return b
