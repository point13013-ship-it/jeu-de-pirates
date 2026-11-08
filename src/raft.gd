class_name Raft
extends Node3D
## Un radeau à voile, fabriqué avec des planches (voir Crafting) pour quitter une île sans bateau : six rondins liés, un mât, une
## vergue et une voile de fortune. Il avance au vent comme un bateau (ShipSim), mais la voile se règle toute seule : on ne fait
## que barrer (A/D) et hisser ou affaler (W/S). Le nœud se pose dans le monde fixe (position = x, hauteur, z du monde) ; son axe +X
## est l'avant, comme pour un bateau (cap `sim.yaw`). Le jeu le fait flotter (`float_on`) et gère les collisions.

const LENGTH := 3.6                         ## m
const HALF := Vector2(1.8, 1.25)            ## m : demi-longueur et demi-largeur
const STAND := Vector2(-0.5, 0.0)           ## où se tient le pirate (repère du radeau, x vers l'avant)
const TOP := 0.34                           ## m : hauteur du pont au-dessus de la ligne de flottaison
const STATS := {"max_speed": 4.6, "turn_rate": 1.1, "accel": 1.0, "sail_speed": 0.9}
const MAST_X := 0.55
const YARD_Y := 2.75
const SAIL_H := 1.85

const WOOD := Color(0.66, 0.47, 0.29)
const WOOD_L := Color(0.76, 0.57, 0.36)
const WOOD_D := Color(0.44, 0.3, 0.18)
const ROPE := Color(0.82, 0.68, 0.42)
const CLOTH := Color(0.93, 0.88, 0.74)
const CLOTH_D := Color(0.78, 0.7, 0.54)
const FLAG := Color(0.78, 0.16, 0.12)

var sim := ShipSim.new()
var owner_id := 0                           ## le joueur qui l'a fabriqué (0 : inconnu)
var _yard: Node3D                           ## pivot de la vergue et de la voile (tourne autour du mât)
var _sail: Node3D                           ## la voile, ancrée en haut : elle se resserre vers la vergue quand on l'affale
var _sail_mat: StandardMaterial3D
var _seam_mat: StandardMaterial3D
var _flag: Node3D
var _time := 0.0


func _init() -> void:
	sim.configure(STATS)
	sim.anchored = true     # personne à bord : il reste où il est
	_build()


## Le radeau à l'état visuel `pos`, `yaw`, ouverture et orientation de voile (radeau d'un autre joueur, reçu du réseau).
func apply_pose(yaw: float, sail_open: float, sail_trim: float) -> void:
	sim.yaw = yaw
	sim.sail_open = sail_open
	sim.sail_trim = sail_trim
	_apply_sail()


## La voile devient plus ou moins translucide : on voit le pirate qui est derrière (1 = pleine).
func set_sail_alpha(a: float) -> void:
	_sail_mat.albedo_color.a = a
	_seam_mat.albedo_color.a = a


func _sail_part(size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _seam_mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sail.add_child(mi)


## Chaque image : la voile suit la simulation, le fanion claque.
func update_visual(delta: float) -> void:
	_time += delta
	_apply_sail()
	if _flag != null:
		_flag.rotation.y = -sim.sail_trim * 0.2 + sin(_time * 7.0) * 0.12


func _apply_sail() -> void:
	if _yard == null:
		return
	_yard.rotation.y = -sim.sail_trim
	var s := maxf(0.06, sim.sail_open)
	_sail.scale = Vector3(1.0, s, 1.0)
	_sail.visible = sim.sail_open > 0.02 or sim.sail_level > 0


## Les quatre coins et les milieux de la coque en coordonnées du monde (x/z), pour tester la rencontre avec la terre.
static func hull_points(pos: Vector2, yaw: float) -> Array:
	var fwd := Vector2(cos(yaw), -sin(yaw))
	var left := Vector2(-fwd.y, fwd.x) * -1.0
	var pts: Array = []
	for fx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for fz in [-1.0, 0.0, 1.0]:
			pts.append(pos + fwd * (HALF.x * fx) + left * (HALF.y * fz))
	return pts


## Vrai si le point monde `p` est sur le pont du radeau (à `margin` m près).
static func covers(pos: Vector2, yaw: float, p: Vector2, margin: float = 0.0) -> bool:
	var fwd := Vector2(cos(yaw), -sin(yaw))
	var left := Vector2(-fwd.y, fwd.x) * -1.0
	var rel := p - pos
	return absf(rel.dot(fwd)) <= HALF.x + margin and absf(rel.dot(left)) <= HALF.y + margin


## Où se tient le pirate, en coordonnées du monde (x/z).
static func stand_world(pos: Vector2, yaw: float) -> Vector2:
	var fwd := Vector2(cos(yaw), -sin(yaw))
	var left := Vector2(-fwd.y, fwd.x) * -1.0
	return pos + fwd * STAND.x + left * STAND.y


## Pose le radeau sur la houle : hauteur moyenne de l'eau sous les coins, tangage et roulis. `h(Vector2) -> float` donne la houle.
func float_on(pos: Vector2, h: Callable, sea_y: float) -> void:
	var yaw := sim.yaw
	var fwd := Vector2(cos(yaw), -sin(yaw))
	var left := Vector2(-fwd.y, fwd.x) * -1.0
	var hb: float = h.call(pos + fwd * HALF.x)
	var hs: float = h.call(pos - fwd * HALF.x)
	var hp: float = h.call(pos + left * HALF.y)
	var hst: float = h.call(pos - left * HALF.y)
	var heave := (hb + hs + hp + hst) * 0.25 * 0.9
	var pitch := atan2(hb - hs, HALF.x * 2.0) * 0.8
	var roll := atan2(hp - hst, HALF.y * 2.0) * 0.8
	position = Vector3(pos.x, sea_y + heave, pos.y)
	rotation = Vector3(roll, yaw, pitch)


# ------------------------------------------------------------------ modèle

func _build() -> void:
	# six rondins dans le sens de la longueur, de longueurs un peu inégales (fait main)
	var lens: Array = [3.5, 3.6, 3.4, 3.6, 3.5, 3.4]
	for i in 6:
		var z := -0.95 + float(i) * 0.38
		var l: float = lens[i]
		var c := WOOD if i % 2 == 0 else WOOD_L
		ShipCannons._box(self, Vector3(l, 0.26, 0.36), Vector3(0.0 + (3.6 - l) * 0.15, TOP - 0.13, z), c)
		# le bout de chaque rondin est plus clair (coupe)
		ShipCannons._box(self, Vector3(0.04, 0.2, 0.3), Vector3(l * 0.5 - 0.02 + (3.6 - l) * 0.15, TOP - 0.13, z), WOOD_D)
	# deux traverses liées par des cordes
	for x in [-0.95, 0.85]:
		ShipCannons._box(self, Vector3(0.2, 0.1, 2.5), Vector3(x, TOP + 0.04, 0.0), WOOD_D)
		for z in [-1.0, -0.38, 0.38, 1.0]:
			ShipCannons._box(self, Vector3(0.24, 0.13, 0.07), Vector3(x, TOP + 0.05, z), ROPE)
	# le mât, bloqué par deux taquets
	ShipCannons._cyl(self, 0.065, 0.085, 2.9, Vector3(MAST_X, TOP + 1.4, 0.0), "y", WOOD_D)
	ShipCannons._box(self, Vector3(0.3, 0.12, 0.12), Vector3(MAST_X, TOP + 0.1, 0.0), WOOD_D)
	ShipCannons._box(self, Vector3(0.12, 0.12, 0.3), Vector3(MAST_X, TOP + 0.1, 0.0), WOOD_D)
	# la vergue et la voile pivotent ensemble autour du mât
	_yard = Node3D.new()
	_yard.position = Vector3(MAST_X, TOP + YARD_Y - 0.2, 0.0)
	add_child(_yard)
	ShipCannons._cyl(_yard, 0.04, 0.04, 2.1, Vector3.ZERO, "z", WOOD_D)
	_sail = Node3D.new()
	_yard.add_child(_sail)
	_sail_mat = StandardMaterial3D.new()
	_sail_mat.albedo_color = CLOTH
	_sail_mat.roughness = 1.0
	_sail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # (devient translucide quand le pirate est derrière)
	_seam_mat = StandardMaterial3D.new()
	_seam_mat.albedo_color = CLOTH_D
	_seam_mat.roughness = 1.0
	_seam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cloth := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, SAIL_H, 1.95)
	cloth.mesh = bm
	cloth.material_override = _sail_mat
	cloth.position = Vector3(0.0, -SAIL_H * 0.5 - 0.03, 0.0)
	_sail.add_child(cloth)
	# trois coutures et un rapiéçage pour qu'elle ait l'air de fortune
	for k in 3:
		_sail_part(Vector3(0.045, SAIL_H, 0.035), Vector3(0.0, -SAIL_H * 0.5 - 0.03, -0.55 + float(k) * 0.55))
	_sail_part(Vector3(0.05, 0.42, 0.5), Vector3(0.0, -SAIL_H * 0.72, 0.4))
	# fanion au sommet du mât
	_flag = Node3D.new()
	_flag.position = Vector3(MAST_X, TOP + 2.95, 0.0)
	add_child(_flag)
	ShipCannons._box(_flag, Vector3(0.42, 0.22, 0.02), Vector3(-0.21, 0.0, 0.0), FLAG)
	# un petit tonneau et une corde enroulée à l'arrière : on vit à bord
	ShipCannons._cyl(self, 0.2, 0.2, 0.34, Vector3(-1.35, TOP + 0.19, 0.7), "y", WOOD_D)
	ShipCannons._cyl(self, 0.21, 0.21, 0.06, Vector3(-1.35, TOP + 0.2, 0.7), "y", ROPE)
	_apply_sail()
