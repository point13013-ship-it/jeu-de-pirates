class_name WindZones
extends RefCounted
## Les caprices du vent (13/11/2026, retours de la session à 3) : des zones de calme fixes sur la carte, et de courtes sautes de
## vent. Dans les deux cas, garder les voiles hautes freine le bateau : il vaut mieux les carguer et courir sur son erre.
## - Calmes : le monde est découpé en cases de CELL m ; une case sur trois environ porte un disque de calme, toujours au même
##   endroit (tiré de la position de la case : tous les joueurs voient les mêmes, sans rien échanger).
## - Sautes : gérées par l'hôte (step), l'angle du vent est déjà diffusé avec l'état du bateau.

const CELL := 420.0            ## m : côté d'une case
const CALMS_ENABLED := false   ## 14/11 (demande d'Ilan : « je ne veux pas faire du sur-place ») : plus de zones de calme ; true pour les remettre
const ODDS := 0.34             ## part des cases qui portent un calme
const RADIUS_MIN := 80.0       ## m
const RADIUS_MAX := 130.0
const EDGE := 35.0             ## m : largeur du bord où le vent retombe progressivement
const STRENGTH := 0.15         ## force du vent au cœur d'un calme (1 : vent normal)
const PORT_CLEAR := 260.0      ## m : pas de calme si près du port

const SHIFT_EVERY_MIN := 240.0 ## s entre deux sautes de vent (tiré entre les deux)
const SHIFT_EVERY_MAX := 420.0
const SHIFT_TIME_MIN := 25.0   ## s : durée d'une saute
const SHIFT_TIME_MAX := 40.0
const SHIFT_ANGLE_MIN := 120.0 ## ° : de combien le vent tourne
const SHIFT_ANGLE_MAX := 180.0
const SHIFT_RAMP := 2.5        ## s pour tourner, et autant pour revenir

var shift_angle := 0.0         ## rad : décalage actuel du vent (0 hors saute)
var shifting := false          ## une saute est en cours
var _next := 0.0
var _left := 0.0
var _goal := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	_next = _rng.randf_range(SHIFT_EVERY_MIN, SHIFT_EVERY_MAX)


static func _hash(cx: int, cy: int, k: int) -> float:
	var h := (cx * 73856093) ^ (cy * 19349663) ^ (k * 83492791) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


## Le disque de calme de la case (cx, cy) : Vector3(x, z, rayon), ou Vector3.ZERO s'il n'y en a pas.
static func zone_of(cx: int, cy: int) -> Vector3:
	if _hash(cx, cy, 0) > ODDS:
		return Vector3.ZERO
	var c := Vector2((float(cx) + 0.2 + 0.6 * _hash(cx, cy, 1)) * CELL, (float(cy) + 0.2 + 0.6 * _hash(cx, cy, 2)) * CELL)
	if c.length() < PORT_CLEAR + RADIUS_MAX:
		return Vector3.ZERO
	return Vector3(c.x, c.y, lerpf(RADIUS_MIN, RADIUS_MAX, _hash(cx, cy, 3)))


## Force du vent en `p` (monde x/z) : 1 partout, STRENGTH au cœur d'un calme, progressif sur le bord.
static func strength_at(p: Vector2) -> float:
	if not CALMS_ENABLED:
		return 1.0
	var cx := floori(p.x / CELL)
	var cy := floori(p.y / CELL)
	var s := 1.0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var z := zone_of(cx + dx, cy + dy)
			if z.z <= 0.0:
				continue
			var d := Vector2(z.x, z.y).distance_to(p)
			s = minf(s, lerpf(STRENGTH, 1.0, clampf((d - (z.z - EDGE)) / EDGE, 0.0, 1.0)))
	return s


## Hôte, chaque image : fait naître et mourir les sautes de vent. `sailing` : le bateau navigue (pas de saute au port).
func step(delta: float, sailing: bool) -> void:
	if shifting:
		_left -= delta
		var k := clampf(minf(_left, SHIFT_RAMP) / SHIFT_RAMP, 0.0, 1.0) if _left < SHIFT_RAMP else 1.0
		shift_angle = move_toward(shift_angle, _goal * k, absf(_goal) / SHIFT_RAMP * delta)
		if _left <= 0.0:
			shifting = false
			shift_angle = 0.0
			_next = _rng.randf_range(SHIFT_EVERY_MIN, SHIFT_EVERY_MAX)
		return
	if not sailing:
		return
	_next -= delta
	if _next <= 0.0:
		shifting = true
		_left = _rng.randf_range(SHIFT_TIME_MIN, SHIFT_TIME_MAX)
		_goal = deg_to_rad(_rng.randf_range(SHIFT_ANGLE_MIN, SHIFT_ANGLE_MAX)) * (1.0 if _rng.randf() < 0.5 else -1.0)
