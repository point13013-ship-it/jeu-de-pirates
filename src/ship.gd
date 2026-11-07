class_name Ship
extends Node2D
## Un bateau de joueur. Le bateau local est piloté au clavier (W/S vitesse, A/D barre) ;
## les bateaux distants suivent les positions reçues par le réseau.
## Les valeurs (taille, vitesse, nombre de places) viennent de data/ships.json.

var seats: int = 2
var stats: Dictionary = {}
var is_local: bool = false
var owner_peer: int = 0

var speed: float = 0.0
var target_pos: Vector2 = Vector2.ZERO
var target_rot: float = 0.0


## Prépare le bateau avec ses places et ses caractéristiques.
func setup(p_seats: int, p_stats: Dictionary, p_local: bool, p_peer: int) -> void:
	seats = p_seats
	stats = p_stats
	is_local = p_local
	owner_peer = p_peer
	target_pos = position
	target_rot = rotation


func _physics_process(delta: float) -> void:
	if not is_local:
		position = position.lerp(target_pos, clampf(delta * 12.0, 0.0, 1.0))
		rotation = lerp_angle(rotation, target_rot, clampf(delta * 12.0, 0.0, 1.0))
		return
	var max_speed: float = float(stats.get("max_speed", 200.0))
	var throttle := Input.get_axis("nav_down", "nav_up")
	speed = move_toward(speed, throttle * max_speed, max_speed * 0.5 * delta)
	var steer := Input.get_axis("nav_left", "nav_right")
	# La barre agit d'autant plus que le bateau avance.
	rotation += steer * float(stats.get("turn_rate", 1.5)) * delta * clampf(absf(speed) / max_speed, 0.0, 1.0) * signf(speed if speed != 0.0 else 1.0)
	position += Vector2.RIGHT.rotated(rotation) * speed * delta


func _draw() -> void:
	var length: float = float(stats.get("length", 100.0))
	var width: float = float(stats.get("width", 40.0))
	var hull := Color(str(stats.get("color", "#a5673a")))
	var half_l := length * 0.5
	var half_w := width * 0.5
	var points := PackedVector2Array([
		Vector2(-half_l, -half_w), Vector2(half_l * 0.6, -half_w),
		Vector2(half_l, 0.0), Vector2(half_l * 0.6, half_w), Vector2(-half_l, half_w)])
	draw_colored_polygon(points, hull)
	draw_polyline(points + PackedVector2Array([points[0]]), hull.darkened(0.5), 3.0)
	# Un rond par place d'équipage.
	for i in seats:
		var x := lerpf(-half_l * 0.6, half_l * 0.4, float(i) / maxf(1.0, seats - 1.0))
		draw_circle(Vector2(x, 0.0), 6.0, Color.WHITE if is_local else Color(0.9, 0.9, 0.6))
