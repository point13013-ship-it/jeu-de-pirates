class_name InventoryPanel
extends Control
## Le sac du pirate (Tab) et le coffre d'une cabane (12/11/2026, refait : « il faut des cases avec des images, pas du texte »).
##
## À gauche, les objets en cases (armes, baies, provisions, ce qu'on porte) : une icône, le nombre en bas à droite. À droite,
## la fabrication : une fiche par recette, ingrédients en vert s'ils y sont, en rouge sinon (à la Valheim). En bas, la fiche de
## l'objet choisi sur un parchemin. Souris : survol pour choisir, clic pour utiliser, clic droit pour l'action secondaire.
## Clavier : flèches (ou ZQSD) pour se déplacer, E pour utiliser, Q pour l'action secondaire, Tab / R / Échap pour fermer.
##
## Le jeu fournit les lignes avec open() / set_rows() (même format qu'avant : {head, label, right, kind, id, enabled, desc,
## count}) ; ce contrôle les range en cases et transmet le choix.

signal use_item(kind: String, id: String)
signal alt_item(kind: String, id: String)   ## Q / clic droit sur une arme : en faire l'arme secondaire
signal place_weapon(id: String, slot: int)  ## une arme glissée sur l'emplacement 1 (clic gauche) ou 2 (clic droit)
signal closed

const SLOT := 64
const COLS := 6
const GAP := 6

var _open := false
var _sel := 0
var _rows: Array = []
var _items: Array = []         ## indices (dans _rows) des lignes sélectionnables, dans l'ordre d'affichage
var _slot_nodes: Dictionary = {}   ## indice de ligne -> Control (case ou fiche)
var _panel: PanelContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _title: Label
var _foot: Label
var _info_name: Label
var _info_sub: Label
var _info_desc: Label
var _purse: HBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.panel())
	_panel.custom_minimum_size = Vector2(900, 560)
	add_child(_panel)   # (centré à chaque image dans _process)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	# en-tête : le titre à gauche, la bourse à droite (or et provisions : 12/11, « on ne les voit que sac ouvert »)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	_title = UiTheme.label("Sac du pirate", 28, UiTheme.BRASS, 5)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_purse = HBoxContainer.new()
	_purse.add_theme_constant_override("separation", 12)
	_purse.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(_purse)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 8)
	_left.custom_minimum_size = Vector2(COLS * (SLOT + GAP), 0)
	cols.add_child(_left)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_right)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UiTheme.parchment())
	info.custom_minimum_size = Vector2(0, 92)
	v.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 2)
	info.add_child(iv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	iv.add_child(head)
	_info_name = UiTheme.label("", 20, UiTheme.INK, 0)
	head.add_child(_info_name)
	_info_sub = UiTheme.label("", 15, Color("6b4a2a"), 0)
	head.add_child(_info_sub)
	_info_desc = UiTheme.label("", 15, UiTheme.INK, 0)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.custom_minimum_size = Vector2(840, 0)
	iv.add_child(_info_desc)
	_foot = UiTheme.label("", 14, UiTheme.MUTED, 2)
	v.add_child(_foot)
	set_texts()


## Change le titre et la ligne d'aide (le panneau sert aussi de coffre de cabane) ; sans argument : ceux du sac.
func set_texts(title: String = "Sac du pirate", foot: String = "Glisse une arme sur l'emplacement 1 (clic gauche) ou 2 (clic droit)     Clic / E : utiliser     Q : en 2     X : échanger 1 et 2     Tab : fermer") -> void:
	_title.text = title
	_foot.text = foot


## La fenêtre grandit avec l'écran et avec + / − (voir DisplaySettings.window_factor), autour de son centre.
func _process(_delta: float) -> void:
	if not visible or _panel == null:
		return
	_fit()


## Centre la fenêtre et lui donne sa taille d'écran. (12/11 : la taille n'était posée qu'après le fondu d'ouverture ; le sac
## s'ouvrait en tout petit puis sautait à sa vraie taille. Elle est maintenant posée dès l'ouverture, et le fondu n'anime plus
## que la transparence.)
func _fit() -> void:
	_panel.reset_size()
	_panel.position = (size - _panel.size) / 2.0
	_panel.pivot_offset = _panel.size / 2.0
	var f := DisplaySettings.window_factor(get_viewport_rect().size, _panel.size)
	if not is_equal_approx(_panel.scale.x, f):
		_panel.scale = Vector2.ONE * f


func is_open() -> bool:
	return _open


func open(rows: Array) -> void:
	_open = true
	visible = true
	_sel = 0
	set_rows(rows)
	_panel.modulate.a = 0.0
	_fit()
	var tw := _panel.create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, UiTheme.ANIM)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


## Remplace les lignes (après un usage) en gardant la sélection au même rang quand c'est possible.
func set_rows(rows: Array) -> void:
	_rows = rows
	_items.clear()
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		if not bool(r.get("head", false)) and not (str(r.get("kind", "none")) in ["none", "purse", "weapon_empty"]):
			_items.append(i)
	_sel = clampi(_sel, 0, maxi(_items.size() - 1, 0))
	_rebuild()


func key(code: int) -> void:
	if not _open:
		return
	match code:
		KEY_LEFT, KEY_A:   # (touches physiques : A = Q en AZERTY, W = Z)
			_move(-1)
		KEY_RIGHT, KEY_D:
			_move(1)
		KEY_UP, KEY_W:
			_move(-COLS if not _is_card(_cur_row()) else -1)
		KEY_DOWN, KEY_S:
			_move(COLS if not _is_card(_cur_row()) else 1)
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			_use(false)
		KEY_Q:
			_use(true)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT:   # agrandir / réduire la fenêtre
			DisplaySettings.window_scale_key(code)
		KEY_R, KEY_TAB, KEY_ESCAPE:
			close()


func _cur_row() -> Dictionary:
	if _items.is_empty():
		return {}
	return _rows[int(_items[_sel])]


func _is_card(r: Dictionary) -> bool:
	return str(r.get("kind", "")) == "craft"


func _use(alt: bool) -> void:
	var r := _cur_row()
	if r.is_empty():
		return
	if alt:
		if str(r.get("kind", "")) == "weapon":
			alt_item.emit(str(r["kind"]), str(r["id"]))
	elif bool(r.get("enabled", false)):
		_flash(int(_items[_sel]))
		use_item.emit(str(r["kind"]), str(r["id"]))


func _move(step: int) -> void:
	if _items.is_empty():
		return
	_sel = clampi(_sel + step, 0, _items.size() - 1)
	_refresh_selection()


# ------------------------------------------------------------------ construction

func _rebuild() -> void:
	for c in _left.get_children():
		c.queue_free()
	for c in _right.get_children():
		c.queue_free()
	_slot_nodes.clear()
	for c in _purse.get_children():
		c.queue_free()
	var grid: GridContainer = null
	var target := _left
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		if str(r.get("kind", "")) == "purse":   # la bourse, dans l'en-tête : une icône et un nombre
			_purse.add_child(_purse_entry(r))
			continue
		if bool(r.get("head", false)):
			var is_craft := str(r["label"]).begins_with("Fabrication")
			target = _right if is_craft else _left
			target.add_child(UiTheme.section(str(r["label"])))
			grid = null
			continue
		var kind := str(r.get("kind", "none"))
		if kind == "none":   # une simple ligne de texte (« aucune baie », « pouvoir actuel… »)
			target.add_child(UiTheme.label(str(r["label"]), 15, UiTheme.MUTED, 2))
			continue
		if kind == "craft":
			var card := _recipe_card(i, r)
			_right.add_child(card)
			_slot_nodes[i] = card
			continue
		if kind == "contract":   # 13/11 : le tableau des quêtes, en cartes sur deux colonnes
			if grid == null or grid.columns != 2:
				grid = GridContainer.new()
				grid.columns = 2
				grid.add_theme_constant_override("h_separation", 10)
				grid.add_theme_constant_override("v_separation", 10)
				target.add_child(grid)
			var mc := _contract_card(i, r)
			grid.add_child(mc)
			_slot_nodes[i] = mc
			continue
		if grid == null:
			grid = GridContainer.new()
			grid.columns = COLS
			grid.add_theme_constant_override("h_separation", GAP)
			grid.add_theme_constant_override("v_separation", GAP)
			target.add_child(grid)
		if kind == "weapon_empty":   # emplacement d'arme libre : on peut y déposer une arme
			grid.add_child(_empty_weapon_slot(r))
			continue
		var s := _slot(i, r)
		grid.add_child(s)
		_slot_nodes[i] = s
	if _right.get_child_count() == 0:
		_right.visible = false
	else:
		_right.visible = true
	_refresh_selection()


## Une case : icône, nombre en bas à droite, grisée si l'objet ne sert à rien maintenant, marque laiton sur l'arme en main.
func _slot(i: int, r: Dictionary) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(SLOT, SLOT)
	p.add_theme_stylebox_override("panel", UiTheme.slot(false))
	var ic := TextureRect.new()
	ic.texture = _icon_of(r)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(8, 8)
	ic.size = Vector2(SLOT - 16, SLOT - 16)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bool(r.get("enabled", false)) and str(r.get("kind", "")) not in ["weapon", "item", "treasure", "hidden"]:
		ic.modulate = Color(1, 1, 1, 0.45)
	p.add_child(ic)
	var n := _count_of(r)
	if n >= 0:
		var cl := UiTheme.label(str(n), 15, Color.WHITE, 4)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cl.position = Vector2(4, SLOT - 24)
		cl.size = Vector2(SLOT - 9, 20)
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(cl)
	if str(r.get("kind", "")) == "weapon":
		var slot_n := int(r.get("slot", 0))
		if slot_n > 0:
			_slot_tag(p, slot_n)
		_wire_weapon_drag(p, str(r["id"]), slot_n)
	_wire_mouse(p, i)
	return p


## Le numéro de l'emplacement (1 : clic gauche, 2 : clic droit), en laiton dans le coin.
func _slot_tag(p: Control, slot_n: int) -> void:
	var tag := UiTheme.label(str(slot_n), 13, UiTheme.BRASS, 3)
	tag.position = Vector2(5, 2)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tag)


## Glisser-déposer des armes (12/11) : on prend la vignette d'une arme et on la lâche sur l'emplacement 1 ou 2 ; les deux
## armes échangent leur place (et donc leur bouton de souris).
func _wire_weapon_drag(p: Control, id: String, slot_n: int) -> void:
	p.set_drag_forwarding(
		func(_at: Vector2) -> Variant:
			var preview := TextureRect.new()
			preview.texture = ItemIcons.icon("weapon", id)
			preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.size = Vector2(SLOT, SLOT) * _panel.scale.x
			preview.modulate.a = 0.85
			set_drag_preview(preview)
			return {"weapon": id, "from": slot_n},
		func(_at: Vector2, data: Variant) -> bool:
			return slot_n > 0 and data is Dictionary and (data as Dictionary).has("weapon") and str(data["weapon"]) != id,
		func(_at: Vector2, data: Variant) -> void:
			place_weapon.emit(str(data["weapon"]), slot_n))


func _empty_weapon_slot(r: Dictionary) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(SLOT, SLOT)
	p.add_theme_stylebox_override("panel", UiTheme.slot(false, true))
	var slot_n := int(r.get("slot", 2))
	_slot_tag(p, slot_n)
	p.tooltip_text = str(r.get("label", ""))
	p.set_drag_forwarding(Callable(),
		func(_at: Vector2, data: Variant) -> bool:
			return data is Dictionary and (data as Dictionary).has("weapon"),
		func(_at: Vector2, data: Variant) -> void:
			place_weapon.emit(str(data["weapon"]), slot_n))
	return p


## Une entrée de la bourse : petite icône et nombre (l'or en laiton).
func _purse_entry(r: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.tooltip_text = str(r.get("label", ""))
	var ic := TextureRect.new()
	ic.texture = ItemIcons.icon("item", str(r["id"]))
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.custom_minimum_size = Vector2(28, 28)
	h.add_child(ic)
	var gold := str(r["id"]) == "gold"
	var l := UiTheme.label(str(int(r.get("count", 0))), 20 if gold else 17, UiTheme.BRASS if gold else UiTheme.CREAM, 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h


## Une fiche de recette : icône, nom, ingrédients (vert : on les a ; rouge : il en manque).
## Une mission du tableau : icône du type de mission dans un cadre à la couleur de sa rareté, intitulé, rareté, jauge
## d'avancement, récompense. Remplie, la carte s'éclaire : un clic touche l'or.
func _contract_card(i: int, r: Dictionary) -> Control:
	var tier_col := Color(str(r.get("tier_color", "b9ad9c")))
	var done := bool(r.get("enabled", false))
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(400, 96)
	var sb := UiTheme.slot(false).duplicate() as StyleBoxFlat
	sb.border_color = tier_col
	sb.set_border_width_all(2)
	sb.border_width_left = 7
	sb.bg_color = sb.bg_color.lerp(tier_col, 0.16 if done else 0.05)
	sb.content_margin_left = 14
	sb.content_margin_right = 12
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var frame := PanelContainer.new()
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(0, 0, 0, 0.28)
	fb.border_color = tier_col
	fb.set_border_width_all(2)
	fb.set_corner_radius_all(6)
	fb.set_content_margin_all(5)
	frame.add_theme_stylebox_override("panel", fb)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(frame)
	var ic := TextureRect.new()
	ic.texture = ItemIcons.icon("item", str(r.get("icon", "")))
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(56, 56)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	h.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var tl := UiTheme.label(str(r.get("tier_name", "")).to_upper(), 12, tier_col, 2)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	top.add_child(UiTheme.label("%d or" % int(r.get("reward", 0)), 15, UiTheme.BRASS, 2))
	var title := UiTheme.label(str(r["label"]), 16, UiTheme.CREAM, 3)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(280, 0)
	v.add_child(title)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = maxf(float(r.get("need", 1)), 1.0)
	bar.value = float(r.get("have", 0))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 9)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.4)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = UiTheme.GREEN if done else tier_col
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	v.add_child(bar)
	v.add_child(UiTheme.label("Rempli : clique pour toucher l'or" if done else "%d / %d" % [int(r.get("have", 0)), int(r.get("need", 1))], 13,
			UiTheme.GREEN if done else UiTheme.MUTED, 2))
	for c in [h, frame, ic, v, top, title, bar]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c2 in v.get_children() + top.get_children():
		(c2 as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wire_mouse(p, i)
	return p


func _recipe_card(i: int, r: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.slot(false))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ic := TextureRect.new()
	ic.texture = ItemIcons.icon("craft", str(r["id"]))
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(48, 48)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var ok := bool(r.get("enabled", false))
	v.add_child(UiTheme.label(str(r["label"]), 18, UiTheme.CREAM, 3))
	var need := UiTheme.label(str(r.get("right", "")), 14, UiTheme.GREEN if ok else UiTheme.RED, 2)
	v.add_child(need)
	for c in v.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wire_mouse(p, i)
	return p


func _wire_mouse(c: Control, row_index: int) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_entered.connect(func() -> void:
		var k := _items.find(row_index)
		if k >= 0 and k != _sel:
			_sel = k
			_refresh_selection())
	c.gui_input.connect(func(ev: InputEvent) -> void:
		# au relâchement (et pas pendant un glisser-déposer) : appuyer puis glisser une arme ne doit pas l'utiliser
		if ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed \
				and (ev as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and not c.get_viewport().gui_is_dragging():
			var k := _items.find(row_index)
			if k >= 0:
				_sel = k
				_use((ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT))


func _icon_of(r: Dictionary) -> Texture2D:
	var kind := str(r.get("kind", ""))
	var id := str(r.get("id", ""))
	if kind in ["cab_put", "cab_take"]:   # coffre de cabane : « t:… » trésor, « b:… » baie, sinon une réserve
		if id.begins_with("t:"):
			return ItemIcons.icon("treasure", id)
		if id.begins_with("b:"):
			return ItemIcons.icon("berry", id.substr(2))
		return ItemIcons.icon("item", id)
	return ItemIcons.icon(kind, id)


## Le nombre à afficher dans la case (-1 : aucun) : « count », ou « xN » à la fin du libellé.
func _count_of(r: Dictionary) -> int:
	if r.has("count"):
		return int(r["count"])
	var m := RegEx.create_from_string("x(\\d+)").search(str(r.get("label", "")))
	return int(m.get_string(1)) if m != null else -1


func _refresh_selection() -> void:
	for idx: int in _slot_nodes:
		var node := _slot_nodes[idx] as Control
		var selected := not _items.is_empty() and int(_items[_sel]) == idx
		var r: Dictionary = _rows[idx]
		node.add_theme_stylebox_override("panel", UiTheme.slot(selected))
		node.pivot_offset = node.size / 2.0
		var tw := node.create_tween()
		tw.tween_property(node, "scale", Vector2.ONE * (1.06 if selected and not _is_card(r) else 1.0), UiTheme.ANIM)
	var cur := _cur_row()
	_info_name.text = str(cur.get("label", "")).strip_edges()
	_info_sub.text = str(cur.get("right", ""))
	_info_desc.text = str(cur.get("desc", ""))


## Petit éclat sur la case qu'on vient d'utiliser.
func _flash(row_index: int) -> void:
	var node := _slot_nodes.get(row_index) as Control
	if node == null:
		return
	node.modulate = Color(1.6, 1.4, 1.0)
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color.WHITE, 0.25)
