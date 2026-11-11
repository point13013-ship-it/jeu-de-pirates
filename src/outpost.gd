class_name Outpost
extends RefCounted
## Capture d'île et cabane. Une île dont on a battu tous les ennemis et ouvert tous les coffres montre un drapeau blanc ;
## on le hisse (E) et l'île est capturée : plus rien n'y revient (ennemis, coffres), le drapeau devient noir. Sur une île
## capturée on peut fabriquer une cabane (data/crafting.json, « cabin ») dont le coffre, partagé par tous les joueurs, garde
## ce qu'on veut (trésors, baies, planches, boulets, munitions, or). L'état vit dans le profil de l'hôte (captured, cabins) et
## est recopié chez les autres joueurs ; cette classe ne contient que la logique, testable sans scène, et la fabrique des
## deux petits modèles 3D.

const FLAG_REACH := 2.2        ## m : portée pour hisser le drapeau
const CABIN_REACH := 2.7       ## m (du centre de la cabane) : portée pour ouvrir son coffre
const CABIN_HALF := 1.35       ## m : demi-côté de l'emprise de la cabane (elle bloque le passage)
const CAPTURE_GOLD := 80       ## or offert par crâne de danger quand on capture une île


# ------------------------------------------------------------------ état (profil)

static func is_captured(profile: Profile, id: String) -> bool:
	return profile.captured.has(id)


## Capture l'île `id` ; faux si elle l'était déjà.
static func capture(profile: Profile, id: String) -> bool:
	if profile.captured.has(id):
		return false
	profile.captured.append(id)
	profile.save()
	return true


static func has_cabin(profile: Profile, id: String) -> bool:
	return profile.cabins.has(id)


## Position monde (x, z) de la cabane de l'île `id`, ou Vector2.INF.
static func cabin_pos(profile: Profile, id: String) -> Vector2:
	if not profile.cabins.has(id):
		return Vector2.INF
	var at: Array = (profile.cabins[id] as Dictionary).get("at", [])
	if at.size() < 2:
		return Vector2.INF
	return Vector2(float(at[0]), float(at[1]))


static func build_cabin(profile: Profile, id: String, at: Vector2) -> void:
	profile.cabins[id] = {"at": [at.x, at.y], "items": {}}
	profile.save()


# ------------------------------------------------------------------ le coffre partagé
# Il garde de tout : trésors (« t:calice »), baies (« b:… »), « plank », « ball », « bullets », « shells » et « gold ».
# Le contenu est un dictionnaire { objet: quantité }. L'hôte en est le maître (voir SailingGame.apply_cabin).

const SUPPLY_KINDS := ["plank", "ball", "bullets", "shells", "gold"]
const SUPPLY_NAMES := {"plank": "Planches", "ball": "Boulets", "bullets": "Balles", "shells": "Cartouches", "gold": "Or"}
## Combien on range ou reprend d'un coup (les trésors et les baies : un par un).
const SUPPLY_STEP := {"plank": 5, "ball": 5, "bullets": 6, "shells": 3, "gold": 100}


static func valid_kind(kind: String) -> bool:
	if kind.begins_with("t:"):
		return Treasure.exists(kind.substr(2))
	if kind.begins_with("b:"):
		return BerryBook.exists(kind.substr(2))
	return kind in SUPPLY_KINDS


static func step_of(kind: String) -> int:
	return int(SUPPLY_STEP.get(kind, 1))


static func kind_name(kind: String) -> String:
	if kind.begins_with("t:"):
		return Treasure.name_of(kind.substr(2))
	if kind.begins_with("b:"):
		return BerryBook.berry_name(kind.substr(2))
	return str(SUPPLY_NAMES.get(kind, kind))


## Le contenu du coffre de l'île `id` : { objet: quantité } (une copie).
static func items_of(profile: Profile, id: String) -> Dictionary:
	if not profile.cabins.has(id):
		return {}
	var it: Variant = (profile.cabins[id] as Dictionary).get("items", {})
	return (it as Dictionary).duplicate() if it is Dictionary else {}


static func count_of(profile: Profile, id: String, kind: String) -> int:
	return int(items_of(profile, id).get(kind, 0))


## Range `n` de `kind` ; renvoie combien ont été rangés (0 : pas de cabane, objet inconnu ou n <= 0).
static func deposit(profile: Profile, id: String, kind: String, n: int) -> int:
	if n <= 0 or not profile.cabins.has(id) or not valid_kind(kind):
		return 0
	var items := items_of(profile, id)
	items[kind] = int(items.get(kind, 0)) + n
	(profile.cabins[id] as Dictionary)["items"] = items
	profile.save()
	return n


## Reprend jusqu'à `n` de `kind` ; renvoie combien sont sortis du coffre (0 s'il n'y en a pas).
static func withdraw(profile: Profile, id: String, kind: String, n: int) -> int:
	var items := items_of(profile, id)
	var got := mini(n, int(items.get(kind, 0)))
	if got <= 0:
		return 0
	var left := int(items[kind]) - got
	if left <= 0:
		items.erase(kind)
	else:
		items[kind] = left
	(profile.cabins[id] as Dictionary)["items"] = items
	profile.save()
	return got


## Une phrase : « Coffre de la cabane : 3 trésor(s), 40 planche(s), 200 or… » ou « vide ».
static func stash_text(profile: Profile, id: String) -> String:
	var items := items_of(profile, id)
	if items.is_empty():
		return "Coffre de la cabane : vide"
	var kinds: Array = items.keys()
	kinds.sort()
	var parts: Array = []
	for k: String in kinds:
		parts.append("%d %s" % [int(items[k]), kind_name(k)])
	return "Coffre de la cabane : " + ", ".join(parts)


## L'état à envoyer aux autres joueurs (îles capturées et cabanes avec leur contenu), et sa lecture chez eux.
static func export_state(profile: Profile) -> Dictionary:
	return {"captured": profile.captured.duplicate(), "cabins": profile.cabins.duplicate(true)}


static func import_state(profile: Profile, d: Dictionary) -> void:
	var cp: Variant = d.get("captured", [])
	profile.captured = (cp as Array).duplicate() if cp is Array else []
	var cb: Variant = d.get("cabins", {})
	profile.cabins = (cb as Dictionary).duplicate(true) if cb is Dictionary else {}


## Récompense en or pour la capture de l'île `i`.
static func capture_reward(world: IslandWorld, i: int) -> int:
	return CAPTURE_GOLD * clampi(int((world.islands[i] as Dictionary).get("danger", 1)), 1, 3)


# ------------------------------------------------------------------ emplacements

## Un point de l'île `i` où poser un objet d'emprise `r` : au plus près de `near`, sur la terre ferme, plat, loin du
## décor, des coffres, des ennemis et des points de `avoid` ([point, distance] comme dans IslandWorld). Vector2.INF si rien.
static func find_spot(world: IslandWorld, i: int, near: Vector2, r: float, avoid: Array = []) -> Vector2:
	var isl: Dictionary = world.islands[i]
	var keep: Array = avoid.duplicate()
	for en_id: int in isl["enemies"]:
		keep.append([world.enemies[en_id].home, 2.0])
	for ch_id: int in isl["chests"]:
		keep.append([(world.chests[ch_id] as Dictionary)["pos"], 2.0])
	for it: Dictionary in isl["items"]:
		keep.append([it["pos"], 1.2])
	for b: Vector3 in isl["blockers_c"]:
		keep.append([Vector2(b.x, b.y), b.z])
	var d := 0.0
	while d <= float(isl["radius"]):
		var steps := 1 if d == 0.0 else maxi(8, int(d * 3.0))
		for k in steps:
			var p := near + Vector2.from_angle(TAU * float(k) / float(steps) + d * 0.7) * d
			if world.sdf(i, p) < r + 1.2:
				continue
			if not world.is_flat(i, p, r * 0.6):
				continue
			var ok := true
			for e: Array in keep:
				if p.distance_to(e[0]) < float(e[1]) + r:
					ok = false
					break
			if ok:
				return p
		d += 0.9
	return Vector2.INF


## Le drapeau de l'île `i` : un point libre le plus près du centre (calculé une fois).
static func flag_pos(world: IslandWorld, i: int) -> Vector2:
	var isl: Dictionary = world.islands[i]
	if not isl.has("flag"):
		var p := find_spot(world, i, isl["center"], 0.6)
		isl["flag"] = p if p != Vector2.INF else isl["center"]
	return isl["flag"]


## Une cabane près du drapeau de l'île `i` (ou, mieux, près de `near`), ou Vector2.INF s'il n'y a pas de place.
static func cabin_spot(world: IslandWorld, i: int, near: Vector2) -> Vector2:
	return find_spot(world, i, near, CABIN_HALF + 0.6, [[flag_pos(world, i), 1.5], [near, 2.0]])


## Île `i` où le drapeau est à portée de `p` (et qui est vaincue ou capturée) ; sinon -1.
static func flag_near(world: IslandWorld, profile: Profile, p: Vector2) -> int:
	var i := world.island_at(p, 2.0)
	if i < 0:
		return -1
	var id := str((world.islands[i] as Dictionary)["id"])
	if not (profile.captured.has(id) or world.is_cleared(i)):
		return -1
	return i if flag_pos(world, i).distance_to(p) <= FLAG_REACH else -1


## Île dont la cabane est à portée de `p`, ou -1.
static func cabin_near(world: IslandWorld, profile: Profile, p: Vector2) -> int:
	for id: String in profile.cabins:
		var at := cabin_pos(profile, id)
		if at != Vector2.INF and at.distance_to(p) <= CABIN_REACH:
			for i in world.islands.size():
				if str((world.islands[i] as Dictionary)["id"]) == id:
					return i
	return -1


# ------------------------------------------------------------------ modèles 3D

static func _xf(pos: Vector3, euler: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(euler), pos)


## Mât et drapeau : blanc (île vaincue, à hisser) ou noir à tête de mort (île capturée).
static func make_flag(parent: Node3D, at: Vector2, y: float, captured: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "OutpostFlag"
	root.position = Vector3(at.x, y, at.y)
	parent.add_child(root)
	var k := MeshKit.new()
	var wood := Color(0.34, 0.22, 0.12)
	k.box(_xf(Vector3(0, 0.12, 0)), Vector3(0.8, 0.24, 0.8), Color(0.5, 0.48, 0.46))
	k.between(Vector3(0, 0.2, 0), Vector3(0, 3.4, 0), 0.07, 0.05, wood)
	if captured:
		var white := Color(0.95, 0.93, 0.86)
		k.box(_xf(Vector3(0.65, 2.9, 0)), Vector3(1.2, 0.8, 0.03), Color(0.1, 0.1, 0.13))
		k.ball(_xf(Vector3(0.65, 2.98, 0.03)), 0.13, white, 6, 3)
		k.box(_xf(Vector3(0.65, 2.74, 0.03)), Vector3(0.44, 0.06, 0.02), white)
		k.box(_xf(Vector3(0.65, 2.74, 0.03), Vector3(0, 0, 0.6)), Vector3(0.44, 0.05, 0.02), white)
		k.box(_xf(Vector3(0.65, 2.74, 0.03), Vector3(0, 0, -0.6)), Vector3(0.44, 0.05, 0.02), white)
	else:
		k.box(_xf(Vector3(0.5, 2.0, 0)), Vector3(0.9, 0.55, 0.03), Color(0.96, 0.96, 0.92))   # drapeau blanc à mi-mât
	k.instance(root)
	return root


## La cabane : la petite hutte des îles, un fanion noir sur le toit et un coffre devant la porte (côté +z).
static func make_cabin(parent: Node3D, at: Vector2, y: float) -> Node3D:
	var root := Node3D.new()
	root.name = "OutpostCabin"
	root.position = Vector3(at.x, y, at.y)
	parent.add_child(root)
	IslandDecor.hut(root)
	var k := MeshKit.new()
	k.between(Vector3(0, 2.7, 0), Vector3(0, 3.6, 0), 0.04, 0.03, Color(0.34, 0.22, 0.12))
	k.box(_xf(Vector3(0.32, 3.4, 0)), Vector3(0.6, 0.35, 0.03), Color(0.1, 0.1, 0.13))
	k.ball(_xf(Vector3(0.32, 3.42, 0.03)), 0.07, Color(0.95, 0.93, 0.86), 6, 3)
	k.instance(root)
	IslandDecor.chest(root, Vector2(0.0, 2.0))
	return root
