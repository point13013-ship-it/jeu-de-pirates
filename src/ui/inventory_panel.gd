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
	_title = UiTheme.label("Sac du pirate", 28, UiTheme.BRASS, 5)
	v.add_child(_title)
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
func set_texts(title: String = "Sac du pirate", foot: String = "Survol / flèches : choisir     Clic / E : utiliser     Clic droit / Q : arme secondaire     + / − : taille     Tab / R : fermer") -> void:
	_title.text = title
	_foot.text = foot


## La fenêtre grandit avec l'écran et avec + / − (voir DisplaySettings.window_factor), autour de son centre.
func _process(_delta: float) -> void:
	if not visible or _panel == null:
		return
	_panel.position = (size - _panel.size) / 2.0
	_panel.pivot_offset = _panel.size / 2.0
	var f := DisplaySettings.window_factor(get_viewport_rect().size, _panel.size)
	if not is_equal_approx(_panel.scale.x, f) and _panel.modulate.a >= 1.0:
		_panel.scale = Vector2.ONE * f


func is_open() -> bool:
	return _open


func open(rows: Array) -> void:
	_open = true
	visible = true
	_sel = 0
	set_rows(rows)
	UiTheme.appear(_panel)


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
		if not bool(r.get("head", false)) and str(r.get("kind", "none")) != "none":
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
	var grid: GridContainer = null
	var target := _left
	for i in _rows.size():
		var r: Dictionary = _rows[i]
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
		if grid == null:
			grid = GridContainer.new()
			grid.columns = COLS
			grid.add_theme_constant_override("h_separation", GAP)
			grid.add_theme_constant_override("v_separation", GAP)
			target.add_child(grid)
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
	if not bool(r.get("enabled", false)) and str(r.get("kind", "")) not in ["weapon", "item", "treasure"]:
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
	var right := str(r.get("right", ""))
	if str(r.get("kind", "")) == "weapon" and (right.begins_with("principale") or right.begins_with("secondaire")):
		var tag := UiTheme.label("1" if right.begins_with("principale") else "2", 13, UiTheme.BRASS, 3)
		tag.position = Vector2(5, 2)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(tag)
	_wire_mouse(p, i)
	return p


## Une fiche de recette : icône, nom, ingrédients (vert : on les a ; rouge : il en manque).
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
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
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
