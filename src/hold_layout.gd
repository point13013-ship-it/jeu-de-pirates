class_name HoldLayout
extends RefCounted
## Plan de la cale, sans rien de graphique : où l'on marche, où sont l'échelle, les planches, le seau et les
## voies d'eau. Repère de la cale : x vers l'étrave, z vers la caméra (le sud de l'écran) ; bâbord est donc au
## fond (z < 0), tribord devant. Distances en mètres de jeu.
##
## Coupe en travers : un fond plat, puis les bordés de la coque qui montent en pente de chaque côté. La pente
## regarde vers le haut, donc la caméra (qui regarde d'en haut, du sud) voit l'intérieur des DEUX flancs ;
## les voies d'eau s'ouvrent sur ces pentes. Au-dessus de la pente, au fond, un mur droit porte l'étagère.

const FLOOR_HALF := GameConfig.HOLD_FLOOR_HALF   ## demi-largeur du fond plat (lot 3 : 1,2 -> 1,8)
const RUN := 1.5            ## largeur horizontale d'une pente
const RISE := 0.8           ## hauteur d'une pente
const WALL_H := GameConfig.HOLD_WALL_H           ## mur du fond, au-dessus de la pente (lot 3 : 1,4 -> 1,8)
const HOLE_T := 0.55        ## position du trou sur la pente (0 = pied, 1 = haut)
const WALK_T := 0.88        ## jusqu'où l'on monte sur la pente
const MARGIN := GameConfig.HOLD_END_STORAGE      ## distance mini aux extrémités (lot 3 : on y range tonneaux et caisses)

var half_len := 5.0
var hatch_x := 0.0
var slot_xs: Array[float] = []
var circles: Array = []     ## [x, z, rayon] : tonneaux, caisse
var hull: HullDamage
var walls: Array[float] = []   ## abscisses des cloisons intérieures (13/11 : la cale est en trois pièces) ; on passe par la porte, au milieu


## Construit le plan de la cale d'un bateau de longueur `ship_length` (unités du modèle) dont l'écoutille est
## à l'abscisse `hatch_model_x`.
func setup(ship_length: float, hatch_model_x: float, p_hull: HullDamage) -> void:
	hull = p_hull
	var scale := ShipModel.SCALE
	var span := (hull.span_end - hull.span_start) * ship_length
	var mid := (hull.span_start + hull.span_end) * 0.5 * ship_length
	# lot 3 (3.3) : la cale est plus longue (et plus large : FLOOR_HALF) ; les voies d'eau et l'échelle s'écartent d'autant
	var k := GameConfig.HOLD_LENGTH_MULT
	half_len = span * scale * 0.5 * k + (MARGIN - 0.5)
	hatch_x = (hatch_model_x - mid) * scale * k
	slot_xs.clear()
	for s in hull.slots_per_side:
		slot_xs.append((hull.slot_bx(s) - mid) * scale * k)
	# 13/11 : deux cloisons coupent la cale en trois pièces (réserve avant, pièce de l'échelle, cambuse arrière). Elles
	# s'écartent de l'échelle et des voies d'eau pour ne gêner ni l'une ni les autres.
	walls.clear()
	for base: float in [half_len * 0.36]:   # (13/11, Jimmy : une seule cloison, à droite ; celle de gauche est retirée)
		var wx := base
		for tries in 8:
			var clash := absf(wx - hatch_x) < 1.1
			for sx: float in slot_xs:
				clash = clash or absf(wx - sx) < 0.7
			if not clash:
				break
			wx += 0.35 * signf(base)
		walls.append(wx)
	var e := half_len - MARGIN   # bout du passage
	circles = [
		[e - 0.4, 0.9, 0.42],
		[e - 0.4, 1.65, 0.42],
		[-e + 0.4, 0.95, 0.4],
	]


## Hauteur du sol de la cale à la profondeur z : plat au fond, puis la pente des bordés.
static func height_at(z: float) -> float:
	var a := absf(z)
	if a <= FLOOR_HALF:
		return 0.0
	return minf((a - FLOOR_HALF) / RUN, 1.0) * RISE


## Vrai si le pirate (rayon 0,2) peut se tenir en p = (x, z).
func is_walkable(p: Vector2) -> bool:
	if absf(p.x) > half_len - MARGIN or absf(p.y) > FLOOR_HALF + RUN * WALK_T:
		return false
	for c: Array in circles:
		if p.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]) + 0.2:
			return false
	for wx: float in walls:   # une cloison : on ne la franchit que par sa porte
		if absf(p.x - wx) < 0.28 and absf(p.y) > GameConfig.HOLD_DOOR_HALF - 0.2:
			return false
	return true


## Déplace `from` de `delta` en glissant le long des obstacles.
func move_with_slide(from: Vector2, delta: Vector2) -> Vector2:
	var target := from + delta
	if is_walkable(target):
		return target
	if is_walkable(Vector2(target.x, from.y)):
		return Vector2(target.x, from.y)
	if is_walkable(Vector2(from.x, target.y)):
		return Vector2(from.x, target.y)
	if not is_walkable(from):
		return target   # coincé : on laisse sortir
	return from


## Position (x, z) de la voie d'eau `slot`, sur la pente de son flanc.
func hole_pos(slot: int) -> Vector2:
	var side := hull.slot_side(slot)   # +1 bâbord = fond de l'écran (z négatif)
	return Vector2(slot_xs[hull.slot_rank(slot)], -float(side) * (FLOOR_HALF + RUN * HOLE_T))


## Pied de l'échelle qui remonte sur le pont.
func ladder_pos() -> Vector2:
	return Vector2(hatch_x, -(FLOOR_HALF + RUN * 0.6))


## Étagère à planches, contre le mur du fond, vers l'arrière.
func rack_pos() -> Vector2:
	return Vector2(-half_len + MARGIN + 1.0, -(FLOOR_HALF + RUN * 0.8))


## 13/11 (Jimmy) : l'armoire aux instruments (boussole ou longue-vue), contre le mur du fond, à gauche de l'échelle.
func tools_pos() -> Vector2:
	return Vector2(hatch_x - 1.7, -(FLOOR_HALF + RUN * 0.8))


## 13/11 (Jimmy) : le tableau des missions acceptées, contre le mur du fond, à droite de l'échelle.
func board_pos() -> Vector2:
	return Vector2(hatch_x + 1.7, -(FLOOR_HALF + RUN * 0.8))


## Le seau pour écoper, sur le fond.
func bucket_pos() -> Vector2:
	return Vector2(hatch_x - 1.9, 0.3)


## Point d'apparition en bas de l'échelle.
func spawn_pos() -> Vector2:
	return Vector2(hatch_x, -0.4)


## Tout ce avec quoi on peut agir dans la cale : {kind, pos, slot?}.
func items() -> Array:
	var out: Array = [
		{"kind": "ladder", "pos": ladder_pos()},
		{"kind": "rack", "pos": rack_pos()},
		{"kind": "bucket", "pos": bucket_pos()},
		{"kind": "tools", "pos": tools_pos()},
		{"kind": "missions", "pos": board_pos()},
	]
	for s in hull.slot_count():
		out.append({"kind": "hole", "pos": hole_pos(s), "slot": s})
	return out
