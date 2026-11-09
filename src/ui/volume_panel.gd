class_name VolumePanel
extends VBoxContainer
## Les curseurs de volume (général, musique, ambiance, effets), partagés par le menu Échap et le menu principal.
## Chaque curseur règle un bus audio tout de suite (AudioSettings) et le réglage est gardé quand on lâche le curseur.

const GOLD := Color("e0a93c")
const CREAM := Color("fff1d6")

var _sliders: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(300, 0)
	AudioSettings.setup()
	var title := Label.new()
	title.text = "Sons et musique"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GOLD)
	add_child(title)
	for key: String in AudioSettings.KEYS:
		var label := Label.new()
		label.text = str(AudioSettings.LABELS[key])
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", CREAM)
		add_child(label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = float(AudioSettings.volumes[key])
		slider.custom_minimum_size = Vector2(220, 28)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_NONE
		row.add_child(slider)
		var pct := Label.new()
		pct.text = "%d %%" % roundi(slider.value * 100.0)
		pct.custom_minimum_size = Vector2(52, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.add_theme_color_override("font_color", CREAM)
		row.add_child(pct)
		slider.value_changed.connect(func(v: float) -> void:
			AudioSettings.set_volume(key, v, false)
			pct.text = "%d %%" % roundi(v * 100.0))
		slider.drag_ended.connect(func(_changed: bool) -> void: AudioSettings.save())
		_sliders[key] = slider
	var reset := Button.new()
	reset.text = "Valeurs par défaut"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void:
		for key: String in AudioSettings.KEYS:
			(_sliders[key] as HSlider).value = float(AudioSettings.DEFAULTS[key])
		AudioSettings.save())
	add_child(reset)


## Remet les curseurs d'après les réglages en cours (à l'ouverture du menu).
func refresh() -> void:
	for key: String in AudioSettings.KEYS:
		(_sliders[key] as HSlider).set_value_no_signal(float(AudioSettings.volumes[key]))
