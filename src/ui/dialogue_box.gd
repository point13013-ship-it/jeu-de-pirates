class_name DialogueBox
extends Control
## Boîte de dialogue en bas de l'écran : le nom du PNJ, une phrase à la fois. E : phrase suivante. Pour une quête
## proposée, après la dernière phrase : E accepte, R refuse. Le jeu appelle confirm() et refuse() depuis ses touches.

signal closed(accepted: bool)

var _lines: Array = []
var _index := 0
var _offer := false
var _open := false
var _name: Label
var _text: Label
var _hint: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := ColorRect.new()
	panel.color = Color(0.07, 0.04, 0.09, 0.9)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(780, 124)
	panel.size = Vector2(780, 124)
	panel.position = Vector2(-390, -150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.85, 0.68, 0.3)
	edge.size = Vector2(780, 3)
	panel.add_child(edge)
	_name = Label.new()
	_name.position = Vector2(18, 8)
	_name.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	_name.add_theme_font_size_override("font_size", 18)
	panel.add_child(_name)
	_text = Label.new()
	_text.position = Vector2(18, 36)
	_text.size = Vector2(744, 60)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_text.add_theme_font_size_override("font_size", 17)
	panel.add_child(_text)
	_hint = Label.new()
	_hint.position = Vector2(18, 98)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_hint.add_theme_font_size_override("font_size", 14)
	panel.add_child(_hint)


func is_open() -> bool:
	return _open


## Ouvre le dialogue : `lines` dites une à une ; `offer` : une quête est proposée à la fin.
func start(speaker: String, lines: Array, offer: bool = false) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_offer = offer
	_open = true
	_name.text = speaker
	visible = true
	_show()


func _show() -> void:
	_text.text = str(_lines[_index])
	var last := _index >= _lines.size() - 1
	if last and _offer:
		_hint.text = "E : accepter la quête     R : refuser"
	else:
		_hint.text = "E : fermer" if last else "E : suite"


## E : phrase suivante, ou fin (en acceptant s'il y avait une quête proposée).
func confirm() -> void:
	if not _open:
		return
	if _index < _lines.size() - 1:
		_index += 1
		_show()
		return
	_close(true)


## R : refuse la quête proposée (seulement après la dernière phrase).
func refuse() -> void:
	if _open and _offer and _index >= _lines.size() - 1:
		_close(false)


func _close(accepted: bool) -> void:
	_open = false
	visible = false
	closed.emit(accepted)
