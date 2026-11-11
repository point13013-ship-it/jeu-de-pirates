class_name QuestPanel
extends Control
## Le journal de quêtes (touche J) : les quêtes en cours avec ce qu'il faut faire, celles à rendre, puis les terminées.
## Tout vient de data/quests.json (QuestLog) et de l'état du profil. Se pose sur la partie, qui continue derrière.

signal closed

const WOOD := Color("3a2415")
const GOLD := Color("e0a93c")
const CREAM := Color("fff1d6")
const MUTED := Color(0.78, 0.72, 0.6)
const GREEN := Color(0.55, 0.85, 0.5)
const BLUE := Color(0.55, 0.78, 1.0)

var _open := false
var _list: VBoxContainer
var _footer: Label
var _win: PanelContainer   ## la fenêtre elle-même (agrandie avec l'écran et + / −)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.03, 0.97)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = GOLD
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	_win = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Journal de quêtes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_color_override("font_color", MUTED)
	_footer.add_theme_font_size_override("font_size", 15)
	box.add_child(_footer)
	var close := Button.new()
	close.text = "Fermer   (J ou Échap)     + / − : taille"
	close.custom_minimum_size = Vector2(0, 40)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(self.close)
	box.add_child(close)


func _process(_delta: float) -> void:
	if not visible or _win == null:
		return
	_win.pivot_offset = _win.size / 2.0
	_win.scale = Vector2.ONE * DisplaySettings.window_factor(get_viewport_rect().size, _win.size)


func is_open() -> bool:
	return _open


## Ouvre le journal. `quests` : le journal de quêtes ; `names` : id de PNJ -> nom ; `island_name` : id d'île -> nom connu ou « Terre inconnue ».
func open(quests: QuestLog, island_name: Callable) -> void:
	_open = true
	visible = true
	for ch in _list.get_children():
		ch.queue_free()
	var active: Array = []
	var done: Array = []
	for id: String in quests.defs:
		match quests.state_of(id):
			"active", "ready":
				active.append(id)
			"done":
				done.append(id)
	if active.is_empty() and done.is_empty():
		_list.add_child(_text("Aucune quête pour l'instant. Parle aux habitants du port : un tavernier, une quartier-maître et un receleur cherchent un matelot.", MUTED, 17))
	for id: String in active:
		_list.add_child(_entry(quests, id, island_name))
	if not done.is_empty():
		_list.add_child(_text("— Terminées —", MUTED, 16))
		for id: String in done:
			_list.add_child(_entry(quests, id, island_name))
	var earned := 0
	for id: String in done:
		earned += int(quests.defs[id]["reward"])
	_footer.text = "En cours : %d     Terminées : %d / %d     Or gagné : %d" % [active.size(), done.size(), quests.defs.size(), earned]


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func _text(t: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(660, 0)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l


## Une quête : titre et état, ce qu'il faut faire, ce qu'on y gagne, et le mot de celui qui l'a confiée.
func _entry(quests: QuestLog, id: String, island_name: Callable) -> Control:
	var q: Dictionary = quests.defs[id]
	var state := quests.state_of(id)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.1, 0.05, 0.9) if state != "done" else Color(0.12, 0.09, 0.07, 0.8)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = {"active": GOLD, "ready": GREEN, "done": Color(0.4, 0.34, 0.26)}[state]
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = str(q["title"])
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", CREAM if state != "done" else MUTED)
	head.add_child(title)
	var chip := Label.new()
	chip.text = {"active": "En cours", "ready": "À rendre", "done": "Terminée ✓"}[state]
	chip.add_theme_font_size_override("font_size", 15)
	chip.add_theme_color_override("font_color", {"active": GOLD, "ready": GREEN, "done": MUTED}[state])
	head.add_child(chip)
	var giver := str(quests.names.get(q["giver"], q["giver"]))
	var target := str(quests.names.get(q["target"], q["target"]))
	if quests.is_expedition(id):
		var island := str(island_name.call(str(q["island"])))
		if state == "ready":
			box.add_child(_text("Objectif : tu as posé le pied sur %s. Retourne le dire à %s." % [island, giver], BLUE, 16))
		elif state == "active":
			box.add_child(_text("Objectif : fais route vers %s (le cap est fixé sur ta carte des mers) et pose le pied sur l'île." % island, BLUE, 16))
		else:
			box.add_child(_text("Tu as exploré %s pour %s." % [island, giver], MUTED, 15))
	else:
		if state == "done":
			box.add_child(_text("Tu as livré %s à %s pour %s." % [q["item"], target, giver], MUTED, 15))
		else:
			box.add_child(_text("Objectif : porter %s à %s. Confiée par %s." % [q["item"], target, giver], BLUE, 16))
	var offer: Array = q.get("offer", [])
	if state != "done" and not offer.is_empty():
		box.add_child(_text("« %s »  — %s" % [str(offer[0]), giver], MUTED, 14))
	box.add_child(_text("Récompense : %d or%s" % [int(q["reward"]), "  (touchée)" if state == "done" else ""], GOLD if state != "done" else MUTED, 15))
	return card
