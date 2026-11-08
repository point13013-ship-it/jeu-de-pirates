class_name CharacterEditor
extends Control
## Éditeur de pirate : à gauche l'aperçu animé (qui tourne sur lui-même), à droite une ligne par pièce
## (◀ variante ▶) et une ligne par couleur (pastilles de la palette + sélecteur libre).

signal closed(look: Dictionary)

const PREVIEW_SCALE := 7
const UI_ORDER := ["hair", "beard", "mustache", "eyes", "brows", "nose", "mouth", "mark", "hat", "shirt", "coat",
		"belt", "pants", "boots"]
const CHANNEL_ORDER := ["skin", "hair", "eyes", "scar", "hat", "hat_trim", "shirt", "shirt_stripe", "coat",
		"coat_trim", "belt", "pants", "boots"]

var look: Dictionary
var _preview: Sprite2D
var _stage: Control
## Les pièces du visage : en les changeant, l'aperçu se met de face et zoome sur la tête (à 48x64 pixels, le détail est petit).
const FACE_PARTS := ["hair", "beard", "mustache", "eyes", "brows", "nose", "mouth", "mark", "hat"]
const HEAD_FROM_FEET := 46.0     ## px : hauteur du centre de la tête au-dessus des pieds, dans une image du pirate

var _zoom_head := false
var _zoom_button: Button
var _anim := "walk"
var _spin := true
var _dir := 0
var _time := 0.0
var _textures: Dictionary = {}
var _value_labels: Dictionary = {}
var _color_pickers: Dictionary = {}
var _refresh_token := 0


func _init(start_look: Dictionary = {}) -> void:
	look = PirateLook.sanitize(start_look if not start_look.is_empty() else PirateLook.load_saved())


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1d3b4a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 24)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	margin.add_child(root)
	root.add_child(_build_preview_side())
	root.add_child(_build_options_side())
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	if _spin:
		_dir = int(_time / 1.1) % 8
	var tex: Texture2D = _textures.get(_anim)
	if tex == null:
		return
	var px := clampi(int((_stage.size.y - 20.0) / 66.0), 3, 9)
	if _zoom_head:
		# gros plan : la tête au centre, deux fois plus grosse
		var feet: Array = PirateLook.catalog().get("feet", [24, 58])
		var frame: Array = PirateLook.catalog().get("frame", [48, 64])
		var head_row := float(feet[1]) - HEAD_FROM_FEET
		var zoom := px * 2.0
		_preview.scale = Vector2(zoom, zoom)
		_preview.position = Vector2(_stage.size.x * 0.5, _stage.size.y * 0.5 + (float(frame[1]) * 0.5 - head_row) * zoom)
	else:
		_preview.scale = Vector2(px, px)
		# les pieds posent sur le bas du cadre (la position des pieds vient du catalogue)
		var feet_dy: float = float(PirateLook.catalog().get("feet", [32, 68])[1]) - float(PirateLook.catalog().get("frame", [64, 72])[1]) * 0.5
		_preview.position = Vector2(_stage.size.x * 0.5, _stage.size.y - 12.0 - feet_dy * px)
	var frames: int = int(PirateLook.catalog()["anims"][_anim])
	_preview.texture = tex
	_preview.hframes = frames
	_preview.vframes = 8
	_preview.frame = _dir * frames + int(_time * float(PirateSprite.FPS[_anim])) % frames


func _build_preview_side() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "Mon pirate"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(400, 300)
	_stage = stage
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(stage)
	var ground := ColorRect.new()
	ground.color = Color("2b6a8a")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(ground)
	_preview = Sprite2D.new()
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	stage.add_child(_preview)
	var row := HBoxContainer.new()
	box.add_child(row)
	for entry in [["◀ Tourner", -1], ["Tourner ▶", 1]]:
		var b := Button.new()
		b.text = entry[0]
		b.pressed.connect(func() -> void:
			_spin = false
			_dir = posmod(_dir + int(entry[1]), 8))
		row.add_child(b)
	var spin := Button.new()
	spin.text = "Tourne tout seul"
	spin.pressed.connect(func() -> void: _spin = true)
	row.add_child(spin)
	var zoom_button := Button.new()
	zoom_button.text = "Gros plan"
	zoom_button.toggle_mode = true
	zoom_button.toggled.connect(func(on: bool) -> void: _zoom_head = on)
	row.add_child(zoom_button)
	_zoom_button = zoom_button
	var anims := HBoxContainer.new()
	box.add_child(anims)
	for entry in [["Repos", "idle"], ["Marche", "walk"], ["Porte un boulet", "carry_walk"], ["À la barre", "helm"]]:
		var b := Button.new()
		b.text = entry[0]
		b.pressed.connect(func() -> void: _anim = entry[1])
		anims.add_child(b)
	return box


func _build_options_side() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	var cat := PirateLook.catalog()
	_section(box, "Apparence")
	for c: String in UI_ORDER:
		if not cat["parts"].has(c):
			continue
		var row := HBoxContainer.new()
		box.add_child(row)
		var name_label := Label.new()
		name_label.text = str(cat["parts"][c]["label"])
		name_label.custom_minimum_size = Vector2(130, 0)
		row.add_child(name_label)
		var prev := Button.new()
		prev.text = "◀"
		prev.pressed.connect(_step.bind(c, -1))
		row.add_child(prev)
		var value := Label.new()
		value.custom_minimum_size = Vector2(190, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(value)
		_value_labels[c] = value
		var nxt := Button.new()
		nxt.text = "▶"
		nxt.pressed.connect(_step.bind(c, 1))
		row.add_child(nxt)
	_section(box, "Couleurs")
	var channels: Dictionary = cat["channels"]
	for ch: String in CHANNEL_ORDER:
		if not channels.has(ch):
			continue
		var row := HFlowContainer.new()
		box.add_child(row)
		var name_label := Label.new()
		name_label.text = str(channels[ch]["label"])
		name_label.custom_minimum_size = Vector2(130, 0)
		row.add_child(name_label)
		for hex: String in channels[ch]["palette"]:
			var swatch := Button.new()
			swatch.custom_minimum_size = Vector2(26, 26)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color.html(hex)
			sb.set_border_width_all(2)
			sb.border_color = Color(0, 0, 0, 0.55)
			for state in ["normal", "hover", "pressed", "focus"]:
				swatch.add_theme_stylebox_override(state, sb)
			swatch.pressed.connect(_set_color.bind(ch, hex))
			row.add_child(swatch)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(60, 26)
		picker.edit_alpha = false
		picker.tooltip_text = "Couleur libre"
		picker.color_changed.connect(func(c: Color) -> void: _set_color(ch, "#" + c.to_html(false)))
		row.add_child(picker)
		_color_pickers[ch] = picker
	box.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var rnd := Button.new()
	rnd.text = "Au hasard"
	rnd.pressed.connect(func() -> void:
		look = PirateLook.random_look(randi())
		_refresh())
	actions.add_child(rnd)
	var reset := Button.new()
	reset.text = "Remettre par défaut"
	reset.pressed.connect(func() -> void:
		look = PirateLook.default_look()
		_refresh())
	actions.add_child(reset)
	var done := Button.new()
	done.text = "Valider"
	done.pressed.connect(func() -> void:
		PirateLook.save(look)
		closed.emit(look))
	actions.add_child(done)
	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.pressed.connect(func() -> void: closed.emit({}))
	actions.add_child(cancel)
	return scroll


func _section(box: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	box.add_child(l)


func _step(category: String, delta: int) -> void:
	var options := PirateLook.variants(category)
	var i := options.find(look["parts"][category])
	look["parts"][category] = options[posmod(i + delta, options.size())]
	# un changement du visage : l'aperçu se met de face, immobile, en gros plan ; un vêtement : retour au corps entier
	var face := category in FACE_PARTS
	_zoom_head = face
	if face:
		_spin = false
		_dir = 0
		_anim = "idle"
	if _zoom_button != null:
		_zoom_button.set_pressed_no_signal(face)
	_refresh()


func _set_color(channel: String, hex: String) -> void:
	look["colors"][channel] = hex
	_refresh()


## Met à jour les libellés et lance la composition des feuilles de ce look.
func _refresh() -> void:
	for c: String in _value_labels:
		(_value_labels[c] as Label).text = PirateLook.variant_label(c, str(look["parts"][c]))
	for ch: String in _color_pickers:
		var picker: ColorPickerButton = _color_pickers[ch]
		picker.color = Color.html(look["colors"][ch])
	_refresh_token += 1
	var token := _refresh_token
	for a in ["idle", "walk", "carry_walk", "helm"]:
		var tex: Texture2D = await PirateSprite.texture_for(look, a)
		if token != _refresh_token:
			return
		if tex != null:
			_textures[a] = tex
