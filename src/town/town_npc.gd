class_name TownNpc
extends RefCounted
## Un habitant de la ville : un pirate-sprite posé dans le monde. Les PNJ de boutique restent à leur place et
## regardent la rue ; les promeneurs suivent un chemin en boucle, avec une pause à chaque point.
## Positions en coordonnées du fichier du port (x, y) ; le monde de jeu est (x, -y).

var id := ""
var display_name := ""
var role := ""
var pos := Vector2.ZERO        ## position monde (x, z)
var h := 0.0                   ## hauteur du sol sous ses pieds
var lines: Array = []
var sprite: PirateSprite
var wanderer := false
var blob: MeshInstance3D       ## ombre ronde sous ses pieds
var interior := -1             ## indice de l intérieur où il se tient (-1 : dehors)
var tag: Label3D               ## son nom au-dessus de la tête (visible d'assez près)

var h_from := Vector2(1.0e9, 1.0e9)   ## où la hauteur du sol a été cherchée la dernière fois (le jeu ne la refait qu'après un pas)
var _path: Array[Vector2] = []
var _target := 1
var _speed := 1.0
var _pause := 2.0
var _wait := 0.0


## Crée le PNJ d'après une entrée de data/npcs.json (`walker` : un promeneur).
static func from_data(d: Dictionary, walker: bool) -> TownNpc:
	var n := TownNpc.new()
	n.id = str(d["id"])
	n.display_name = str(d.get("name", "Passant"))
	n.role = str(d.get("role", "passant"))
	n.lines = d.get("lines", [])
	n.wanderer = walker
	var look := PirateLook.random_look(int(d.get("seed", 1)))
	var parts: Dictionary = d.get("parts", {})
	for k: String in parts:
		look["parts"][k] = parts[k]
	n.sprite = PirateSprite.new()
	n.sprite.compass_enabled = false   # lot 8 (10.4) : plus de boussole dans la main des habitants (bras le long du corps)
	n.sprite.anims_only = ["idle", "walk"]   # 14/11 (fps) : un habitant ne porte, ne grimpe, ne saute jamais
	n.sprite.lazy_sheets = true              # ... et ses feuilles ne se fabriquent que s'il est assez près pour être vu
	n.sprite.set_look(look)
	n.tag = _make_tag(n.display_name, n.role)
	n.sprite.add_child(n.tag)
	if walker:
		for p: Array in d["path"]:
			n._path.append(Vector2(float(p[0]), -float(p[1])))
		n.pos = n._path[0]
		n._speed = float(d.get("speed", 1.0))
		n._pause = float(d.get("pause", 2.0))
		n._wait = float(int(d.get("seed", 1)) % 3)
	else:
		var p: Array = d["pos"]
		n.pos = Vector2(float(p[0]), -float(p[1]))
		n.h = float(d.get("h", 0.0))
		n.sprite.direction = int(d.get("facing", 0))
	return n


## Le nom d'un habitant au-dessus de sa tête (demande de Jimmy) : distinct de celui des joueurs (crème, gras) : plus petit, en
## italique doré pour les marchands et gens de métier, gris-bleu pour les passants, avec son métier en dessous.
static func _make_tag(display: String, p_role: String) -> Label3D:
	var l := Label3D.new()
	var trade := p_role != "passant" and p_role != "naufragé"
	var same := display.to_lower() == p_role.to_lower() or p_role == ""
	l.text = display if same else "%s\n— %s —" % [display, p_role]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 24
	l.pixel_size = 0.0065
	l.modulate = Color(1.0, 0.82, 0.42) if trade else Color(0.72, 0.82, 0.92)
	l.outline_size = 7
	l.outline_modulate = Color(0.12, 0.06, 0.02) if trade else Color(0.05, 0.07, 0.12)
	l.position = Vector3(0.0, 2.25, 0.0)
	l.no_depth_test = true
	l.render_priority = 6
	l.visible = false
	return l


## Fait avancer le promeneur ; renvoie le déplacement de cette image (monde x/z).
func update(delta: float) -> Vector2:
	if not wanderer or _path.size() < 2:
		return Vector2.ZERO
	if _wait > 0.0:
		_wait -= delta
		return Vector2.ZERO
	var to := _path[_target] - pos
	var step := _speed * delta
	if to.length() <= step:
		pos = _path[_target]
		_target = (_target + 1) % _path.size()
		_wait = _pause
		return to
	var move := to.normalized() * step
	pos += move
	return move
