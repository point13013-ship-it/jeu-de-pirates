class_name MainMenu
extends Control
## Écran d'accueil : le titre, ton pirate (animé), et les choix de départ — jouer seul, héberger, rejoindre un
## ami, modifier ton pirate. Il se pose sur la mer vivante du jeu.

signal play_solo(ship: String)
signal preview_town(ship: String)   ## (13/11 : jouer seul dans la nouvelle ville en chantier)
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
var _name_edit: LineEdit
var _message: Label
var _hint: Label
var _volume_panel: VolumePanel
var _preview: Sprite2D
var _stage: Control
var _look: Dictionary
var _time := 0.0
var _textures: Dictionary = {}
var _jetty: Dictionary = {}          ## les morceaux du ponton sous le pirate (ColorRect)
var _feet_tex: Texture2D
var _feet_row := 0                   ## dernière ligne opaque de la première image du pirate (ses semelles)


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
	# (12/11 : refait avec le style commun — les choix sur un panneau de bois translucide posé sur la mer qui bouge)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel(0.86))
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_child(_build_left())
	root.add_child(card)
	root.add_child(_build_right())
	UiTheme.appear(card)
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
	_place_jetty(tex, frames, float(px))


## Le ponton : posé sous les semelles du pirate, il file jusqu'au bord droit de l'écran.
func _place_jetty(tex: Texture2D, frames: int, px: float) -> void:
	var cell := Vector2(tex.get_width() / float(frames), tex.get_height() / 8.0)
	if tex != _feet_tex:
		_feet_tex = tex
		_feet_row = int(cell.y) - 1
		var img := tex.get_image()
		for y in range(int(cell.y) - 1, -1, -1):
			var solid := false
			for x in int(cell.x):
				if img.get_pixel(x, y).a > 0.5:
					solid = true
					break
			if solid:
				_feet_row = y
				break
	var feet := _preview.position.y + (float(_feet_row) + 1.0 - cell.y * 0.5) * px
	var left := _preview.position.x - 15.0 * px
	var width := _stage.size.x - left + 60.0
	(_jetty["edge"] as ColorRect).position = Vector2(left, feet)
	(_jetty["edge"] as ColorRect).size = Vector2(width, px)
	(_jetty["deck"] as ColorRect).position = Vector2(left, feet + px)
	(_jetty["deck"] as ColorRect).size = Vector2(width, 3.0 * px)
	(_jetty["under"] as ColorRect).position = Vector2(left + px, feet + 4.0 * px)
	(_jetty["under"] as ColorRect).size = Vector2(width, 2.0 * px)
	(_jetty["post_a"] as ColorRect).position = Vector2(left + 3.0 * px, feet + 4.0 * px)
	(_jetty["post_a"] as ColorRect).size = Vector2(3.0 * px, 400.0)
	(_jetty["post_b"] as ColorRect).position = Vector2(left + 34.0 * px, feet + 4.0 * px)
	(_jetty["post_b"] as ColorRect).size = Vector2(3.0 * px, 400.0)


func _build_left() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 8)
	var title := UiTheme.label("JEU DE PIRATES", 54, UiTheme.BRASS, 14)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)
	box.add_child(UiTheme.label("Aventure en équipage, de 1 à 4 pirates", 18, CREAM, 3))
	box.add_child(_gap(4))
	PlayerName.load_saved()
	var name_row := HBoxContainer.new()   # le pseudo, affiché en petit au-dessus de ton pirate
	name_row.add_theme_constant_override("separation", 8)
	box.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Ton pseudo"
	name_label.add_theme_color_override("font_color", CREAM)
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Choisis un pseudo"
	_name_edit.max_length = PlayerName.MAX_LENGTH
	_name_edit.text = PlayerName.value
	_name_edit.custom_minimum_size = Vector2(240, 32)
	_name_edit.text_changed.connect(func(t: String) -> void: PlayerName.set_name_value(t))
	name_row.add_child(_name_edit)
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
	var solo := _big_button("Jouer seul", func() -> void: play_solo.emit(ship))
	var brass := StyleBoxFlat.new()   # le bouton principal, en laiton plein
	brass.bg_color = UiTheme.BRASS_DARK
	brass.border_color = UiTheme.BRASS
	brass.set_border_width_all(2)
	brass.set_corner_radius_all(7)
	solo.add_theme_stylebox_override("normal", brass)
	box.add_child(solo)
	box.add_child(_big_button("Héberger une partie", func() -> void: host_game.emit(ship)))
	# 13/11 : la nouvelle ville (design/ville-v3) se visite seul tant qu'elle est en chantier ; les parties à plusieurs gardent l'ancienne
	box.add_child(_big_button("Aperçu : la nouvelle ville (seul)", func() -> void: preview_town.emit(ship)))
	box.add_child(_big_button("Rejoindre un ami", _toggle_join))
	_join_row = HBoxContainer.new()
	_join_row.visible = false
	_join_row.add_theme_constant_override("separation", 8)
	box.add_child(_join_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Adresse IP de ton ami (ex. 82.12.34.56) ou code"
	_code_edit.custom_minimum_size = Vector2(290, 40)
	_code_edit.text_submitted.connect(func(t: String) -> void: join_game.emit(t.strip_edges()))
	_join_row.add_child(_code_edit)
	var go := Button.new()
	go.text = "Rejoindre"
	go.custom_minimum_size = Vector2(130, 40)
	_style_button(go, true)
	go.pressed.connect(func() -> void: join_game.emit(_code_edit.text.strip_edges()))
	_join_row.add_child(go)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(430, 0)
	_message.visible = false
	_message.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_message.add_theme_font_size_override("font_size", 15)
	box.add_child(_message)
	box.add_child(_big_button("Mon pirate (apparence)", func() -> void: edit_pirate.emit()))
	box.add_child(_big_button("Sons, musique et affichage", func() -> void: _volume_panel.visible = not _volume_panel.visible))
	box.add_child(_big_button("Quitter", func() -> void: quit_game.emit()))
	var tips := Label.new()
	tips.text = "ZQSD / flèches : marcher   Espace : sauter   Maj : courir   E : agir   R : lâcher / agir autrement\nÉchap : menu   Tab : sac   B : boussole   J : quêtes   I : invitation (hôte)   Maj+M : couper le son   M : vol libre (essais)\nMolette enfoncée + souris : tourner et incliner la caméra (trois clics : vue de base)   Clic gauche / droit : armes"
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
	# 13/11 : le pirate se tient au bout d'un ponton, devant le coucher de soleil (il flottait au-dessus de la mer)
	for spec: Array in [["post_a", "2e2a44"], ["post_b", "2e2a44"], ["under", "3a2630"], ["deck", "6a4532"], ["edge", "9c6a43"]]:
		var part := ColorRect.new()
		part.color = Color(str(spec[1]))
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(part)
		_jetty[str(spec[0])] = part
	_preview = Sprite2D.new()
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage.add_child(_preview)
	var name_label := Label.new()
	name_label.text = "Ton pirate"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	UiTheme.apply_font(name_label, 22)
	name_label.add_theme_color_override("font_color", GOLD)
	box.add_child(name_label)
	_volume_panel = VolumePanel.new()   # (le bouton « Sons et musique » l'ouvre)
	_volume_panel.visible = false
	box.add_child(_volume_panel)
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
	if solid:
		UiTheme.style_button(b, int(b.get_theme_font_size("font_size")) if b.has_theme_font_size_override("font_size") else 18)
		return
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
	UiTheme.apply_font(b, int(b.get_theme_font_size("font_size")) if b.has_theme_font_size_override("font_size") else 16)


## Tous les bateaux du menu (identifiants) : ils sont tous proposés d'emblée, même au tout premier lancement.
static func ship_ids() -> Array:
	var out: Array = []
	for s: Array in SHIPS:
		out.append(s[0])
	return out


## Un message sous les boutons (connexion en cours, impossible de rejoindre…) : le menu cache le reste du jeu, c'est ici que le
## joueur doit voir ce qui se passe quand il clique sur « Rejoindre ».
func set_message(text: String) -> void:
	if _message == null:
		return
	_message.text = text
	_message.visible = text != ""


## Verrouille les bateaux qu'on ne possède pas encore (à acheter au chantier naval) et choisit `selected`.
func set_ships(owned: Array, selected: String) -> void:
	for s: Array in SHIPS:
		var b := _ship_buttons[s[0]] as Button
		var has: bool = owned.has(s[0])
		b.disabled = not has
		b.text = str(s[1]) if has else "%s (verrouillé)" % s[1]
		b.tooltip_text = str(s[2]) if has else "À acheter au chantier naval du port"
	_choose_ship(selected if owned.has(selected) else str(owned[0]))


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
