class_name TimedAction
extends RefCounted
## Une action qui prend du temps (lot 2, règle commune) : lever ou jeter l'ancre, réparer une voie d'eau, écoper, hisser un allié,
## relever un camarade (lot 4)… Elle avance tant que le joueur reste en place ; elle s'interrompt s'il se déplace, s'il fait autre
## chose ou s'il prend un coup. Le jeu l'affiche (jauge circulaire, animation, son) et l'annonce aux autres joueurs ; à la fin il
## applique son effet (demande à l'hôte, qui fait autorité).
## Durées : GameConfig.ACTION_TIMES.

var kind := ""             ## "anchor", "repair", "bail", "hoist"…
var label := ""            ## texte sous la jauge (« Lever l'ancre »)
var duration := 1.0        ## s
var t := 0.0               ## s écoulées
var arg := 0               ## paramètre de l'effet (voie d'eau visée, joueur à hisser…)
var origin := Vector2.ZERO ## où se tenait le joueur au départ (repère du lieu : pont, cale, terre)
var done := false
var cancelled := false


static func create(p_kind: String, p_label: String, p_duration: float, p_origin: Vector2, p_arg: int = 0) -> TimedAction:
	var a := TimedAction.new()
	a.kind = p_kind
	a.label = p_label
	a.duration = maxf(p_duration, 0.05)
	a.origin = p_origin
	a.arg = p_arg
	return a


## Durée réglée pour un genre d'action (voir GameConfig.ACTION_TIMES), ou `fallback`.
static func duration_of(p_kind: String, fallback: float = 1.0) -> float:
	return float(GameConfig.ACTION_TIMES.get(p_kind, fallback))


func progress() -> float:
	return clampf(t / duration, 0.0, 1.0)


## Fait avancer l'action. `pos` : où est le joueur (même repère que `origin`) ; `moving` : il appuie sur une direction ;
## `hurt` : il vient de prendre un coup. Renvoie vrai à l'image où elle se termine.
func step(delta: float, pos: Vector2, moving: bool, hurt: bool) -> bool:
	if done or cancelled:
		return false
	if moving or hurt or pos.distance_to(origin) > GameConfig.ACTION_MOVE_TOLERANCE:
		cancelled = true
		return false
	t += delta
	if t >= duration:
		t = duration
		done = true
		return true
	return false


## L'écopage a deux temps : on remplit le seau, puis on le vide. Renvoie la phase en cours ("fill" ou "pour").
func bail_phase() -> String:
	return "fill" if progress() < GameConfig.BAIL_FILL_SHARE else "pour"
