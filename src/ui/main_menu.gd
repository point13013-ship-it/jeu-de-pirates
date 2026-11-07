class_name MainMenu
extends Control
## Écran d'accueil : le titre, ton pirate (animé), et les choix de départ — jouer seul, héberger, rejoindre un
## ami, modifier ton pirate. Il se pose sur la mer vivante du jeu.

signal play_solo(ship: String)
signal host_game(ship: String)
signal join_game(code: String)
signal edit_pirate
signal quit_game

const SHIPS := [
	["sloop", "Sloop", "2 places — vif et maniable"],
	["brigantin", "Brigantin", "3 places — le bon compromis"],
	["galion", "Galion", "4 places — lourd, puissant"],
]
const WOOD := Color("3a2415")
const WOOD_LIGHT := Color("5a3820")
const GOLD := Color("e0a93c")
const CREAM := Color("fff1d6")

var ship := "brigantin"
var _ship_buttons: Dictionary = {}
var _join_row: HBoxContainer
var _code_edit: LineEdit
var _hint: Label
var _preview: Sprite2D
var _stage: Control
var _look: Dictionary
var _time := 0.0
var _textures: Dictionary = {}


func _init(look: Dictionary = {}) -> void:
	_look = look


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sea := ColorRect.new()
	sea.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/menu_sea.gdshader")
	sea.material = mat
	add_child(sea)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 40)
	margin.add_child(root)
	root.add_child(_build_left())
	root.add_child(_build_right())
	_choose_ship(ship)
	set_look(_look if not _look.is_empty() else PirateLook.load_saved())


## Change l'apparence montrée à droite.
func set_look(look: Dictionary) -> void:
	_look = look
	_textures.clear()
	for a in ["idle", "walk"]:
		var tex: Texture2D = await PirateSprite.texture_for(look, a)
		if tex != null and _look == look:
			_textures[a] = tex


func _process(delta: float) -> void:
	_time += delta
	var tex: Texture2D = _textures.get("idle")
	if tex == null or _preview == null:
		return
	var frames: int = int(PirateLook.catalog()["anims"]["idle"])
	_preview.texture = tex
	_preview.hframes = frames
	_preview.vframes = 8
	_preview.frame = 0 * frames + int(_time * 3.0) % frames
	var px := clampi(int(_stage.size.y / 90.0), 3, 9)
	_preview.scale = Vector2(px, px)
	_preview.position = Vector2(_stage.size.x * 0.5, _stage.size.y * 0.5 + 8.0 * px)


func _build_left() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "JEU DE PIRATES"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Aventure en équipage, de 1 à 4 pirates"
	sub.add_theme_color_override("font_color", CREAM)
	sub.add_theme_font_size_override("font_size", 18)
	box.add_child(sub)
	box.add_child(_gap(4))
	var ship_label := Label.new()
	ship_label.text = "Ton bateau"
	ship_label.add_theme_color_override("font_color", CREAM)
	box.add_child(ship_label)
	var ships := HBoxContainer.new()
	ships.add_theme_constant_override("separation", 8)
	box.add_child(ships)
	for s: Array in SHIPS:
		var b := Button.new()
		b.text = s[1]
		b.tooltip_text = s[2]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130, 40)
		_style_button(b, false)
		b.pressed.connect(_choose_ship.bind(s[0]))
		ships.add_child(b)
		_ship_buttons[s[0]] = b
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	_hint.add_theme_font_size_override("font_size", 14)
	box.add_child(_hint)
	box.add_child(_gap(2))
	box.add_child(_big_button("Jouer seul", func() -> void: play_solo.emit(ship)))
	box.add_child(_big_button("Héberger une partie", func() -> void: host_game.emit(ship)))
	box.add_child(_big_button("Rejoindre un ami", _toggle_join))
	_join_row = HBoxContainer.new()
	_join_row.visible = false
	_join_row.add_theme_constant_override("separation", 8)
	box.add_child(_join_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Code d'invitation (ex. K7QD-M2XP-9WAB)"
	_code_edit.custom_minimum_size = Vector2(290, 40)
	_code_edit.text_submitted.connect(func(t: String) -> void: join_game.emit(t.strip_edges()))
	_join_row.add_child(_code_edit)
	var go := Button.new()
	go.text = "Rejoindre"
	go.custom_minimum_size = Vector2(130, 40)
	_style_button(go, true)
	go.pressed.connect(func() -> void: join_game.emit(_code_edit.text.strip_edges()))
	_join_row.add_child(go)
	box.add_child(_big_button("Mon pirate (apparence)", func() -> void: edit_pirate.emit()))
	box.add_child(_big_button("Quitter", func() -> void: quit_game.emit()))
	var tips := Label.new()
	tips.text = "ZQSD / flèches : marcher   Espace : sauter   E : agir   R : agir autrement"
	tips.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	tips.add_theme_font_size_override("font_size", 13)
	box.add_child(tips)
	return box


func _build_right() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(300, 300)
	box.add_child(_stage)
	var plank := ColorRect.new()
	plank.color = Color(0.0, 0.0, 0.0, 0.0)
	_stage.add_child(plank)
	_preview = Sprite2D.new()
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage.add_child(_preview)
	var name_label := Label.new()
	name_label.text = "Ton pirate"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", GOLD)
	box.add_child(name_label)
	return box


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _big_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 19)
	_style_button(b, true)
	b.pressed.connect(action)
	return b


func _style_button(b: Button, solid: bool) -> void:
	var states := {"normal": WOOD, "hover": WOOD_LIGHT, "pressed": Color("7a4c28"), "focus": WOOD}
	for state: String in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[state]
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(2)
		sb.border_color = GOLD if state != "normal" or solid else Color("8a6a3a")
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		b.add_theme_stylebox_override(state, sb)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color("8a5a2a")
	sel.set_corner_radius_all(6)
	sel.set_border_width_all(3)
	sel.border_color = GOLD
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)


func _choose_ship(name_id: String) -> void:
	ship = name_id
	for id: String in _ship_buttons:
		(_ship_buttons[id] as Button).set_pressed_no_signal(id == name_id)
	for s: Array in SHIPS:
		if s[0] == name_id:
			_hint.text = str(s[2])


func _toggle_join() -> void:
	_join_row.visible = not _join_row.visible
	if _join_row.visible:
		_code_edit.grab_focus()
