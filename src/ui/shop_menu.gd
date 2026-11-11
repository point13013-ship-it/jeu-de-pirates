class_name ShopMenu
extends Control
## Le menu d'une boutique : une liste d'articles (flèches haut/bas ou Z/S), E achète, R ou Échap ferme. Les règles
## sont dans Shop ; ce contrôle ne fait que dessiner et transmettre les touches.

signal purchased(result: Dictionary)   ## résultat de Shop.activate (le jeu applique la nouvelle tenue)
signal closed

const MAX_ROWS := 11

var shop: Shop
var _open := false
var _sel := 0
var _panel: ColorRect
var _title: Label
var _rows: VBoxContainer
var _desc: Label
var _foot: Label
var _note: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = ColorRect.new()
	_panel.color = Color(0.07, 0.04, 0.09, 0.94)
	_panel.size = Vector2(560, 470)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-280, -245)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var edge := ColorRect.new()
	edge.color = Color(0.85, 0.68, 0.3)
	edge.size = Vector2(560, 3)
	_panel.add_child(edge)
	_title = _label(Vector2(20, 12), 22, Color(1.0, 0.82, 0.4))
	_rows = VBoxContainer.new()
	_rows.position = Vector2(20, 54)
	_rows.size = Vector2(520, 300)
	_rows.add_theme_constant_override("separation", 2)
	_panel.add_child(_rows)
	_desc = _label(Vector2(20, 372), 15, Color(0.85, 0.9, 1.0))
	_desc.size = Vector2(520, 24)
	_foot = _label(Vector2(20, 400), 15, Color(1.0, 0.85, 0.35))
	_note = _label(Vector2(20, 430), 14, Color(0.7, 0.85, 1.0))
	_note.text = "Haut/Bas : choisir     E : acheter     + / − : taille     R : sortir"


func _label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_panel.add_child(l)
	return l



## La fenêtre grandit avec l'écran et avec + / − (voir DisplaySettings.window_factor), autour de son centre.
func _process(_delta: float) -> void:
	if not visible or _panel == null:
		return
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2.ONE * DisplaySettings.window_factor(get_viewport_rect().size, _panel.size)

func is_open() -> bool:
	return _open


func open(p_shop: Shop) -> void:
	shop = p_shop
	_sel = 0
	_open = true
	visible = true
	_title.text = shop.title
	_refresh()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


## Une touche pendant que le menu est ouvert (code physique).
func key(code: int) -> void:
	if not _open:
		return
	match code:
		KEY_UP, KEY_W:   # W physique = Z sur un clavier AZERTY
			_sel = posmod(_sel - 1, shop.items.size())
			_refresh()
		KEY_DOWN, KEY_S:
			_sel = posmod(_sel + 1, shop.items.size())
			_refresh()
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			var res := shop.activate(_sel)
			_refresh(str(res["msg"]))
			purchased.emit(res)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT:   # agrandir / réduire la fenêtre
			DisplaySettings.window_scale_key(code)
		KEY_R, KEY_ESCAPE:
			close()


func _refresh(message: String = "") -> void:
	for c in _rows.get_children():
		c.queue_free()
	# fenêtre de MAX_ROWS lignes qui suit la sélection (la voilerie en a 17)
	var first := clampi(_sel - MAX_ROWS / 2, 0, maxi(shop.items.size() - MAX_ROWS, 0))
	_title.text = shop.title if shop.items.size() <= MAX_ROWS else "%s   (%d / %d)" % [shop.title, _sel + 1, shop.items.size()]
	for i in range(first, mini(first + MAX_ROWS, shop.items.size())):
		var r := shop.row(i)
		var line := Label.new()
		line.custom_minimum_size = Vector2(520, 26)
		line.add_theme_font_size_override("font_size", 17)
		var txt := "%s%s" % ["> " if i == _sel else "   ", str(r["label"])]
		line.text = "%s  —  %s" % [txt, str(r["right"])]
		var col := Color(1, 0.95, 0.85) if bool(r["enabled"]) else Color(0.55, 0.5, 0.5)
		if i == _sel:
			col = Color(1.0, 0.85, 0.35) if bool(r["enabled"]) else Color(0.8, 0.6, 0.35)
		line.add_theme_color_override("font_color", col)
		_rows.add_child(line)
	_desc.text = message if message != "" else str(shop.row(_sel)["desc"])
	var stock := shop.stock_text()
	_foot.text = "Or : %d%s" % [shop.profile.gold, ("     " + stock) if stock != "" else ""]
