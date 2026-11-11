class_name ShipSim
extends RefCounted
## Simulation d'un bateau façon Sea of Thieves : la vitesse dépend des voiles hissées et de l'angle
## du vent, la barre tourne d'autant plus que le bateau avance, l'ancre le stoppe net.
## Repère monde : (x, z) à plat, y vers le haut. Le cap `yaw` est la rotation autour de Y :
## yaw = 0 vers +x, yaw positif vers -z (gauche à l'écran).

const SAIL_LEVELS := 3
const MIN_STEER := 0.12

var yaw: float = 0.0
var position := Vector2.ZERO
var speed: float = 0.0
var rudder: float = 0.0          ## position actuelle de la barre, -1 (bâbord) .. 1 (tribord)
var rudder_target: float = 0.0
var sail_level: int = 0          ## 0..3 : niveau demandé par l'équipage
var sail_open: float = 0.0       ## 0..1 : ouverture réelle des voiles (elles se hissent en quelques secondes)
var anchored: bool = false
var wind_dir := Vector2(1.0, 0.0)  ## direction vers laquelle le vent souffle (vecteur unitaire monde)
var wind_angle := 0.0            ## le même vent en angle (rad, Vector2.angle) ; il dérive lentement (voir drift_wind)
var sail_trim := 0.0             ## orientation réelle des vergues (rad, sens de Vector2.rotated) : 0 = perpendiculaires à la coque
var sail_trim_target := 0.0
var trim_input := 0.0            ## -1..1 : quelqu'un tourne les vergues au mât
var auto_trim_pending := true    ## voiles affalées : au prochain hissage, l'équipage les règle d'emblée au mieux

const MAX_TRIM := 1.13           ## rad (65°)
const TRIM_SPEED := 0.55         ## rad/s : vitesse à laquelle les vergues tournent
const TRIM_FLOOR := 0.18         ## rendement d'une voile très mal réglée (elle ne tire presque plus)

var max_speed: float = 8.0       ## m/s, toutes voiles dehors, vent arrière
var turn_rate: float = 0.55      ## rad/s à pleine barre et pleine vitesse
var accel: float = 1.1           ## m/s²
var sail_speed: float = 0.35     ## ouverture par seconde
var drag: float = 1.0            ## facteur sur la vitesse visée : 1 à sec, moins quand la cale se remplit


## Configure le bateau depuis ses caractéristiques (données externes).
func configure(stats: Dictionary) -> void:
	max_speed = float(stats.get("max_speed", max_speed))
	turn_rate = float(stats.get("turn_rate", turn_rate))
	accel = float(stats.get("accel", accel))
	sail_speed = float(stats.get("sail_speed", sail_speed))


## Sinus de l'inclinaison de la caméra (1 = pas de correction). Vue de dessus inclinée, un mètre « vers le haut de l'écran » paraît
## plus court qu'un mètre « sur le côté » : le jeu le renseigne pour que le bateau avance à la même vitesse à l'écran dans
## toutes les directions.
static var view_sin: float = 1.0


## Facteur sur le déplacement réel pour que la vitesse À L'ÉCRAN ne dépende pas du cap.
func screen_comp() -> float:
	var f := forward()
	return 1.0 / maxf(sqrt(f.x * f.x + f.y * f.y * view_sin * view_sin), 0.2)


## Direction de l'étrave dans le monde, vecteur (x, z) unitaire.
func forward() -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


## Alignement du bateau avec le vent : 1 = vent arrière, 0 = vent de travers, -1 = face au vent.
func wind_alignment() -> float:
	return forward().dot(wind_dir)


## Rendement du vent dans les voiles, de 0.12 (face au vent) à 1.0 (vent arrière).
func wind_factor() -> float:
	return 0.12 + 0.88 * pow(clampf((wind_alignment() + 1.0) * 0.5, 0.0, 1.0), 0.6)


## Angle du vent par rapport à l'étrave (rad, -PI..PI) : 0 = vent arrière, ±PI/2 = de travers, ±PI = vent debout.
func wind_relative() -> float:
	return forward().angle_to(wind_dir)


## Poussée d'une voile plate dont la normale est tournée de `theta` par rapport à l'axe du bateau, quand le vent souffle
## sous l'angle `delta` : la pression est proportionnelle à (vent·normale)², et seule sa part le long de la coque avance.
static func sail_thrust(delta: float, theta: float) -> float:
	var c := cos(delta - theta)
	return c * absf(c) * cos(theta)


## L'orientation de vergue qui donne la meilleure poussée pour ce vent (rad, même sens que sail_trim).
func optimal_trim() -> float:
	var d := wind_relative()
	var best := -INF
	var best_t := 0.0
	for k in 53:
		var t := lerpf(-MAX_TRIM, MAX_TRIM, float(k) / 52.0)
		var v := sail_thrust(d, t)
		if v > best + 0.0001:
			best = v
			best_t = t
	return best_t


## Rendement du réglage des voiles, de TRIM_FLOOR (mal réglées) à 1 (au mieux). Vent debout il n'y a rien à régler.
func trim_efficiency() -> float:
	var d := wind_relative()
	var best := sail_thrust(d, optimal_trim())
	if best < 0.05:
		return 1.0
	var t := sail_thrust(d, sail_trim)
	return TRIM_FLOOR + (1.0 - TRIM_FLOOR) * clampf(t / best, 0.0, 1.0)


## Hisse (+1) ou affale (-1) d'un cran. Quand on hisse depuis des voiles affalées, les matelots règlent d'emblée les
## vergues au mieux pour le vent du moment ; ensuite c'est à l'équipage de les suivre quand le vent ou le cap change.
func change_sails(step_levels: int) -> void:
	if sail_level == 0 and step_levels > 0 and auto_trim_pending:
		sail_trim_target = optimal_trim()
		auto_trim_pending = false
	sail_level = clampi(sail_level + step_levels, 0, SAIL_LEVELS)


## Fait varier le vent : il tourne lentement (quelques degrés par dizaine de secondes), toujours dans une bande autour du
## vent d'origine pour que le port reste jouable. `t` : temps de la partie (s).
func drift_wind(t: float) -> void:
	wind_angle = deg_to_rad(28.0 * sin(t * 0.021) + 17.0 * sin(t * 0.047 + 1.3))
	wind_dir = Vector2.from_angle(wind_angle)


## Fait avancer la simulation de `dt` secondes.
func step(dt: float) -> void:
	sail_open = move_toward(sail_open, float(sail_level) / SAIL_LEVELS, sail_speed * dt)
	if sail_level == 0 and sail_open < 0.02:
		auto_trim_pending = true
	if absf(trim_input) > 0.01:
		sail_trim_target = clampf(sail_trim_target + trim_input * TRIM_SPEED * 1.2 * dt, -MAX_TRIM, MAX_TRIM)
	sail_trim = move_toward(sail_trim, sail_trim_target, TRIM_SPEED * dt)
	rudder = move_toward(rudder, rudder_target, 1.6 * dt)
	var target := 0.0 if anchored else max_speed * sail_open * sail_efficiency() * drag
	var rate := accel if target > speed else accel * (2.6 if anchored else 0.6)
	speed = move_toward(speed, target, rate * dt)
	var steer := MIN_STEER + (1.0 - MIN_STEER) * clampf(speed / (max_speed * 0.6), 0.0, 1.0)
	if anchored:
		steer = 0.3  # l'ancre fait pivoter le bateau lentement
	yaw -= rudder * turn_rate * steer * dt
	position += forward() * speed * dt * screen_comp()


const MIN_SAIL_EFF := 0.4    ## rendement minimal des voiles (vent debout + vergues mal réglées) : le vent ralentit, il n'arrête jamais le bateau

## Rendement total des voiles, de MIN_SAIL_EFF (très mauvais vent / réglage) à 1 (vent arrière, vergues au mieux).
func sail_efficiency() -> float:
	return MIN_SAIL_EFF + (1.0 - MIN_SAIL_EFF) * clampf(wind_factor() * trim_efficiency(), 0.0, 1.0)
