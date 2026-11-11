class_name InventoryPanel
extends Control
## Le sac du pirate (touche Tab) : armes (E pour prendre en main), baies des dieux gardées (E pour la manger), munitions,
## provisions et trésor porté. Le jeu fournit les lignes avec set_rows() ; ce contrôle ne fait que les dessiner et
## transmettre le choix. Haut/Bas (ou Z/S) : choisir, E : utiliser, Tab, R ou Échap : fermer.

signal use_item(kind: String, id: String)
signal alt_item(kind: String, id: String)   ## Q sur une arme : en faire l'arme secondaire
signal closed

const MAX_ROWS := 14

var _open := false
var _sel := 0
var _rows: Array = []          ## {head: bool, label, right, kind, id, enabled, desc}
var _panel: ColorRect
var _list: VBoxContainer
var _desc: Label
var _foot: Label
var _title: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = ColorRect.new()
	_panel.color = Color(0.07, 0.04, 0.09, 0.95)
	_panel.size = Vector2(620, 540)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-310, -275)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var edge := ColorRect.new()
	edge.color = Color(0.85, 0.68, 0.3)
	edge.size = Vector2(620, 3)
	_panel.add_child(edge)
	_title = _label(Vector2(20, 10), 24, Color(1.0, 0.82, 0.4))
	_title.text = "Sac du pirate"
	_list = VBoxContainer.new()
	_list.position = Vector2(20, 52)
	_list.size = Vector2(580, 380)
	_list.add_theme_constant_override("separation", 1)
	_panel.add_child(_list)
	_desc = _label(Vector2(20, 440), 15, Color(0.85, 0.9, 1.0))
	_desc.size = Vector2(580, 40)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot = _label(Vector2(20, 490), 14, Color(0.7, 0.85, 1.0))
	_foot.text = "Haut/Bas : choisir     E : utiliser     Q : arme secondaire     Tab / R : fermer"


func _label(pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_panel.add_child(l)
	return l


## Change le titre et la ligne d'aide (le panneau sert aussi de coffre de cabane) ; sans argument : ceux du sac.
func set_texts(title: String = "Sac du pirate", foot: String = "Haut/Bas : choisir     E : utiliser     Q : arme secondaire     Tab / R : fermer") -> void:
	_title.text = title
	_foot.text = foot


func is_open() -> bool:
	return _open


func open(rows: Array) -> void:
	_open = true
	visible = true
	_sel = 0
	set_rows(rows)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


## Remplace les lignes (après un usage) en gardant la sélection au même rang quand c'est possible.
func set_rows(rows: Array) -> void:
	_rows = rows
	_sel = clampi(_sel, 0, maxi(_rows.size() - 1, 0))
	if not _rows.is_empty() and bool((_rows[_sel] as Dictionary).get("head", false)):
		_sel = _first_selectable(_sel, 1)
	_refresh()


func _first_selectable(from: int, step: int) -> int:
	var i := from
	while i >= 0 and i < _rows.size():
		if not bool((_rows[i] as Dictionary).get("head", false)):
			return i
		i += step
	return clampi(from, 0, maxi(_rows.size() - 1, 0))


func key(code: int) -> void:
	if not _open:
		return
	match code:
		KEY_UP, KEY_W:
			_move(-1)
		KEY_DOWN, KEY_S:
			_move(1)
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			if not _rows.is_empty():
				var r: Dictionary = _rows[_sel]
				if bool(r.get("enabled", false)):
					use_item.emit(str(r["kind"]), str(r["id"]))
		KEY_Q:   # une arme : la mettre en arme secondaire (clic droit)
			if not _rows.is_empty():
				var r2: Dictionary = _rows[_sel]
				if str(r2.get("kind", "")) == "weapon":
					alt_item.emit(str(r2["kind"]), str(r2["id"]))
		KEY_R, KEY_TAB, KEY_ESCAPE:
			close()


func _move(step: int) -> void:
	if _rows.is_empty():
		return
	var i := _sel
	for n in _rows.size():
		i = posmod(i + step, _rows.size())
		if not bool((_rows[i] as Dictionary).get("head", false)):
			_sel = i
			break
	_refresh()


func _refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var first := clampi(_sel - MAX_ROWS / 2, 0, maxi(_rows.size() - MAX_ROWS, 0))
	for i in range(first, mini(first + MAX_ROWS, _rows.size())):
		var r: Dictionary = _rows[i]
		var line := Label.new()
		line.custom_minimum_size = Vector2(580, 24)
		if bool(r.get("head", false)):
			line.text = "— %s —" % str(r["label"])
			line.add_theme_font_size_override("font_size", 15)
			line.add_theme_color_override("font_color", Color(0.9, 0.7, 0.35))
		else:
			var txt := "%s%s" % ["> " if i == _sel else "   ", str(r["label"])]
			var right := str(r.get("right", ""))
			line.text = txt if right == "" else "%s  —  %s" % [txt, right]
			line.add_theme_font_size_override("font_size", 17)
			var enabled := bool(r.get("enabled", false))
			var col := Color(1, 0.95, 0.85) if enabled else Color(0.62, 0.58, 0.58)
			if i == _sel:
				col = Color(1.0, 0.85, 0.35) if enabled else Color(0.85, 0.68, 0.4)
			line.add_theme_color_override("font_color", col)
		_list.add_child(line)
	_desc.text = str((_rows[_sel] as Dictionary).get("desc", "")) if not _rows.is_empty() else ""
