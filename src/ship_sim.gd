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


## Direction de l'étrave dans le monde, vecteur (x, z) unitaire.
func forward() -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


## Alignement du bateau avec le vent : 1 = vent arrière, 0 = vent de travers, -1 = face au vent.
func wind_alignment() -> float:
	return forward().dot(wind_dir)


## Rendement du vent dans les voiles, de 0.12 (face au vent) à 1.0 (vent arrière).
func wind_factor() -> float:
	return 0.12 + 0.88 * pow(clampf((wind_alignment() + 1.0) * 0.5, 0.0, 1.0), 0.6)


## Fait avancer la simulation de `dt` secondes.
func step(dt: float) -> void:
	sail_open = move_toward(sail_open, float(sail_level) / SAIL_LEVELS, sail_speed * dt)
	rudder = move_toward(rudder, rudder_target, 1.6 * dt)
	var target := 0.0 if anchored else max_speed * sail_open * wind_factor() * drag
	var rate := accel if target > speed else accel * (2.6 if anchored else 0.6)
	speed = move_toward(speed, target, rate * dt)
	var steer := MIN_STEER + (1.0 - MIN_STEER) * clampf(speed / (max_speed * 0.6), 0.0, 1.0)
	if anchored:
		steer = 0.3  # l'ancre fait pivoter le bateau lentement
	yaw -= rudder * turn_rate * steer * dt
	position += forward() * speed * dt
