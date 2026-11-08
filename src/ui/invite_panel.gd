class_name InvitePanel
extends PanelContainer
## Le cadre « Inviter un ami » de l'hôte : son adresse IP (celle qu'un ami tape pour le rejoindre), le code d'invitation, son
## adresse sur son réseau, et ce qu'il faut savoir (port ouvert ou non). Il reste affiché pendant la partie ; la touche I le cache.

const WOOD := Color(0.14, 0.08, 0.04, 0.92)
const GOLD := Color("e0a93c")
const CREAM := Color("fff1d6")
const GREEN := Color("9be58b")
const ORANGE := Color("ffb866")

var _ip: Label
var _code: Label
var _local: Label
var _note: Label
var _info: Dictionary = {}
var _copied_t := 0.0


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = GOLD
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 74.0   # sous les lignes d'état du haut de l'écran
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	var title := Label.new()
	title.text = "INVITER UN AMI          (touche I : cacher)"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 15)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	_ip = _row(grid, "Adresse IP", "ip")
	_code = _row(grid, "Code", "code")
	_local = Label.new()
	_local.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_local.add_theme_font_size_override("font_size", 13)
	box.add_child(_local)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(440, 0)
	_note.add_theme_font_size_override("font_size", 13)
	box.add_child(_note)
	var how := Label.new()
	how.text = "Ton ami : « Rejoindre un ami », il tape l'adresse IP (ou le code) puis « Rejoindre »."
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(440, 0)
	how.add_theme_color_override("font_color", CREAM)
	how.add_theme_font_size_override("font_size", 13)
	box.add_child(how)
	_refresh()


func _row(grid: GridContainer, name_text: String, what: String) -> Label:
	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_color_override("font_color", CREAM)
	name_label.add_theme_font_size_override("font_size", 15)
	grid.add_child(name_label)
	var value := Label.new()
	value.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	value.add_theme_font_size_override("font_size", 24 if what == "ip" else 18)
	value.custom_minimum_size = Vector2(250, 0)
	grid.add_child(value)
	var b := Button.new()
	b.text = "Copier"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: _copy(what))
	grid.add_child(b)
	return value


func _copy(what: String) -> void:
	var text := str(_info.get(what, ""))
	if text == "":
		return
	DisplayServer.clipboard_set(text)
	_copied_t = 2.0
	_refresh()


## Met à jour l'affichage : `info` vient de SailingNet.invite_info().
func show_info(info: Dictionary) -> void:
	_info = info
	_refresh()


func _process(delta: float) -> void:
	if _copied_t > 0.0:
		_copied_t -= delta
		if _copied_t <= 0.0:
			_refresh()


func _refresh() -> void:
	if _ip == null:
		return
	var ip := str(_info.get("ip", ""))
	_ip.text = ip if ip != "" else "recherche…"
	var code := str(_info.get("code", ""))
	_code.text = code if code != "" else "…"
	var local := str(_info.get("local", ""))
	_local.text = "Ami chez toi ou sur un VPN : adresse %s" % local if local != "" else ""
	var note := str(_info.get("note", ""))
	if _copied_t > 0.0:
		note = "Copié !"
	_note.text = note
	_note.add_theme_color_override("font_color", GREEN if (bool(_info.get("port_open", false)) or _copied_t > 0.0) else ORANGE)
