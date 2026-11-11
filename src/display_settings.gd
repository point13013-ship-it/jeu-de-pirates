class_name DisplaySettings
extends RefCounted
## Le mode d'affichage choisi par le joueur : fenêtré, plein écran ou fenêtre sans bordure plein écran.
## Gardé dans user://affichage.json et appliqué au lancement (setup) puis à chaque changement (set_mode).

const PATH := "user://affichage.json"
static var path := PATH   ## (les essais le détournent pour ne pas toucher aux réglages du joueur)
const MODES := ["windowed", "fullscreen", "borderless"]
const LABELS := {"windowed": "Fenêtré", "fullscreen": "Plein écran", "borderless": "Fenêtre sans bordure"}
const SHORT := {"windowed": "Fenêtré", "fullscreen": "Plein écran", "borderless": "Sans bordure"}
const DEFAULT := "windowed"

const HUD_MIN := 0.8
const HUD_MAX := 1.8
static var mode: String = DEFAULT
static var hud_scale := 1.0   ## taille de l'interface en jeu (texte, cadran, cœurs…) : 1 = taille d'origine
static var _inited := false


## À appeler au lancement : lit le réglage et l'applique (une seule fois).
static func setup() -> void:
	if _inited:
		return
	_inited = true
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				if MODES.has(str((data as Dictionary).get("mode", ""))):
					mode = str((data as Dictionary)["mode"])
				hud_scale = clampf(float((data as Dictionary).get("hud_scale", 1.0)), HUD_MIN, HUD_MAX)
	if mode != DEFAULT:
		apply()


## Change le mode, l'applique et le garde.
static func set_mode(m: String) -> void:
	if not MODES.has(m):
		return
	mode = m
	apply()
	save()


## Règle la taille de l'interface (le jeu la lit à chaque image) ; `save_now` faux pendant qu'on tire le curseur.
static func set_hud_scale(v: float, save_now: bool = true) -> void:
	hud_scale = clampf(v, HUD_MIN, HUD_MAX)
	if save_now:
		save()


## Pose le mode sur la fenêtre. Sans fenêtre réelle (essais sans tête), ne fait rien.
static func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var screen := DisplayServer.window_get_current_screen()
	match mode:
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var win := DisplayServer.window_get_size()
			var avail := DisplayServer.screen_get_usable_rect(screen)
			if win.x >= avail.size.x or win.y >= avail.size.y:   # sortie d'un plein écran : une fenêtre qui tient dans l'écran
				var size := Vector2i(mini(1280, avail.size.x - 80), mini(720, avail.size.y - 80))
				DisplayServer.window_set_size(size)
				DisplayServer.window_set_position(avail.position + (avail.size - size) / 2)


static func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"mode": mode, "hud_scale": hud_scale}, "\t"))
