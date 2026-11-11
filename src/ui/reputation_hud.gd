class_name ReputationHud
extends Control
## La réputation de pirate à l'écran : le rang et une barre de progression en bas à droite, qui se remplit en s'animant quand
## on gagne des points (éclat doré, « +N » qui monte), et une bannière quand on passe un rang (avec les skins débloqués).
## Le jeu appelle `set_points` au départ, `gain` à chaque gain et `rank_up` quand le rang change.

const GOLD := Color("e0a93c")
const CREAM := Color("fff1d6")
const BAR_W := 244.0
const BAR_H := 12.0
const BANNER_TIME := 4.6

var shown := 0.0             ## points affichés (rattrapent `goal` en douceur : c'est ce qui anime la barre)
var goal := 0.0
var glow := 0.0              ## 0..1 : éclat autour du cadre après un gain
var flash := 0.0             ## 0..1 : éclair blanc de la barre quand elle passe un rang
var active_t := 0.0          ## s restantes d'affichage « plein » (le cadre est plus discret au repos)
var banner_t := -1.0         ## âge de la bannière de rang (-1 : pas de bannière)
var banner_title := ""
var banner_lines: Array = []
var _floaters: Array = []    ## [{text, age}]
var _last_rank := 0
var _t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pose les points sans animation (au chargement du profil).
func set_points(p: int) -> void:
	shown = float(p)
	goal = float(p)
	_last_rank = Reputation.rank_of(p)


## `n` points viennent d'être gagnés : la barre se remplit de `from` à `to`.
func gain(from: int, to: int, n: int) -> void:
	if absf(shown - goal) < 0.5:
		shown = float(from)   # pas d'animation en cours : on repart de l'ancienne valeur
	goal = float(to)
	glow = 1.0
	active_t = 7.0
	_floaters.append({"text": "+%d réputation" % n, "age": 0.0})


## Un nouveau rang : bannière avec le nom du rang et ce qu'il débloque.
func rank_up(rank_name: String, unlocked: Array) -> void:
	banner_title = rank_name
	banner_lines = unlocked
	banner_t = 0.0
	active_t = 9.0


func _process(delta: float) -> void:
	_t += delta
	if absf(goal - shown) > 0.01:
		shown = move_toward(shown, goal, maxf(absf(goal - shown) * 2.2, 14.0) * delta)
	var r := Reputation.rank_of(int(shown))
	if r != _last_rank:
		if r > _last_rank:
			flash = 1.0   # la barre déborde : éclair
		_last_rank = r
	glow = maxf(glow - delta * 0.7, 0.0)
	flash = maxf(flash - delta * 1.6, 0.0)
	active_t = maxf(active_t - delta, 0.0)
	for f: Dictionary in _floaters:
		f["age"] = float(f["age"]) + delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["age"]) < 2.4)
	if banner_t >= 0.0:
		banner_t += delta
		if banner_t > BANNER_TIME:
			banner_t = -1.0
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var p := int(shown)
	var r := Reputation.rank_of(p)
	var alpha := clampf(0.5 + active_t * 0.3, 0.5, 1.0)
	var origin := Vector2(size.x - BAR_W - 28.0, size.y - 158.0)
	var panel := Rect2(origin, Vector2(BAR_W + 16.0, 50.0))
	draw_rect(panel, Color(0.07, 0.04, 0.09, 0.78 * alpha))
	var edge := GOLD.lerp(Color.WHITE, glow * 0.7)
	edge.a = (0.5 + 0.5 * glow) * alpha
	draw_rect(panel, edge, false, 2.0 + 2.0 * glow)
	if glow > 0.02:   # halo doré qui s'éteint
		draw_rect(panel.grow(3.0 + 7.0 * glow), Color(1.0, 0.8, 0.3, 0.28 * glow), false, 3.0)
	draw_string(font, origin + Vector2(10, 19), Reputation.rank_name(r), HORIZONTAL_ALIGNMENT_LEFT, 150, 15, Color(CREAM, alpha))
	var right_text := "%d / %d" % [p, Reputation.points_for(r + 1)] if not Reputation.is_max(p) else "%d  (rang max)" % p
	draw_string(font, origin + Vector2(BAR_W - 128.0 + 8.0, 19), right_text, HORIZONTAL_ALIGNMENT_RIGHT, 128, 13, Color(0.85, 0.8, 0.7, alpha))
	var bar := Rect2(origin + Vector2(8, 28), Vector2(BAR_W, BAR_H))
	draw_rect(bar, Color(0.02, 0.01, 0.03, 0.9))
	var frac := Reputation.progress(p) if not Reputation.is_max(p) else 1.0
	var fill := Rect2(bar.position + Vector2(1, 1), Vector2((BAR_W - 2.0) * frac, BAR_H - 2.0))
	var col := Color(0.88, 0.62, 0.18).lerp(Color(1.0, 0.92, 0.5), 0.5 + 0.5 * sin(_t * 6.0) * glow)
	col = col.lerp(Color.WHITE, flash)
	draw_rect(fill, col)
	if absf(goal - shown) > 0.5 and fill.size.x > 3.0:   # reflet qui court sur la barre pendant qu'elle se remplit
		var sx := fill.position.x + fmod(_t * 160.0, maxf(fill.size.x, 1.0))
		draw_rect(Rect2(sx, fill.position.y, 10.0, fill.size.y), Color(1, 1, 1, 0.45))
	# les « +N réputation » qui montent
	for f: Dictionary in _floaters:
		var age := float(f["age"])
		var a := clampf(1.0 - age / 2.4, 0.0, 1.0)
		var pos := origin + Vector2(10, -6.0 - age * 22.0)
		draw_string_outline(font, pos, str(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, 220, 17, 5, Color(0.1, 0.05, 0.02, a))
		draw_string(font, pos, str(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, 220, 17, Color(1.0, 0.88, 0.4, a))
	if banner_t >= 0.0:
		_draw_banner(font)


## La bannière de nouveau rang : elle gonfle en arrivant, reste un moment, puis s'efface ; des rayons dorés tournent derrière.
func _draw_banner(font: Font) -> void:
	var t := banner_t
	var appear := clampf(t / 0.45, 0.0, 1.0)
	var pop := 0.55 + 0.45 * appear + 0.18 * sin(appear * PI)   # un petit dépassement à l'arrivée
	var fade := clampf((BANNER_TIME - t) / 0.8, 0.0, 1.0)
	var c := Vector2(size.x * 0.5, size.y * 0.3)
	var w := 420.0 * pop
	var lines := banner_lines.size()
	var h := (92.0 + 22.0 * lines) * pop
	# rayons
	for k in 12:
		var a := TAU * k / 12.0 + t * 0.6
		var from := c + Vector2.from_angle(a) * (h * 0.5 + 6.0)
		var to := c + Vector2.from_angle(a) * (h * 0.5 + 40.0 + 24.0 * sin(t * 5.0 + k))
		draw_line(from, to, Color(1.0, 0.85, 0.35, 0.5 * fade * appear), 3.0)
	var rect := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	draw_rect(rect, Color(0.08, 0.04, 0.1, 0.9 * fade))
	draw_rect(rect, Color(GOLD, fade), false, 3.0)
	draw_rect(rect.grow(-6.0), Color(GOLD, 0.45 * fade), false, 1.0)
	var fs := int(round(14.0 * pop))
	draw_string(font, rect.position + Vector2(0, 28.0 * pop), "NOUVEAU RANG", HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(0.85, 0.8, 0.7, fade))
	var ts := int(round(34.0 * pop))
	draw_string_outline(font, rect.position + Vector2(0, 66.0 * pop), banner_title, HORIZONTAL_ALIGNMENT_CENTER, w, ts, 6, Color(0.1, 0.05, 0.02, fade))
	draw_string(font, rect.position + Vector2(0, 66.0 * pop), banner_title, HORIZONTAL_ALIGNMENT_CENTER, w, ts, Color(1.0, 0.88, 0.4, fade))
	for i in lines:
		draw_string(font, rect.position + Vector2(0, (92.0 + 20.0 * i) * pop), "Débloqué : %s" % str(banner_lines[i]), HORIZONTAL_ALIGNMENT_CENTER, w, int(round(15.0 * pop)), Color(CREAM, fade))
