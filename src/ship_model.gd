class_name ShipModel
extends Node3D
## Modèle 3D d'un bateau et ses données de jeu : collisions du pont, cabine, points d'interaction.
## Les calculs de jeu se font dans le repère du modèle (x vers l'étrave, y vers bâbord, en mètres
## avant mise à l'échelle) ; to_local3() convertit vers la scène Godot.

const SCALE := 1.5            ## mètres de jeu par unité du modèle
const WALK_RADIUS := 0.08     ## rayon du personnage, en unités du modèle
const RAIL_MARGIN := 0.18      ## distance minimale du pirate au plat-bord
const MIN_LANE := 0.45        ## demi-largeur minimale du couloir de marche (vers l'étrave)

var ship_name: String = ""
var meta: Dictionary = {}
var shift: float = 0.0
var length: float = 16.0
var beam: float = 5.6
var boxes: Array = []          ## [x0, y0, x1, y1]
var circles: Array = []        ## [x, y, rayon]
var cabin: Dictionary = {}
var cannons: Array = []        ## [x, y, côté, z]
var ladders: Array = []        ## [x, y du pirate, côté, y de la coque] : échelles de coque
var nests: Array = []          ## [x, y, z du plancher, hauteur du mât]
var mast_ladder: Array = []    ## [x, y, z bas, z haut] : échelle du mât le plus haut, vers son nid
var bow_x := 0.0               ## abscisse la plus avancée où l'on peut se tenir (la pointe)
var sheer := 1.0               ## tonture : facteur sur la remontée du pont vers l'étrave et la poupe (méta du modèle)
var low_boxes: Array = []      ## indices des boîtes qu'on peut enjamber d'un saut (caisses), les autres sont des murs
var low_circles: Array = []    ## indices des cercles qu'on peut enjamber (barre, tonneau) ; les mâts sont trop hauts
var cannon_stubs: Array = []   ## les petits canons du modèle d'origine, masqués : le jeu pose des canons plus gros (ShipCannons)
var masts: Array = []          ## [x, hauteur] de chaque mât
var crate_pos := Vector2.INF   ## où se trouve la pile de caisses du pont (repère du modèle), INF si le modèle n'en a pas
var stash_pos := Vector2.INF   ## où se trouve le coffre du capitaine, dans la cabine (repère du modèle)

const RAIL_HEIGHT := 0.35      ## m : au-dessus de cette hauteur de saut, on passe par-dessus le plat-bord
const LOW_CLEAR := 0.5         ## m : hauteur de saut qui suffit pour enjamber une caisse, un tonneau ou la roue

var _model: Node3D
var _sails: Array = []         ## {node, top, base: Transform3D, alpha}
var _sail_pivot: Array = []    ## par voile : abscisse (repère du glb) de l'axe du mât autour duquel elle pivote, NAN si elle ne pivote pas
var _sail_open_v := 1.0
var _sail_trim_v := 0.0
var _cuts: Array = []          ## {node, normal: Vector2, always: bool}


## Charge le modèle `p_name` (sloop, brigantin, galion). Renvoie false si un fichier manque.
func load_ship(p_name: String) -> bool:
	var scene := load("res://assets/models/ship/%s.glb" % p_name) as PackedScene
	var f := FileAccess.open("res://assets/models/ship/%s_meta.json" % p_name, FileAccess.READ)
	if scene == null or f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return false
	ship_name = p_name
	meta = parsed
	shift = float(meta.get("shift", 0.0))
	length = float(meta.get("length", 16.0))
	beam = float(meta.get("beam", 5.6))
	boxes = meta.get("boxes", [])
	circles = meta.get("circles", [])
	cabin = meta.get("cabin", {})
	cannons = meta.get("cannons", [])
	_apply_layout_overrides(p_name)
	ladders = meta.get("ladders", [])
	nests = meta.get("nests", [])
	mast_ladder = meta.get("mast_ladder", [])
	bow_x = float(meta.get("bow_x", length * 0.5 - 0.4))
	sheer = float(meta.get("sheer", 1.0))
	masts = meta.get("masts", [])
	_model = scene.instantiate() as Node3D
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_index_nodes(_model)
	_build_helm_wheel()
	_dress_sails(_model)
	_dress_flag()
	_compute_low_obstacles()   # (après _index_nodes : il faut savoir où est la pile de caisses)
	# les canons sont solides (12/11) : leur emprise au sol est un obstacle bas, qu'un saut enjambe
	for c: Array in cannons:
		boxes.append(ShipCannons.footprint(c))
		low_boxes.append(boxes.size() - 1)
	_compute_sail_pivots()
	return true


var _helm_disc: Node3D
var _helm_wheel: Node3D
var _helm_base := Transform3D.IDENTITY


## Lot 3 (3.9) : la roue du gouvernail. Le modèle n'avait qu'un disque plat ; on le remplace (même place, même axe) par une
## roue de bois sculptée : jante, huit rayons qui dépassent en poignées tournées, moyeu et ferrures de laiton, bois un peu usé
## (rayons de teintes légèrement différentes). Unités du modèle (le modèle est agrandi par SCALE). Elle tourne avec la barre
## (set_helm), chez tous les joueurs : l'angle de la barre fait partie de l'état du bateau envoyé par l'hôte.
func _build_helm_wheel() -> void:
	if _helm_disc == null:
		return
	_helm_disc.visible = false
	_helm_base = _helm_disc.transform
	var r := GameConfig.HELM_WHEEL_RADIUS
	var wheel := Node3D.new()
	wheel.name = "helm_wheel"
	_helm_disc.get_parent().add_child(wheel)
	wheel.transform = _helm_base
	var wood := _mat(Color(0.42, 0.25, 0.13), 0.85)
	var wood_dark := _mat(Color(0.33, 0.19, 0.1), 0.9)
	var brass := _mat(Color(0.78, 0.6, 0.25), 0.35, 0.8)
	# la jante (deux anneaux de bois, une bande de laiton entre eux)
	for k in 2:
		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.07
		tm.outer_radius = r
		tm.rings = 28
		tm.ring_segments = 8
		rim.mesh = tm
		rim.material_override = wood if k == 0 else wood_dark
		rim.position = Vector3(0.0, -0.022 + 0.044 * k, 0.0)
		rim.scale = Vector3(1.0, 0.7, 1.0)
		wheel.add_child(rim)
	var band := MeshInstance3D.new()
	var bt := TorusMesh.new()
	bt.inner_radius = r - 0.045
	bt.outer_radius = r - 0.025
	bt.rings = 28
	bt.ring_segments = 6
	band.mesh = bt
	band.material_override = brass
	wheel.add_child(band)
	# huit rayons, et leur poignée tournée au-delà de la jante
	for k in 8:
		var a := TAU * float(k) / 8.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var spoke := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.022
		cm.bottom_radius = 0.032
		cm.height = r
		cm.radial_segments = 8
		spoke.mesh = cm
		spoke.material_override = wood if k % 2 == 0 else wood_dark
		spoke.basis = _basis_along(dir)
		spoke.position = dir * (r * 0.5)
		wheel.add_child(spoke)
		var handle := MeshInstance3D.new()
		var hm := CapsuleMesh.new()
		hm.radius = 0.034
		hm.height = 0.2
		hm.radial_segments = 8
		hm.rings = 2
		handle.mesh = hm
		handle.material_override = wood_dark
		handle.basis = _basis_along(dir)
		handle.position = dir * (r + 0.1)
		wheel.add_child(handle)
	# moyeu de laiton et cabochon
	var hub := MeshInstance3D.new()
	var hc := CylinderMesh.new()
	hc.top_radius = 0.1
	hc.bottom_radius = 0.1
	hc.height = 0.12
	hc.radial_segments = 14
	hub.mesh = hc
	hub.material_override = brass
	wheel.add_child(hub)
	var cap := MeshInstance3D.new()
	var sc := SphereMesh.new()
	sc.radius = 0.055
	sc.height = 0.11
	sc.radial_segments = 10
	sc.rings = 5
	cap.mesh = sc
	cap.material_override = brass
	cap.position = Vector3(0.0, 0.07, 0.0)
	wheel.add_child(cap)
	_helm_wheel = wheel


static var _canvas_tex: ImageTexture
const SAIL_MATS := ["sail", "sail_d", "sail_p", "sail_e"]


## Lot 3 (3.5) : une toile crédible sur les voiles (elles étaient unies, en panneaux de deux teintes). Les voiles du modèle n'ont
## pas de coordonnées de texture : la toile est projetée (« triplanaire ») dans le repère du modèle. La texture est presque
## blanche : la couleur de la matière (et celle d'un skin de voilerie) la teinte. Posée une fois sur les matières partagées.
func _dress_sails(node: Node) -> void:
	var mats := {}
	_collect_sail_mats(node, mats)
	var base: StandardMaterial3D = mats.get("sail")
	for key: String in mats:
		var m: StandardMaterial3D = mats[key]
		if m.albedo_texture != null:
			continue   # (matière partagée : déjà habillée par un autre bateau)
		# 12/11 : les voiles du modèle ont des coordonnées de texture : une toile entière par voile (lés, ralingue, garcettes),
		# et l'emblème peint sur la grand-voile ; plus de projection « triplanaire » ni de damier
		m.albedo_texture = emblem_sail_texture() if key == "sail_e" else canvas_texture()
		m.uv1_triplanar = false
		m.uv1_scale = Vector3.ONE
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		m.cull_mode = BaseMaterial3D.CULL_DISABLED   # (toile vue des deux côtés)
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		if base != null and key != "sail" and key != "sail_e":
			m.albedo_color = base.albedo_color * (GameConfig.SAIL_PANEL_DARK if key == "sail_d" else GameConfig.SAIL_PANEL_LIGHT)


## Le crâne du pavillon (un disque blanc dans le modèle) remplacé par une tête de mort dessinée, des deux côtés du pavillon.
func _dress_flag() -> void:
	var disc := _find(_model, "flag_skull") as Node3D
	if disc == null:
		return
	disc.visible = false
	for side in [-1.0, 1.0]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.8, 0.8)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_texture = emblem_texture(true)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		q.material_override = m
		disc.get_parent().add_child(q)
		q.position = disc.position + Vector3(0.0, 0.0, side * 0.03)
		q.rotation.y = 0.0 if side > 0 else PI


func _find(node: Node, node_name: String) -> Node:
	if String(node.name) == node_name:
		return node
	for c in node.get_children():
		var f := _find(c, node_name)
		if f != null:
			return f
	return null


func _collect_sail_mats(node: Node, out: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m != null and m.resource_name in SAIL_MATS:
				out[m.resource_name] = m
	for c in node.get_children():
		_collect_sail_mats(c, out)


## Une voile entière (12/11, la voile porte ses coordonnées de texture : u en largeur, v de la bordure basse (0) à la vergue (1)) :
## huit lés verticaux cousus, ralingue plus sombre sur le pourtour, une rangée de garcettes de ris, des renforts aux coins, la
## toile qui s'use et se salit vers le bas, un tissage fin. Valeurs proches du blanc : la couleur de la voile (ou du skin) la teinte.
static func canvas_image() -> Image:
	var w := 512
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13013
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.008
	noise.fractal_octaves = 4
	var panels := 8
	for y in h:
		var v := 1.0 - float(y) / float(h - 1)     # (l'image a y vers le bas ; la voile, v vers le haut)
		for x in w:
			var u := float(x) / float(w - 1)
			var c := 0.95
			c += 0.018 * (1.0 if (x + y) % 2 == 0 else -1.0)                 # tissage
			var stain := noise.get_noise_2d(float(x), float(y))
			c -= maxf(stain, 0.0) * 0.14 + (1.0 - v) * 0.07                 # usure, et la toile plus sale en bas
			var pu := u * panels
			var dseam := absf(pu - roundf(pu)) * float(w) / panels            # px jusqu'à la couture la plus proche
			if dseam < 1.6:
				c -= 0.16                                                     # couture
			elif dseam < 3.2:
				c -= 0.05                                                     # recouvrement des lés
			if dseam < 5.0 and dseam > 3.6 and y % 7 < 3:
				c -= 0.08                                                     # les points de couture
			var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v)) * float(w)
			if edge < 7.0:
				c -= 0.22 * (1.0 - edge / 7.0)                                # ralingue (la corde cousue au bord)
			if absf(v - 0.78) < 0.006:
				c -= 0.08                                                     # bande de ris
			if absf(v - 0.78) < 0.018 and fmod(u * 26.0, 1.0) < 0.12:
				c -= 0.3                                                      # les garcettes
			if (u < 0.08 or u > 0.92) and (v < 0.08 or v > 0.92):
				c -= 0.05                                                     # renforts aux coins
			c += rng.randf_range(-0.01, 0.01)
			img.set_pixel(x, y, Color(c, c * 0.985, c * 0.955))
	return img


static func canvas_texture() -> ImageTexture:
	if _canvas_tex != null:
		return _canvas_tex
	var img := canvas_image()
	img.generate_mipmaps()
	_canvas_tex = ImageTexture.create_from_image(img)
	return _canvas_tex


static var _emblem_sail_tex: ImageTexture
static var _emblem_tex: Dictionary = {}


## La grand-voile : la toile, et une tête de mort aux tibias croisés peinte dessus (couleur sombre : elle reste lisible sur toutes
## les teintes de voile, comme une peinture sur toile).
static func emblem_sail_texture() -> ImageTexture:
	if _emblem_sail_tex != null:
		return _emblem_sail_tex
	var img := canvas_image()
	_paint_emblem(img, Vector2(256, 236), 150.0, Color(0.13, 0.1, 0.1), false)
	img.generate_mipmaps()
	_emblem_sail_tex = ImageTexture.create_from_image(img)
	return _emblem_sail_tex


## Le pavillon : une tête de mort claire sur fond transparent (posée sur le tissu du pavillon).
static func emblem_texture(_on_flag: bool = true) -> ImageTexture:
	if _emblem_tex.has("flag"):
		return _emblem_tex["flag"]
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_paint_emblem(img, Vector2(128, 120), 92.0, Color(0.93, 0.9, 0.82), true)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_emblem_tex["flag"] = t
	return t


## Peint une tête de mort aux tibias croisés centrée en `c` (px), de taille `s` (largeur du crâne ≈ s). Orbites, nez et dents
## sont creusés (laissent voir la toile, ou transparents sur le pavillon). Bords adoucis.
static func _paint_emblem(img: Image, c: Vector2, s: float, col: Color, transparent_holes: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := maxi(int(c.x - s * 1.3), 0)
	var x1 := mini(int(c.x + s * 1.3), w - 1)
	var y0 := maxi(int(c.y - s * 0.8), 0)
	var y1 := mini(int(c.y + s * 1.4), h - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := (Vector2(x, y) - c) / s   # repère du dessin : crâne de rayon ~0,5, y vers le bas
			var ink := 0.0
			# les tibias croisés, derrière le crâne : deux os en X avec leurs extrémités bosselées
			for sgn: float in [-1.0, 1.0]:
				var dir := Vector2(1.0, sgn * 0.62).normalized()
				var q := p - Vector2(0.0, 0.62)
				var along := q.dot(dir)
				var across := absf(q.dot(Vector2(-dir.y, dir.x)))
				if absf(along) < 1.0:
					ink = maxf(ink, 1.0 - smoothstep(0.06, 0.09, across))
				for e in [-1.0, 1.0]:
					var knob: Vector2 = dir * float(e) * 1.02
					for o in [-1.0, 1.0]:
						var kp: Vector2 = knob + Vector2(-dir.y, dir.x) * float(o) * 0.07
						ink = maxf(ink, 1.0 - smoothstep(0.09, 0.12, q.distance_to(kp)))
			# le crâne : une calotte ronde et une mâchoire plus étroite
			var head := Vector2(p.x / 0.5, (p.y + 0.05) / 0.46).length()
			var jaw := absf(p.x) < 0.27 and p.y > 0.25 and p.y < 0.52
			var skull := 1.0 - smoothstep(0.96, 1.04, head)
			if jaw:
				skull = 1.0
			# orbites, nez, dents : creusés
			var hole := 0.0
			for e in [-1.0, 1.0]:
				hole = maxf(hole, 1.0 - smoothstep(0.11, 0.14, Vector2((p.x - e * 0.19) / 1.1, p.y - 0.02).length()))
			if p.y > 0.13 and p.y < 0.27 and absf(p.x) < (p.y - 0.13) * 0.55:
				hole = 1.0
			if p.y > 0.36 and p.y < 0.47 and fmod(absf(p.x) + 0.03, 0.09) < 0.025:
				hole = maxf(hole, 0.8)
			skull = maxf(0.0, skull - hole)
			var a := maxf(ink * (1.0 - skull * 0.0), skull)
			if skull > 0.0 and hole > 0.0 and transparent_holes:
				a = skull
			if a <= 0.0:
				continue
			var base := img.get_pixel(x, y)
			if transparent_holes:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, maxf(base.a, a)))
			else:
				img.set_pixel(x, y, base.lerp(Color(col.r * base.r, col.g * base.g, col.b * base.b), a * 0.92))


## Une base dont l'axe Y pointe vers `dir` (pour coucher un cylindre ou une capsule le long d'un rayon).
static func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := Vector3.UP.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func _mat(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## Tourne la roue selon la barre (-1 bâbord … 1 tribord) : GameConfig.HELM_WHEEL_TURNS tours d'une butée à l'autre.
func set_helm(rudder_pos: float) -> void:
	if _helm_wheel != null:
		_helm_wheel.transform = _helm_base * Transform3D(Basis(Vector3.UP, rudder_pos * GameConfig.HELM_WHEEL_TURNS * PI), Vector3.ZERO)


## Lot 3 (3.4) : retouches de disposition par bateau (data/ship_layout.json), appliquées par-dessus le fichier du modèle
## (assets/models/ship/*_meta.json, que tools/art/blender/make_ship.py régénère). `cannon_x` : nouvelle abscisse de chaque canon
## (même ordre que dans le fichier du modèle ; null : inchangé). La demi-largeur de la coque n'est pas la même partout : le canon
## garde sa distance au plat-bord.
func _apply_layout_overrides(p_name: String) -> void:
	var f := FileAccess.open("res://data/ship_layout.json", FileAccess.READ)
	if f == null:
		return
	var all: Variant = JSON.parse_string(f.get_as_text())
	if not (all is Dictionary) or not (all as Dictionary).has(p_name):
		return
	var o: Dictionary = all[p_name]
	var xs: Array = o.get("cannon_x", [])
	var out: Array = []
	for i in cannons.size():
		var c: Array = (cannons[i] as Array).duplicate()
		if i < xs.size() and xs[i] != null:
			var inset := half_width(float(c[0])) - absf(float(c[1]))
			c[0] = float(xs[i])
			c[1] = signf(float(c[1])) * (half_width(float(c[0])) - inset)
		out.append(c)
	cannons = out


## Quels obstacles du pont un saut peut enjamber : tout ce qui n'est pas un mur de cabine ni un mât.
func _compute_low_obstacles() -> void:
	low_boxes.clear()
	low_circles.clear()
	for i in boxes.size():
		var b: Array = boxes[i]
		# un mur de cabine ou un château d'étrave est trop haut ; une caisse (moins de 1,1 m de côté) s'enjambe
		var tall := float(b[2]) - float(b[0]) > 1.1 or float(b[3]) - float(b[1]) > 1.1
		if not cabin.is_empty():
			tall = tall or (float(b[2]) > float(cabin["x0"]) - 0.3 and float(b[0]) < float(cabin["x1"]) + 0.3 \
					and float(b[3]) > float(cabin["y0"]) - 0.3 and float(b[1]) < float(cabin["y1"]) + 0.3)
		# la pile de caisses du pont (sur le sloop elle touche la cabine) reste une caisse : on la saute
		if crate_pos != Vector2.INF and Vector2((float(b[0]) + float(b[2])) * 0.5, (float(b[1]) + float(b[3])) * 0.5).distance_to(crate_pos) < 0.35:
			tall = false
		if not tall:
			low_boxes.append(i)
	for i in circles.size():
		var c: Array = circles[i]
		var is_mast := false
		for m: Array in masts:
			if absf(float(c[0]) - float(m[0])) < 0.06 and absf(float(c[1])) < 0.06:
				is_mast = true
		if not is_mast:
			low_circles.append(i)


func _index_nodes(node: Node) -> void:
	var s := String(node.name)
	if node is Node3D:
		var n3 := node as Node3D
		if s == "cannon" or s.begins_with("cannon_"):
			cannon_stubs.append(n3)
			n3.visible = false
		if s == "helm" and node is MeshInstance3D:
			_helm_disc = n3   # le disque plat du modèle : remplacé par une vraie roue (voir _build_helm_wheel)
		if s == "crate":
			# la pile de caisses du pont : c'est elle qui devient la caisse de provisions (voir crate_pos)
			crate_pos = Vector2(n3.position.x - shift, -n3.position.z)
		if s == "int_chest":
			# le coffre de la cabine : le coffre du capitaine, où l'équipage dépose les trésors
			stash_pos = Vector2(n3.position.x - shift, -n3.position.z)
		if s.begins_with("sail_z"):
			var digits := s.substr(6)
			var top := float(digits.to_int()) / 100.0
			_sails.append({"node": n3, "top": top, "base": n3.transform, "alpha": 1.0})
		elif s.begins_with("cut_"):
			var info := {"node": n3, "normal": Vector2.ZERO, "always": true}
			if s.begins_with("cut_wall_") or s.begins_with("cut_win_"):
				var tag := s.substr(9 if s.begins_with("cut_wall_") else 8, 1)
				var normals := {"w": Vector2(-1, 0), "e": Vector2(1, 0), "n": Vector2(0, 1), "s": Vector2(0, -1)}
				if normals.has(tag):
					info["normal"] = normals[tag]
					info["always"] = false
			_cuts.append(info)
	for child in node.get_children():
		_index_nodes(child)


## Position dans le repère local de la scène (mètres de jeu) d'un point du pont.
func to_local3(bp: Vector2, height_offset: float = 0.0) -> Vector3:
	return Vector3((bp.x + shift) * SCALE, deck_height(bp.x) + height_offset, -bp.y * SCALE)


## Demi-largeur de la coque (unités du modèle) à l'abscisse bx.
func half_width(bx: float) -> float:
	var u := (bx + length * 0.5) / length
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return beam * 0.5 * (0.90 + 0.10 * minf(1.0, u * 3.0)) * (1.0 - 0.96 * pow(u, 2.4))


## Hauteur du pont (mètres de jeu) à l'abscisse bx.
func deck_height(bx: float) -> float:
	var u := clampf((bx + length * 0.5) / length, 0.0, 1.0)
	# (12/11 : `sheer` vient de la méta du modèle ; le brigantin v2 a une tonture exagérée, 1,7)
	return (0.62 * pow(u, 2.2) + 0.34 * pow(1.0 - u, 2.5)) * (length / 13.0) * SCALE * sheer


## Vrai si le point est dans la cabine (porte comprise).
func inside_cabin(bp: Vector2) -> bool:
	if cabin.is_empty():
		return false
	return bp.x > float(cabin["x0"]) and bp.x < float(cabin["door_x"]) \
			and bp.y > float(cabin["y0"]) and bp.y < float(cabin["y1"])


## Vrai si un personnage de rayon WALK_RADIUS peut se tenir en bp. On peut aller jusqu'à la pointe de
## l'étrave : le long du plat-bord la marge est de 0,5, mais jamais moins de MIN_LANE de part et d'autre
## de l'axe, pour que le passage vers l'avant reste ouvert.
func is_walkable(bp: Vector2) -> bool:
	var r := WALK_RADIUS
	var u := (bp.x + length * 0.5) / length
	if u < 0.03 or bp.x > bow_x:
		return false
	# (12/11 : le couloir minimal MIN_LANE laissait marcher plus loin que la coque à la pointe de l'étrave : le pirate
	# s'affichait au-dessus de l'eau. Il ne dépasse plus jamais le plat-bord, et la pointe trop étroite n'est plus praticable.)
	var hw := half_width(bp.x)
	var lane := maxf(hw - RAIL_MARGIN, minf(MIN_LANE, hw - 0.3))
	if not inside_cabin(bp) and (absf(bp.y) > lane or lane < 0.15):
		return false
	for b: Array in boxes:
		if bp.x > float(b[0]) - r and bp.x < float(b[2]) + r and bp.y > float(b[1]) - r and bp.y < float(b[3]) + r:
			return false
	for c: Array in circles:
		if bp.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]) + r:
			return false
	return true


## Déplace `from` de `delta` en glissant le long des obstacles. Un pirate déjà coincé dans un obstacle
## (au sortir de la barre, par exemple) peut toujours en sortir.
func move_with_slide(from: Vector2, delta: Vector2) -> Vector2:
	var target := from + delta
	if is_walkable(target):
		return target
	var try_x := Vector2(from.x + delta.x, from.y)
	if is_walkable(try_x):
		return try_x
	var try_y := Vector2(from.x, from.y + delta.y)
	if is_walkable(try_y):
		return try_y
	if not is_walkable(from):
		return target
	# glisser autour d'un obstacle rond (mât, barre, tonneau) ou d'un coin : le pas tourné de plus en plus, en gardant ce
	# qu'il a d'utile (projection sur la direction voulue). Sans cela, en diagonale contre un rond, on restait bloqué.
	for deg: float in [25.0, 50.0, 75.0]:
		for sgn: float in [1.0, -1.0]:
			var rot := delta.rotated(deg_to_rad(deg) * sgn) * cos(deg_to_rad(deg))
			if is_walkable(from + rot):
				return from + rot
	return from


## Vrai si un pirate sauté à la hauteur `h` (m au-dessus du pont) peut se trouver en bp : en dessous du plat-bord c'est
## la marche normale ; au-dessus, il passe par-dessus le bastingage (et sort du bateau), enjambe les caisses, le tonneau
## et la roue, mais pas les murs de la cabine ni les mâts.
func is_walkable_air(bp: Vector2, h: float) -> bool:
	if h < RAIL_HEIGHT:
		return is_walkable(bp) or not over_hull(bp)   # en bas : le pont, ou déjà au-dessus de l'eau
	var r := WALK_RADIUS
	for i in boxes.size():
		if h >= LOW_CLEAR and i in low_boxes:
			continue
		var b: Array = boxes[i]
		if bp.x > float(b[0]) - r and bp.x < float(b[2]) + r and bp.y > float(b[1]) - r and bp.y < float(b[3]) + r:
			return false
	for i in circles.size():
		if h >= LOW_CLEAR and i in low_circles:
			continue
		var c: Array = circles[i]
		if bp.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]) + r:
			return false
	return true


## Comme move_with_slide, mais en l'air (voir is_walkable_air).
func move_air(from: Vector2, delta: Vector2, h: float) -> Vector2:
	var target := from + delta
	if is_walkable_air(target, h):
		return target
	var try_x := Vector2(from.x + delta.x, from.y)
	if is_walkable_air(try_x, h):
		return try_x
	var try_y := Vector2(from.x, from.y + delta.y)
	if is_walkable_air(try_y, h):
		return try_y
	return from


## Vrai si le point est au-dessus de la coque (pont, plat-bord compris) et pas au-dessus de l'eau.
## Tout point où l'on peut marcher compte comme coque : vers l'étrave, la coque est plus étroite que le couloir de
## marche (MIN_LANE), et sans cela le pirate qui marche jusqu'à la pointe tombait à l'eau sans avoir sauté.
func over_hull(bp: Vector2) -> bool:
	var u := (bp.x + length * 0.5) / length
	if u > 0.0 and u < 1.0 and absf(bp.y) <= half_width(bp.x):
		return true
	return is_walkable(bp)


## Où retombe un pirate qui touche le pont en bp : le point lui-même s'il est libre, le point libre voisin s'il
## est sur la coque (une caisse, le plat-bord), Vector2.INF s'il est au-dessus de l'eau.
## `from_cabin` : le saut est parti de l'intérieur de la cabine. Bug 1.7 : on ne se pose plus jamais de l'autre côté d'un mur.
## Avant, un saut qui retombait sur la bande étroite entre la cabine et le plat-bord était « recalé » au point libre le plus proche…
## souvent dans la cabine, à travers son mur ; et un saut depuis le quai qui retombait au-dessus du toit de la cabine y entrait.
func landing_spot(bp: Vector2, from_cabin: bool = false) -> Vector2:
	if is_walkable(bp) and inside_cabin(bp) == from_cabin:
		return bp
	if over_hull(bp):
		var q := nearest_reachable(bp, 1.6, from_cabin)
		if q != Vector2.INF:
			return q
	return Vector2.INF


## Le point libre le plus proche de bp qu'on atteint en ligne droite sans traverser de mur (cabine, mât…), du même côté des murs
## de la cabine que `in_cabin` ; Vector2.INF si aucun à moins de max_dist.
func nearest_reachable(bp: Vector2, max_dist: float, in_cabin: bool) -> Vector2:
	var d := 0.0
	while d <= max_dist:
		for k in (1 if d == 0.0 else 24):
			var q := bp + Vector2.from_angle(TAU * k / 24.0) * d
			if is_walkable(q) and inside_cabin(q) == in_cabin and _clear_line(bp, q):
				return q
		d += 0.1
	return Vector2.INF


## Vrai si le segment a → b ne traverse aucun mur (boîte haute, mât). Les caisses basses s'enjambent : elles ne comptent pas, ni
## l'obstacle sur lequel on retombe (a est dedans : on en descend).
func _clear_line(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(int(ceil(a.distance_to(b) / 0.04)), 1)
	for s in steps + 1:
		var p := a.lerp(b, float(s) / float(steps))
		for i in boxes.size():
			if i in low_boxes:
				continue
			var bx: Array = boxes[i]
			if _in_box(p, bx) and not _in_box(a, bx):
				return false
		for i in circles.size():
			if i in low_circles:
				continue
			var c: Array = circles[i]
			var cc := Vector2(float(c[0]), float(c[1]))
			if p.distance_to(cc) < float(c[2]) and a.distance_to(cc) >= float(c[2]):
				return false
	return true


static func _in_box(p: Vector2, bx: Array) -> bool:
	return p.x > float(bx[0]) and p.x < float(bx[2]) and p.y > float(bx[1]) and p.y < float(bx[3])


## Le point juste à l'extérieur de la coque, à côté de bp (là où tombe à l'eau un saut qui ne peut se poser nulle part).
func outside_point(bp: Vector2) -> Vector2:
	var side := 1.0 if bp.y >= 0.0 else -1.0
	return Vector2(bp.x, side * (half_width(bp.x) + GameConfig.HULL_OUTSIDE_MARGIN))


## Le point libre le plus proche de bp (recherche en spirale), ou bp si rien à moins de max_dist.
func nearest_walkable(bp: Vector2, max_dist: float = 3.0) -> Vector2:
	if is_walkable(bp):
		return bp
	var d := 0.1
	while d <= max_dist:
		for k in 24:
			var q := bp + Vector2.from_angle(TAU * k / 24.0) * d
			if is_walkable(q):
				return q
		d += 0.1
	return bp


## Vrai si le point monde `p` (x/z) est au-dessus de cette coque quand le bateau est en `sim_pos` avec le cap `yaw`
## (même repère que hull_points_world : sert aux collisions entre bateaux).
func contains_world(sim_pos: Vector2, yaw: float, p: Vector2) -> bool:
	var rel := p - sim_pos
	var local := Basis(Vector3.UP, -yaw) * Vector3(rel.x, 0.0, rel.y)
	return over_hull(Vector2(local.x / SCALE - shift, -local.z / SCALE))


## Les points de la coque (repère monde, x/z) pour tester la rencontre avec la terre : le contour,
## du cul à l'étrave, aux deux bords.
func hull_points_world(sim_pos: Vector2, yaw: float) -> Array:
	var pts: Array = []
	var fwd := Vector2(cos(yaw), -sin(yaw))
	var left := Vector2(-fwd.y, fwd.x) * -1.0    # vers bâbord, en x/z
	for i in 9:
		var bx := -length * 0.5 + length * (float(i) / 8.0)
		var hw := half_width(bx) * SCALE
		var center := sim_pos + fwd * ((bx + shift) * SCALE)
		pts.append(center + left * hw)
		pts.append(center - left * hw)
		if i == 8:
			pts.append(center)
	return pts


## Masque les voiles dont le haut dépasse `z` (unités du modèle) : vu d'en haut, elles cachent le pirate
## perché dans le nid de pie. Passer une valeur très grande les remet toutes.
func hide_sails_above(z: float) -> void:
	for entry: Dictionary in _sails:
		(entry["node"] as Node3D).visible = float(entry["top"]) <= z


## Règle l'ouverture visuelle des voiles (0..1) : elles se resserrent vers leur vergue.
func set_sail_open(open: float) -> void:
	_sail_open_v = open
	_apply_sails()


## Oriente les vergues (angle en radian, dans le sens de Vector2.rotated : 0 = perpendiculaires à la coque) : chaque
## voile carrée pivote autour de son mât. Les voiles de pointe (foc, artimon) ne bougent pas.
func set_sail_trim(angle: float) -> void:
	if is_equal_approx(angle, _sail_trim_v):
		return
	_sail_trim_v = angle
	_apply_sails()


var _fill := 1.0                ## 0…1 : les voiles prennent-elles le vent ? (lissé) — leur creux en dépend
var _luff := 0.0                ## 0…1 : force du battement (voiles hissées que le vent prend mal)
var _wind_t := 0.0


## Le vent dans les voiles (chaque image) : `fill` 0…1 (rendement du vent et du réglage), `luff` 0…1 (battement). Les voiles
## carrées se creusent quand elles prennent le vent et s'aplatissent en battant quand il les prend mal.
func set_sail_wind(fill: float, luff: float, delta: float) -> void:
	_fill = move_toward(_fill, fill, delta / GameConfig.SAIL_FILL_SMOOTH)
	_luff = move_toward(_luff, luff, delta * 2.0)
	_wind_t += delta
	_apply_sails()


func _apply_sails() -> void:
	var s := maxf(0.1, _sail_open_v)
	var m_scale := Basis.from_scale(Vector3(1.0, s, 1.0))
	for k in _sails.size():
		var entry: Dictionary = _sails[k]
		var top: float = entry["top"]
		var m := Transform3D(m_scale, Vector3(0.0, top * (1.0 - s), 0.0))
		var pivot: float = _sail_pivot[k]
		if not is_nan(pivot):
			# le creux de la voile (son bombement, vers l'étrave) autour de l'axe du mât : gonflée ou flasque, et qui bat
			var bulge := lerpf(GameConfig.SAIL_BULGE_SLACK, GameConfig.SAIL_BULGE_FULL, _fill)
			bulge += _luff * GameConfig.SAIL_LUFF_FLAP * sin(_wind_t * 17.0 + float(k) * 1.7) * (1.0 + 0.5 * sin(_wind_t * 5.3))
			m = Transform3D(Basis(), Vector3(pivot, 0.0, 0.0)) * Transform3D(Basis.from_scale(Vector3(maxf(bulge, 0.05), 1.0, 1.0)), Vector3.ZERO) \
					* Transform3D(Basis(), Vector3(-pivot, 0.0, 0.0)) * m
		var t := m * (entry["base"] as Transform3D)
		if not is_nan(pivot) and absf(_sail_trim_v) > 0.0001:
			# autour de l'axe vertical du mât (repère du modèle) ; Vector2.rotated(a) = rotation d'axe Y de -a
			var rot := Transform3D(Basis(Vector3.UP, -_sail_trim_v), Vector3.ZERO)
			t = Transform3D(Basis(), Vector3(pivot, 0.0, 0.0)) * rot * Transform3D(Basis(), Vector3(-pivot, 0.0, 0.0)) * t
		(entry["node"] as Node3D).transform = t


## Cherche pour chaque voile le mât qui la porte (le plus proche de son centre) : l'abscisse du pivot, NAN pour les
## voiles qui ne pivotent pas (foc, artimon, ornements loin des mâts).
func _compute_sail_pivots() -> void:
	_sail_pivot.clear()
	for entry: Dictionary in _sails:
		var node := entry["node"] as Node3D
		var pivot := NAN
		var lname := String(node.name)
		if node is MeshInstance3D and not lname.contains("jib") and not lname.contains("spanker"):
			var mi := node as MeshInstance3D
			var center: Vector3 = (entry["base"] as Transform3D) * mi.get_aabb().get_center()
			var best := 1.6
			for m: Array in masts:
				var mx := float(m[0]) + shift
				if absf(mx - center.x) < best:
					best = absf(mx - center.x)
					pivot = mx
		_sail_pivot.append(pivot)


## Les voiles que l'on voit à travers : celles que le rayon du pirate vers la caméra traverse deviennent transparentes
## (même idée que les bâtiments du port), les autres restent pleines. `origin` : la tête du pirate ; `to_cam` : direction
## vers la caméra ; `active` faux : tout redevient plein.
func update_sail_fade(origin: Vector3, to_cam: Vector3, active: bool, delta: float, target_alpha: float = 0.3) -> void:
	for entry: Dictionary in _sails:
		var node := entry["node"] as Node3D
		if not (node is MeshInstance3D):
			continue
		var mi := node as MeshInstance3D
		var want := 1.0
		if active and mi.visible and mi.mesh != null:
			var box := (mi.global_transform * mi.get_aabb()).grow(0.45)
			if box.intersects_ray(origin, to_cam) != null:
				want = target_alpha
		var a: float = entry["alpha"]
		if is_equal_approx(a, want):
			continue
		a = move_toward(a, want, delta * 4.0)
		entry["alpha"] = a
		mi.transparency = 0.0 if a > 0.995 else 1.0 - a


## Masque le toit et les murs tournés vers la caméra quand le joueur est dans la cabine.
## La caméra regarde vers -z : un mur dont la normale (en monde) a une composante +z est de son côté.
## 12/11 : un mur côté caméra n'est plus masqué en entier, il est rabattu en muret (GameConfig.CABIN_STUB_WALL) : on voit
## toujours le contour de la pièce et l'ouverture de la porte, donc où sortir (comme les murs « coupés » des jeux vus de dessus).
func update_cutaway(player_inside: bool) -> void:
	var basis := global_transform.basis
	for entry: Dictionary in _cuts:
		var node: Node3D = entry["node"]
		if not entry.has("base"):
			entry["base"] = node.transform
		var base: Transform3D = entry["base"]
		node.transform = base
		if not player_inside:
			node.visible = true
			continue
		if entry["always"]:
			node.visible = false
			continue
		var n: Vector2 = entry["normal"]
		var world_normal := basis * Vector3(n.x, 0.0, -n.y)
		if world_normal.z <= 0.1:
			node.visible = true   # mur du fond : entier
			continue
		var is_wall := String(node.name).begins_with("cut_wall_")
		var box := _parent_aabb(node, base)
		if not is_wall or box.size.y <= 0.0 or box.position.y > float(cabin.get("floor_z", 0.0)) + 0.3:
			node.visible = false   # fenêtres, linteau au-dessus de la porte : masqués
			continue
		node.visible = true
		var k := clampf(GameConfig.CABIN_STUB_WALL / box.size.y, 0.02, 1.0)
		var bottom := box.position.y
		node.transform = Transform3D(Basis(), Vector3(0.0, bottom, 0.0)) * Transform3D(Basis.from_scale(Vector3(1.0, k, 1.0)), Vector3.ZERO) \
				* Transform3D(Basis(), Vector3(0.0, -bottom, 0.0)) * base


## Boîte englobante d'un mur dans le repère de son parent (unités du modèle).
func _parent_aabb(node: Node3D, base: Transform3D) -> AABB:
	if node is MeshInstance3D:
		return base * (node as MeshInstance3D).get_aabb()
	return AABB()


## Écoutille du pont (unités du modèle), qui mène à la cale. Le sloop n'en a pas dans son modèle : on en
## pose une à l'exécution (voir sailing_game.gd).
func hatch_pos() -> Vector2:
	return Vector2(1.6 if length > 11.0 else 1.2, 0.0)


## Beaucoup de points de la coque (repère monde, x/z), cinq par station : sert à toucher un récif plus petit
## que l'écart entre deux points du contour.
func hull_points_dense(sim_pos: Vector2, yaw: float) -> Array:
	var pts: Array = []
	var fwd := Vector2(cos(yaw), -sin(yaw))
	var left := Vector2(-fwd.y, fwd.x) * -1.0
	for i in 17:
		var bx := -length * 0.5 + length * (float(i) / 16.0)
		var hw := half_width(bx) * SCALE
		var center := sim_pos + fwd * ((bx + shift) * SCALE)
		for k in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			pts.append(center + left * hw * k)
	return pts


## Où une partie de la coque touche : à partir de la liste de `hull_points_dense` et de l'indice du point
## touché, renvoie {bx, side} (abscisse dans le repère du modèle, +1 bâbord / -1 tribord).
func dense_hit_info(index: int) -> Dictionary:
	var station := floori(index / 5.0)
	var k := index % 5
	var bx := -length * 0.5 + length * (float(station) / 16.0)
	var side := -1 if k < 2 else (1 if k > 2 else 0)
	return {"bx": bx, "side": side}


## Où la coque touche : à partir de l'indice d'un point de `hull_points_world`, renvoie {bx, side}
## (abscisse dans le repère du modèle, +1 bâbord / -1 tribord).
func contour_hit_info(index: int) -> Dictionary:
	var station := mini(floori(index / 2.0), 8)
	return {"bx": -length * 0.5 + length * (float(station) / 8.0), "side": 1 if index % 2 == 0 else -1}
