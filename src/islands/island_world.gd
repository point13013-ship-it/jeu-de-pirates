class_name IslandWorld
extends RefCounted
## Les îles du monde : terre ferme (union de disques), relief des plages, décor, ennemis, coffres.
## Données : data/islands.json (îles) et data/enemies.json (ennemis, joueur). `setup()` ne fait que lire les
## données et calculer les positions (testable sans scène) ; `build()` pose le tout en 3D.
## Chez l'hôte (ou en solo) `step()` fait vivre les ennemis ; chez les autres, `apply_net()` copie son état.

const SLOPE := 2.6          ## m : largeur de la pente de plage, du bord de la terre à l'eau profonde
const DROP := 1.75          ## m : profondeur au pied de la pente
const SHALLOW_WIDTH := 8.0    ## m : largeur des eaux peu profondes autour de la terre
const SHALLOW_Y := -1.05     ## hauteur de la nappe (la mer est à -1,45, la houle monte à -1,1 au plus)
const GRID := 0.4           ## m entre deux sommets du maillage
const SHIP_MARGIN := 0.8    ## m : un bateau s'arrête à cette distance du bord de la terre marchable
const CHEST_REACH := 1.5    ## m : portée pour ouvrir un coffre
const BERRY_REACH := 1.6    ## m : portée pour cueillir une baie
const BERRY_REVEAL := 5.5   ## m : une baie cachée dans son buisson ne scintille qu'à cette distance
const BERRY_RESPAWN := 10800.0  ## s : une baie cueillie ne repousse qu'au bout de trois heures (c'est le plus rare des trésors)
const ISLANDS_PATH := "res://data/islands.json"
const ENEMIES_PATH := "res://data/enemies.json"
const ISLAND_SCALE := 2.0     ## les îles du fichier sont agrandies d'autant (elles étaient trop petites)
const WORLD_SEED := 20261108  ## graine des îles tirées au hasard : même monde pour tous les joueurs
const BREAKABLE := {"barrel": 1, "crate": 2}   ## objets qu'on peut casser sur les îles : points de vie
const BREAK_RESPAWN := 700.0  ## s : un tonneau cassé se reforme (si personne n'est sur l'île)

var islands: Array = []
## Tonneaux et caisses à casser : {island, kind, pos, hp, broken, timer, node, block: Vector3}. Jamais retirés de la liste.
var breakables: Array = []
var generated: Dictionary = {}     ## clés des cases déjà tirées (voir IslandGen)
var chunk_order: Array = []        ## [[cx, cz], …] : cases qui ont donné une île, dans l'ordre (les clients les refont dans le même ordre)
var _fixed_avoid: Array = []       ## cercles (x, z, rayon) des îles du fichier : les îles tirées au hasard les évitent
var _land_ref: Land
var enemies: Array[IslandEnemy] = []
var chests: Array = []
## Baies des dieux à cueillir : {island, pos, berry, taken, timer, dropped, node, fruit, glint}. Les baies du fichier
## (cachées dans un buisson) viennent d'abord ; les baies lâchées par un joueur s'ajoutent après. Jamais retirées de la liste.
var berry_spots: Array = []
var player_cfg: Dictionary = {}
var kinds: Dictionary = {}
var held: Dictionary = {}          ## îles capturées (id -> true) : leurs ennemis et leurs coffres ne reviennent plus
var respawn_secs := 150.0
var chest_respawn_secs := 600.0
var active_range := 70.0
var reveal_range := 70.0
var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _slashes: Array = []
var _fx: Array = []          ## effets de sorts en cours : {node, mat, t, dur, from, to}
var _slash_mesh: ArrayMesh
var _time := 0.0
var _opened_this_frame: Array = []


static func read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


# ------------------------------------------------------------------ données

func setup(islands_cfg: Dictionary, enemies_cfg: Dictionary) -> void:
	player_cfg = enemies_cfg.get("player", {})
	kinds = enemies_cfg.get("kinds", {})
	respawn_secs = float(enemies_cfg.get("respawn_secs", 150.0))
	chest_respawn_secs = float(enemies_cfg.get("chest_respawn_secs", 600.0))
	active_range = float(enemies_cfg.get("active_range", 70.0))
	reveal_range = float(islands_cfg.get("reveal_range", 70.0))
	_rng.seed = 424242
	islands.clear()
	enemies.clear()
	chests.clear()
	berry_spots.clear()
	breakables.clear()
	generated.clear()
	chunk_order.clear()
	_fixed_avoid.clear()
	var list: Array = islands_cfg.get("islands", [])
	for d: Dictionary in list:
		var i := _register_island(_scaled_island(d, ISLAND_SCALE), false)
		var isl: Dictionary = islands[i]
		_fixed_avoid.append(Vector3((isl["center"] as Vector2).x, (isl["center"] as Vector2).y, float(isl["radius"])))
	if GameConfig.TOWN_V3:   # (13/11 : l'ancienne ville, sur son île à part : pas d'île tirée au hasard dessus)
		_fixed_avoid.append(Vector3(GameConfig.OLD_TOWN_CENTER.x, GameConfig.OLD_TOWN_CENTER.y, 110.0))


## Ajoute l'île décrite par `d` (format de data/islands.json, coordonnées déjà à l'échelle) : terre, ennemis, coffres, baies,
## décor prévu. Renvoie son indice. `proc` : tirée au hasard sur la route (voir IslandGen).
func _register_island(d: Dictionary, proc: bool) -> int:
	var i := islands.size()
	var c := Vector2(float(d["center"][0]), float(d["center"][1]))
	var isl := {
		"id": str(d["id"]), "name": str(d["name"]), "blurb": str(d.get("blurb", "")), "danger": int(d.get("danger", 1)),
		"center": c, "lobes": [], "radius": 0.0, "items": [], "props": d.get("props", []),
		"scatter": _scatter_of(d), "cliffs": float(d.get("cliffs", 0.0)), "tone": str(d.get("tone", "lush")), "plateaus": _plateaus_of(d, c),
		"terrain": _terrain_of(d, c),
		"blockers_c": [], "blockers_r": [], "chests": [], "enemies": [], "proc": proc, "node": null, "breakable_ids": [],
	}
	var bound := 0.0
	for l: Array in d["lobes"]:
		var lc := c + Vector2(float(l[0]), float(l[1]))
		(isl["lobes"] as Array).append(Vector3(lc.x, lc.y, float(l[2])))
		bound = maxf(bound, Vector2(float(l[0]), float(l[1])).length() + float(l[2]))
	isl["radius"] = bound
	islands.append(isl)
	for e: Dictionary in d.get("enemies", []):
		var at := _settle(i, c + Vector2(float(e["at"][0]), float(e["at"][1])))
		var en := IslandEnemy.create(enemies.size(), str(e["kind"]), i, at, kinds[str(e["kind"])])
		enemies.append(en)
		(isl["enemies"] as Array).append(en.id)
	for ch: Dictionary in d.get("chests", []):
		var at := _settle(i, c + Vector2(float(ch["at"][0]), float(ch["at"][1])), true)
		var rec := {"island": i, "pos": at, "gold": int(ch["gold"]), "open": false, "timer": 0.0, "node": null, "lid": null,
				"pile": null, "glint": null, "lid_angle": 0.0}
		(isl["chests"] as Array).append(chests.size())
		chests.append(rec)
	for b: Dictionary in d.get("berries", []):
		var at := c + Vector2(float(b["at"][0]), float(b["at"][1]))
		berry_spots.append(_berry_record(i, at, str(b["berry"]), false))
	_plan_decor(i)
	return i


## Les îles du fichier, agrandies de `s` (elles étaient trop petites : un tour à pied ne durait que quelques secondes) :
## terre, relief et positions sont multipliés ; les semis de décor suivent la surface ; on ajoute des ennemis, des tonneaux
## et des caisses pour que la terre agrandie ne paraisse pas vide. Les objets eux-mêmes gardent leur taille.
static func _scaled_island(d: Dictionary, s: float) -> Dictionary:
	if is_equal_approx(s, 1.0):
		return d
	var out := d.duplicate(true)
	var lobes: Array = []
	for l: Array in d["lobes"]:
		lobes.append([float(l[0]) * s, float(l[1]) * s, float(l[2]) * s])
	out["lobes"] = lobes
	var placed: Array = []
	for key in ["enemies", "chests", "berries"]:
		for e: Dictionary in out.get(key, []):
			e["at"] = [float(e["at"][0]) * s, float(e["at"][1]) * s]
			placed.append([Vector2(float(e["at"][0]), float(e["at"][1])), 3.0])
	for p: Dictionary in out.get("props", []):
		if p.has("at"):
			p["at"] = [float(p["at"][0]) * s, float(p["at"][1]) * s]
			placed.append([Vector2(float(p["at"][0]), float(p["at"][1])), 3.0])
		if p.has("from"):
			p["from"] = [float(p["from"][0]) * s, float(p["from"][1]) * s]
			p["to"] = [float(p["to"][0]) * s, float(p["to"][1]) * s]
			# un mur occupe sa ligne : on y pose des repères pour ne rien placer dedans
			var wa := Vector2(float(p["from"][0]), float(p["from"][1]))
			var wb := Vector2(float(p["to"][0]), float(p["to"][1]))
			var steps := int(wa.distance_to(wb) / 2.0) + 1
			for k in steps + 1:
				placed.append([wa.lerp(wb, float(k) / float(steps)), 2.4])
	for pl: Dictionary in out.get("plateaus", []):
		pl["at"] = [float(pl["at"][0]) * s, float(pl["at"][1]) * s]
		pl["r"] = float(pl["r"]) * s
		if pl.has("ramp"):
			(pl["ramp"] as Dictionary)["len"] = float((pl["ramp"] as Dictionary).get("len", 0.0)) * s
		# ni ennemi, ni coffre, ni tonneau sur un plateau ou sa rampe
		placed.append([Vector2(float(pl["at"][0]), float(pl["at"][1])), float(pl["r"]) + float((pl.get("ramp", {}) as Dictionary).get("len", 0.0)) + 2.0])
	if out.has("terrain"):   # le relief suit la terre agrandie (les hauteurs, elles, sont en mètres)
		for hl: Dictionary in (out["terrain"] as Dictionary).get("hills", []):
			hl["at"] = [float(hl["at"][0]) * s, float(hl["at"][1]) * s]
			hl["r"] = float(hl["r"]) * s
			hl["flat"] = float(hl.get("flat", 0.0)) * s
	var sc: Dictionary = out.get("scatter", {})
	for k: String in sc:
		sc[k] = int(round(float(sc[k]) * s * s * 0.8))
	out["scatter"] = sc
	if out.has("palms"):
		out["palms"] = int(round(float(out["palms"]) * s * s * 0.8))
	# plus de monde sur la terre agrandie
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(d["id"]) + "/extra")
	var enemy_list: Array = out.get("enemies", [])
	if not enemy_list.is_empty():
		var enemy_kinds: Array = []
		for e: Dictionary in enemy_list:
			if not str(e["kind"]) in enemy_kinds and str(e["kind"]) != "captain":
				enemy_kinds.append(str(e["kind"]))
		for k in int(round(enemy_list.size() * 0.7)):
			var ep := IslandGen._free_point(lobes, rng, 3.0, placed, 3.0)
			if ep != Vector2.INF and not enemy_kinds.is_empty():
				enemy_list.append({"kind": enemy_kinds[rng.randi() % enemy_kinds.size()], "at": [ep.x, ep.y]})
				placed.append([ep, 2.5])
		out["enemies"] = enemy_list
	if int(d.get("danger", 1)) >= 2:
		var chest_list: Array = out.get("chests", [])
		var cp := IslandGen._free_point(lobes, rng, 3.5, placed, 4.0)
		if cp != Vector2.INF:
			chest_list.append({"at": [cp.x, cp.y], "gold": 55 + 25 * int(d.get("danger", 1))})
			placed.append([cp, 3.0])
		out["chests"] = chest_list
	var prop_list: Array = out.get("props", [])
	for k in int(round(lobes.size() * 2.0 + 3.0)):
		var bp := IslandGen._free_point(lobes, rng, 2.0, placed, 1.6)
		if bp != Vector2.INF:
			prop_list.append({"kind": "barrel" if rng.randf() < 0.5 else "crate", "at": [snappedf(bp.x, 0.1), snappedf(bp.y, 0.1)]})
			placed.append([bp, 1.6])
	out["props"] = prop_list
	return out


## Règles de semis du décor : [sdf mini, sdf maxi, espacement, rayon bloquant (0 = on traverse)].
const SCATTER_RULES := {
	"palm": [1.6, 99.0, 2.4, 0.32], "rock_spire": [3.0, 99.0, 4.5, 1.0], "rock": [1.8, 99.0, 2.4, 0.8],
	"dead_tree": [2.0, 99.0, 3.0, 0.3], "bush": [1.8, 99.0, 1.4, 0.0], "fern": [1.8, 99.0, 1.0, 0.0],
	"driftwood": [0.3, 1.8, 3.0, 0.5], "shell": [0.3, 2.8, 0.7, 0.0], "starfish": [0.3, 2.2, 1.4, 0.0],
}
const LORE_KINDS := ["bottle", "journal", "castaway"]   ## trouvailles : on les ramasse (bouteille, journal) ou on leur parle (naufragé)


## Place le décor (au hasard mais toujours pareil) : objets du fichier, puis semis de palmiers, rochers, buissons…
## Remplit isl["items"] = [{kind, pos, yaw, seed, data}] et la liste de ce qui bloque le passage.
func _plan_decor(i: int) -> void:
	var isl: Dictionary = islands[i]
	var c: Vector2 = isl["center"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(isl["id"]))
	var keep_clear: Array = []   # [point, distance mini] : ennemis, coffres, accessoires
	for en_id: int in isl["enemies"]:
		keep_clear.append([enemies[en_id].home, 2.6])
	for ch_id: int in isl["chests"]:
		keep_clear.append([(chests[ch_id] as Dictionary)["pos"], 2.4])
	var cb := isl["blockers_c"] as Array
	var rb := isl["blockers_r"] as Array
	var items := isl["items"] as Array
	var n := 0
	for p: Dictionary in isl["props"]:
		n += 1
		var kind := str(p["kind"])
		if kind == "wall":
			var a := c + Vector2(float(p["from"][0]), float(p["from"][1]))
			var b := c + Vector2(float(p["to"][0]), float(p["to"][1]))
			rb.append(Rect2(Vector2(minf(a.x, b.x) - 0.4, minf(a.y, b.y) - 0.4), Vector2(absf(a.x - b.x) + 0.8, absf(a.y - b.y) + 0.8)))
			items.append({"kind": "wall", "pos": c, "yaw": 0.0, "seed": i * 100 + n, "data": p})
			continue
		var at := c + Vector2(float(p["at"][0]), float(p["at"][1]))
		var yaw := IslandDecor.prop_yaw(p, i * 100 + n)
		keep_clear.append([at, 4.0 if kind in ["wreck", "tower", "hut", "skull_rock", "arch"] else 1.6])
		var blocks := IslandDecor.blockers(kind, at, yaw)
		cb.append_array(blocks)
		var item := {"kind": kind, "pos": at, "yaw": yaw, "seed": i * 100 + n, "data": p}
		if BREAKABLE.has(kind):   # tonneau ou caisse : on peut le casser (et il ne bloque plus quand il est cassé)
			item["breakable"] = breakables.size()
			(isl["breakable_ids"] as Array).append(breakables.size())
			breakables.append({"island": i, "kind": kind, "pos": at, "hp": int(BREAKABLE[kind]), "broken": false, "timer": 0.0,
					"node": null, "block": blocks[0] if not blocks.is_empty() else Vector3.INF})
		items.append(item)
	for ch_id: int in isl["chests"]:
		var cp: Vector2 = (chests[ch_id] as Dictionary)["pos"]
		cb.append(Vector3(cp.x, cp.y, 0.5))
	var placed: Array = []
	var bound: float = isl["radius"]
	var scatter: Dictionary = isl["scatter"]
	var tone := str(isl.get("tone", "lush"))
	isl["lore_items"] = []
	isl["plants"] = []
	for kind: String in ["palm", "rock_spire", "rock", "dead_tree", "bush", "fern", "driftwood", "shell", "starfish"]:
		var want := int(scatter.get(kind, 0))
		if kind == "shell" and not scatter.has(kind):
			want = int(bound / 1.6)
		elif kind == "starfish" and not scatter.has(kind):
			want = 0 if tone == "dead" else int(bound / 4.5)
		var rule: Array = SCATTER_RULES[kind]
		var got := 0
		var tries := 0
		while got < want and tries < 3000:
			tries += 1
			var p := c + Vector2(rng.randf_range(-bound, bound), rng.randf_range(-bound, bound))
			var r := 0.0
			if kind == "rock":
				r = rng.randf_range(0.5, 1.0)
			elif kind == "rock_spire":
				r = rng.randf_range(0.9, 1.4)
			var s := sdf(i, p)
			if s < float(rule[0]) + r * 0.6 or s > float(rule[1]):
				continue
			if _too_close(p, keep_clear, r) or _too_close(p, placed, 0.0) or not is_flat(i, p, 1.0 + r):
				continue
			var yaw := rng.randf() * TAU
			var seed_value := i * 1000 + items.size()
			items.append({"kind": kind, "pos": p, "yaw": yaw, "seed": seed_value, "data": {"r": r}})
			placed.append([p, float(rule[2]) + r])
			if float(rule[3]) > 0.0:
				cb.append(Vector3(p.x, p.y, maxf(float(rule[3]), r * 0.85) if r > 0.0 else float(rule[3])))
			got += 1
	_plan_lore(i, rng, keep_clear, placed, tone)


## Les trouvailles de l'île (toujours les mêmes d'une partie à l'autre) : ruines, camp d'un naufragé, bouteille échouée sur la
## plage, journal de pirate à l'intérieur des terres. Chaque trouvaille a un `seed` : c'est elle qui choisit le message.
func _plan_lore(i: int, rng: RandomNumberGenerator, keep_clear: Array, placed: Array, tone: String) -> void:
	var isl: Dictionary = islands[i]
	var c: Vector2 = isl["center"]
	var bound: float = isl["radius"]
	var items := isl["items"] as Array
	var cb := isl["blockers_c"] as Array
	# [sorte, chance, rayon mini de l'île, distance au bord mini, maxi, place libre autour]
	var plans := [["ruin", 0.38, 14.0, 5.0, 99.0, 3.6], ["castaway", 0.3 if tone == "lush" else 0.0, 16.0, 4.5, 99.0, 3.6],
			["bottle", 0.75, 4.0, 0.6, 2.0, 1.0], ["journal", 0.5, 10.0, 3.5, 99.0, 1.5]]
	for plan: Array in plans:
		var kind: String = plan[0]
		var roll := rng.randf()
		if roll > float(plan[1]) or bound < float(plan[2]):
			continue
		for attempt in 400:
			var p := c + Vector2(rng.randf_range(-bound, bound), rng.randf_range(-bound, bound))
			var s := sdf(i, p)
			if s < float(plan[3]) or s > float(plan[4]):
				continue
			if _too_close(p, keep_clear, float(plan[5])) or _too_close(p, placed, 0.0) or not is_flat(i, p, 1.5):
				continue
			var yaw := rng.randf() * TAU
			var seed_value := i * 1000 + 700 + items.size()
			var item := {"kind": kind, "pos": p, "yaw": yaw, "seed": seed_value, "data": {}}
			items.append(item)
			cb.append_array(IslandDecor.blockers(kind, p, yaw))
			placed.append([p, float(plan[5])])
			if kind in LORE_KINDS:
				(isl["lore_items"] as Array).append(item)
			if kind == "castaway":   # son feu de camp, à côté de l'abri
				var off := Vector2(1.9, 1.4)
				var fp := p + Vector2(off.x * cos(yaw) + off.y * sin(yaw), -off.x * sin(yaw) + off.y * cos(yaw))
				items.append({"kind": "campfire", "pos": fp, "yaw": 0.0, "seed": seed_value + 1, "data": {}})
				cb.append_array(IslandDecor.blockers("campfire", fp, 0.0))
				item["data"] = {"fire": fp}
			break


func _too_close(p: Vector2, list: Array, extra: float) -> bool:
	for e: Array in list:
		if p.distance_to(e[0]) < float(e[1]) + extra:
			return true
	return false


func _plateaus_of(d: Dictionary, c: Vector2) -> Array:
	var out: Array = []
	for pl: Dictionary in d.get("plateaus", []):
		var ramp: Dictionary = pl.get("ramp", {})
		out.append({"c": c + Vector2(float(pl["at"][0]), float(pl["at"][1])), "r": float(pl["r"]), "h": float(pl["h"]),
				"ramp_dir": Vector2.from_angle(deg_to_rad(float(ramp.get("angle", 0.0)))), "ramp_half": float(ramp.get("width", 0.0)) * 0.5,
				"ramp_len": float(ramp.get("len", 0.0))})
	return out


# ------------------------------------------------------------------ relief (13/11, refonte des îles)
# Une île « à relief » décrit son terrain dans data/islands.json :
#   "terrain": {"seed": 7, "noise": 0.8, "beach": 6, "hills": [{"at": [x, z], "r": 30, "h": 20, "steep": 0.7, "steep_dir": 40,
#               "flat": 3, "coast": false}]}
# Le sol n'est plus plat : chaque colline est une bosse lisse de rayon `r` et de hauteur `h` (mètres), avec un sommet plat de
# rayon `flat` ; `steep` (0…1) resserre la bosse du côté `steep_dir` (degrés) : ce flanc devient une falaise, l'autre reste
# une pente qu'on gravit. Un bruit de `noise` m bosselle le tout, et une plage plate de `beach` m borde l'île (sauf pour
# une colline « coast », dont la falaise tombe dans la mer). On ne marche pas sur une pente plus raide que WALK_SLOPE.
const WALK_SLOPE := 0.85     ## pente maximale où l'on tient debout (rapport hauteur / distance : environ 40°)


func _terrain_of(d: Dictionary, c: Vector2) -> Dictionary:
	if not d.has("terrain"):
		return {}
	var t: Dictionary = d["terrain"]
	var hills: Array = []
	var top := 0.0
	for hl: Dictionary in t.get("hills", []):
		hills.append({"c": c + Vector2(float(hl["at"][0]), float(hl["at"][1])), "r": float(hl["r"]), "h": float(hl["h"]),
				"steep": float(hl.get("steep", 0.0)), "dir": deg_to_rad(float(hl.get("steep_dir", 0.0))), "flat": float(hl.get("flat", 0.0)),
				"coast": bool(hl.get("coast", false))})
		top = maxf(top, float(hl["h"]))
	return {"seed": float(t.get("seed", 1.0)), "noise": float(t.get("noise", 0.6)), "beach": float(t.get("beach", 5.0)), "hills": hills,
			"top": top}


static func _vhash(p: Vector2) -> float:
	return fposmod(sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453, 1.0)


## Bruit de valeur lissé (0…1), le même dessin pour tous les joueurs.
static func _vnoise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	return lerpf(lerpf(_vhash(i), _vhash(i + Vector2(1, 0)), f.x), lerpf(_vhash(i + Vector2(0, 1)), _vhash(i + Vector2(1, 1)), f.x), f.y)


## Hauteur du relief de l'île `i` en `p` (0 en mer et sur la plage).
func _terrain_h(i: int, p: Vector2) -> float:
	var t: Dictionary = (islands[i] as Dictionary)["terrain"]
	var s := sdf(i, p)
	if s <= 0.0:
		return 0.0
	var beach: float = t["beach"]
	var inland := smoothstep(beach * 0.5, beach + 7.0, s)
	var shore := smoothstep(0.0, 2.0, s)
	var h := 0.0
	for hl: Dictionary in t["hills"]:
		var d: Vector2 = p - (hl["c"] as Vector2)
		var dist := d.length()
		var r: float = hl["r"]
		if float(hl["steep"]) > 0.0 and dist > 0.01:
			var k := maxf(cos(d.angle() - float(hl["dir"])), 0.0)
			r *= 1.0 - float(hl["steep"]) * 0.62 * k * k
		var flat: float = hl["flat"]
		var u := clampf(1.0 - maxf(dist - flat, 0.0) / maxf(r - flat, 0.1), 0.0, 1.0)
		h += float(hl["h"]) * u * u * (3.0 - 2.0 * u) * (shore if bool(hl["coast"]) else inland)
	var seed: float = t["seed"]
	var amp: float = t["noise"]
	h += ((_vnoise(p * 0.085 + Vector2(seed, seed * 1.7)) - 0.5) * 2.0 * amp + (_vnoise(p * 0.24 + Vector2(seed * 3.1, 5.0)) - 0.5) * amp * 0.7) * inland
	return maxf(h, 0.0)


## Le sol est-il presque plat autour de `q` (un coffre s'y pose droit) ?
func _level_enough(i: int, q: Vector2) -> bool:
	var h0 := _terrain_h(i, q)
	for off: Vector2 in [Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
		if absf(_terrain_h(i, q + off) - h0) > 0.2:
			return false
	return true


## Sur une île à relief, ramène `p` au point le plus proche où l'on tient debout (un ennemi ou un coffre ne se pose pas sur une
## falaise) ; ailleurs, `p` tel quel.
func _settle(i: int, p: Vector2, level: bool = false) -> Vector2:
	if ((islands[i] as Dictionary)["terrain"] as Dictionary).is_empty():
		return p
	var d := 0.0
	while d <= 14.0:
		for k in (1 if d == 0.0 else 16):
			var q := p + Vector2.from_angle(TAU * k / 16.0) * d
			if sdf(i, q) > 1.2 and not too_steep(i, q) and not too_steep(i, q + Vector2(0.6, 0)) and not too_steep(i, q - Vector2(0.6, 0)) 					and not too_steep(i, q + Vector2(0, 0.6)) and not too_steep(i, q - Vector2(0, 0.6)) 					and (not level or _level_enough(i, q)):
				return q
		d += 0.5
	return p


## La pente est-elle trop raide pour tenir debout en `p` sur l'île `i` ? (toujours faux sur une île sans relief)
func too_steep(i: int, p: Vector2) -> bool:
	if ((islands[i] as Dictionary)["terrain"] as Dictionary).is_empty():
		return false
	var e := 0.45
	var gx := (_terrain_h(i, p + Vector2(e, 0)) - _terrain_h(i, p - Vector2(e, 0))) / (2.0 * e)
	var gz := (_terrain_h(i, p + Vector2(0, e)) - _terrain_h(i, p - Vector2(0, e))) / (2.0 * e)
	return gx * gx + gz * gz > WALK_SLOPE * WALK_SLOPE


## Pour Land : vrai si `p` (monde) est sur une pente d'île trop raide pour y marcher.
func steep_at(p: Vector2) -> bool:
	var i := island_at(p)
	return i >= 0 and too_steep(i, p)


## Hauteur du sol de l'île `i` en `p` : 0 en plaine, la hauteur du plateau dessus, une pente douce sur la rampe.
## Le bord d'un plateau est une falaise à pic (on ne la monte pas), sauf là où se trouve la rampe.
func height(i: int, p: Vector2) -> float:
	var h := 0.0
	if not ((islands[i] as Dictionary)["terrain"] as Dictionary).is_empty():
		h = _terrain_h(i, p)
	for pl: Dictionary in (islands[i] as Dictionary)["plateaus"]:
		var d: Vector2 = p - (pl["c"] as Vector2)
		var dist := d.length()
		var r: float = pl["r"]
		if dist <= r:
			h = maxf(h, float(pl["h"]))
		elif float(pl["ramp_len"]) > 0.0 and dist < r + float(pl["ramp_len"]):
			if absf(rad_to_deg(d.angle_to(pl["ramp_dir"]))) < float(pl["ramp_half"]):
				h = maxf(h, float(pl["h"]) * (1.0 - (dist - r) / float(pl["ramp_len"])))
	return h


## Hauteur du sol en un point quelconque du monde (0 hors des îles) : c'est ce que Land utilise pour marcher.
func ground_h(p: Vector2) -> float:
	var i := island_at(p)
	return height(i, p) if i >= 0 else 0.0


## Le terrain est-il assez plat autour de `p` (rayon `r`) pour y poser un objet ?
func is_flat(i: int, p: Vector2, r: float) -> bool:
	var h0 := height(i, p)
	var tol := 0.05 if ((islands[i] as Dictionary)["terrain"] as Dictionary).is_empty() else 0.05 + 0.28 * r   # (relief : une pente douce suffit)
	for off: Vector2 in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if absf(height(i, p + off) - h0) > tol:
			return false
	return true


func _scatter_of(d: Dictionary) -> Dictionary:
	var out: Dictionary = (d.get("scatter", {}) as Dictionary).duplicate()
	if d.has("palms"):
		out["palm"] = int(d["palms"])
	if d.has("rocks"):
		out["rock"] = int(d["rocks"])
	return out


# ------------------------------------------------------------------ géométrie

## Distance signée au bord de la terre marchable de l'île `i` : positive à l'intérieur, négative en mer.
func sdf(i: int, p: Vector2) -> float:
	var best := -INF
	for l: Vector3 in (islands[i] as Dictionary)["lobes"]:
		best = maxf(best, l.z - Vector2(l.x, l.y).distance_to(p))
	return best


## Un point de rayon `r` peut-il se tenir ici (sur la terre, hors des obstacles) ?
func walkable(i: int, p: Vector2, r: float) -> bool:
	if sdf(i, p) < r:
		return false
	if too_steep(i, p):
		return false
	var isl: Dictionary = islands[i]
	for b: Vector3 in isl["blockers_c"]:
		if Vector2(b.x, b.y).distance_to(p) < b.z + r * 0.5:
			return false
	for rc: Rect2 in isl["blockers_r"]:
		if rc.grow(r * 0.5).has_point(p):
			return false
	return true


## L'île dont la terre contient (ou borde de moins de `margin` m) le point, ou -1.
func island_at(p: Vector2, margin: float = 0.0) -> int:
	for i in islands.size():
		var isl: Dictionary = islands[i]
		if p.distance_to(isl["center"]) > float(isl["radius"]) + margin + 1.0:
			continue
		if sdf(i, p) >= -margin:
			return i
	return -1


## Hauteur du relief à la distance signée `s` du bord (0 sur la terre, puis la pente vers le fond).
static func ground_height(s: float) -> float:
	if s >= 0.0:
		return 0.0
	var t := clampf(-s / SLOPE, 0.0, 1.0)
	return -DROP * t * t * (3.0 - 2.0 * t)


## Indice du premier point du contour de la coque qui touche une île, ou -1.
func ship_hit_index(points: Array) -> int:
	for i in points.size():
		var p: Vector2 = points[i]
		for k in islands.size():
			var isl: Dictionary = islands[k]
			if p.distance_squared_to(isl["center"]) > pow(float(isl["radius"]) + SHIP_MARGIN + 1.0, 2.0):
				continue
			for l: Vector3 in isl["lobes"]:
				if Vector2(l.x, l.y).distance_squared_to(p) < pow(l.z + SHIP_MARGIN, 2.0):
					return i
	return -1


## Discs marchables [x, z, r] de toutes les îles, pour le terrain à pied (Land).
func walk_discs() -> Array:
	var out: Array = []
	for isl: Dictionary in islands:
		for l: Vector3 in isl["lobes"]:
			out.append([l.x, l.y, l.z])
	return out


# ------------------------------------------------------------------ 3D

func build(parent: Node3D, land: Land) -> void:
	_root = Node3D.new()
	_root.name = "Islands"
	parent.add_child(_root)
	_land_ref = land
	land.island_discs = walk_discs()
	land.island_height = ground_h
	land.island_steep = steep_at
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load("res://shaders/island_ground.gdshader") as Shader
	for i in islands.size():
		_build_island(i)
	_build_slash_mesh()


var _ground_mat: ShaderMaterial


## Pose en 3D l'île `i` : terre, eaux peu profondes, décor, obstacles à pied, coffres, ennemis, baies.
func _build_island(i: int) -> void:
	var land := _land_ref
	var isl: Dictionary = islands[i]
	if isl["node"] != null:
		return
	var c: Vector2 = isl["center"]
	var node := Node3D.new()
	node.name = str(isl["id"])
	node.position = Vector3(c.x, 0.0, c.y)
	_root.add_child(node)
	isl["node"] = node
	var mi := MeshInstance3D.new()
	mi.mesh = _terrain_mesh(i)
	mi.material_override = _ground_material(_ground_mat, str(isl["tone"]))
	if not (isl["terrain"] as Dictionary).is_empty():   # relief : l'herbe change de teinte avec l'altitude
		(mi.material_override as ShaderMaterial).set_shader_parameter("relief_top", float((isl["terrain"] as Dictionary)["top"]))
	node.add_child(mi)
	var sh := MeshInstance3D.new()
	sh.mesh = _shallows_mesh(i)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/island_shallows.gdshader") as Shader
	sm.set_shader_parameter("seed", float(i) * 13.7)
	sh.material_override = sm
	sh.position = Vector3(0, SHALLOW_Y, 0)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(sh)
	for it: Dictionary in isl["items"]:
		var d: Dictionary = it["data"]
		var made := IslandDecor.make(node, str(it["kind"]), (it["pos"] as Vector2) - c, float(it["yaw"]), int(it["seed"]), d, height(i, it["pos"]))
		if it.has("breakable"):
			(breakables[int(it["breakable"])] as Dictionary)["node"] = made
		it["node"] = made
		if it["kind"] in ["bush", "fern", "palm"]:   # les plantes s'écartent sur le passage du joueur (voir IslandLife)
			(isl["plants"] as Array).append(it)
	if bool(isl["proc"]):
		for l: Vector3 in isl["lobes"]:
			land.island_discs.append([l.x, l.y, l.z])
	# ce qui bloque le passage à pied : mêmes obstacles côté Land (repère du fichier : y = -z)
	for b: Vector3 in isl["blockers_c"]:
		land.circles.append([b.x, -b.y, b.z])
	for rc: Rect2 in isl["blockers_r"]:
		land.obstacles.append([rc.position.x, -(rc.position.y + rc.size.y), rc.position.x + rc.size.x, -rc.position.y])
	for ch_id: int in isl["chests"]:
		var ch: Dictionary = chests[ch_id]
		var made_chest := IslandDecor.chest(_root, ch["pos"])
		ch["node"] = made_chest["root"]
		ch["lid"] = made_chest["lid"]
		ch["pile"] = made_chest["pile"]
		ch["glint"] = made_chest["glint"]
		(made_chest["root"] as Node3D).rotation.y = float(hash(str(ch["pos"])) % 100) / 100.0 * 0.6 - 0.3
		(made_chest["root"] as Node3D).position.y = height(i, ch["pos"])
	for en_id: int in isl["enemies"]:
		enemies[en_id].build_model(_root)
	for k in berry_spots.size():
		if int((berry_spots[k] as Dictionary)["island"]) == i:
			_build_berry_node(k)


# ------------------------------------------------------------------ îles tirées au hasard

## Génère (hôte, ou client qui suit la liste de l'hôte) l'île de la case `c` si elle n'existe pas encore. Renvoie son indice, ou -1.
func ensure_chunk(c: Vector2i) -> int:
	var key := IslandGen.key_of(c)
	if generated.has(key):
		return int(generated[key])
	var d := IslandGen.generate(c, WORLD_SEED, _fixed_avoid)
	if d.is_empty():
		generated[key] = -1
		return -1
	var i := _register_island(d, true)
	generated[key] = i
	chunk_order.append([c.x, c.y])
	if _root != null:
		_build_island(i)
	return i


## Hôte (ou solo) : génère l'île de la case voisine du bateau la plus proche qui n'en a pas encore (une seule par appel :
## construire une grande île prend un moment, on étale le travail sur plusieurs images). Renvoie son indice, ou -1.
func ensure_around(p: Vector2) -> int:
	var here := IslandGen.cell_of(p)
	var cells: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			cells.append(here + Vector2i(dx, dz))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ca := (Vector2(a) + Vector2(0.5, 0.5)) * IslandGen.CELL
		var cb := (Vector2(b) + Vector2(0.5, 0.5)) * IslandGen.CELL
		return ca.distance_squared_to(p) < cb.distance_squared_to(p))
	for c in cells:
		if generated.has(IslandGen.key_of(c)):
			continue
		var i := ensure_chunk(c)
		if i >= 0:
			return i
	return -1


## Chemins de terre : de la plage où l'on aborde (côté du port) au centre, puis jusqu'à chaque coffre.
func _path_segments(i: int) -> Array:
	var isl: Dictionary = islands[i]
	var c: Vector2 = isl["center"]
	var lobe: Vector3 = isl["lobes"][0]
	var toward := (Vector2.ZERO - c).normalized()
	var landing := Vector2(lobe.x, lobe.y) + toward * (lobe.z - 1.5)
	var segs: Array = [[landing, c]]
	for ch_id: int in isl["chests"]:
		var cp: Vector2 = (chests[ch_id] as Dictionary)["pos"]
		var mid := (c + cp) * 0.5 + Vector2(-(cp - c).y, (cp - c).x).normalized() * 1.6
		segs.append([c, mid])
		segs.append([mid, cp])
	return segs


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Part de falaise (0..1) de la côte de l'île `i` dans la direction de `p` : par secteurs, selon `cliffs` dans le fichier.
func _cliff_amount(i: int, p: Vector2) -> float:
	var isl: Dictionary = islands[i]
	var amount: float = isl["cliffs"]
	if amount <= 0.0:
		return 0.0
	var d := p - (isl["center"] as Vector2)
	var a := atan2(d.y, d.x)
	var ph := float(hash(str(isl["id"])) % 628) / 100.0
	var nz := sin(a * 2.0 + ph) * 0.5 + sin(a * 5.0 + ph * 2.3) * 0.3 + 0.1
	return smoothstep(1.0 - amount * 1.4, 1.0 - amount * 1.4 + 0.12, nz)


## Matière du sol d'une île selon son ambiance : « lush » (verte, fleurie) ou « dead » (herbe terne, sans fleurs).
func _ground_material(base: ShaderMaterial, tone: String) -> ShaderMaterial:
	var m := base.duplicate() as ShaderMaterial
	if tone == "dead":
		m.set_shader_parameter("grass_dark", Vector3(0.23, 0.30, 0.19))
		m.set_shader_parameter("grass_base", Vector3(0.34, 0.41, 0.24))
		m.set_shader_parameter("grass_light", Vector3(0.42, 0.48, 0.28))
		m.set_shader_parameter("grass_high", Vector3(0.5, 0.55, 0.32))
		m.set_shader_parameter("flowers", 0.0)
	elif tone == "fort":
		m.set_shader_parameter("flowers", 0.3)
	return m


func _terrain_mesh(i: int) -> ArrayMesh:
	var isl: Dictionary = islands[i]
	var c: Vector2 = isl["center"]
	var ext: float = float(isl["radius"]) + SLOPE + 1.0
	# les grandes îles (agrandies) ont un maillage un peu plus lâche : sinon le calcul au lancement serait trop long
	var relief := not (isl["terrain"] as Dictionary).is_empty()
	var grid := GRID * clampf(ext / 40.0, 1.0, 2.6 if relief else 2.0)
	var n := int(ceil(ext * 2.0 / grid)) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var sdfs := PackedFloat32Array()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	sdfs.resize(n * n)
	var segs := _path_segments(i)
	for iz in n:
		for ix in n:
			var lx := -ext + ix * grid
			var lz := -ext + iz * grid
			var wp := c + Vector2(lx, lz)
			var s := sdf(i, wp)
			var cl := _cliff_amount(i, wp)
			var h := lerpf(ground_height(s), cliff_height(s), cl) + (height(i, wp) if s >= 0.0 else 0.0)
			var idx := iz * n + ix
			verts[idx] = Vector3(lx, h, lz)
			sdfs[idx] = s
			var noise := sin(lx * 0.9 + lz * 0.7) * 0.5 + sin(lx * 0.37 - lz * 1.1) * 0.5
			var grass := clampf((s - 2.6 + noise * 0.7) * 2.0 + 0.5, 0.0, 1.0)
			var dp := 99.0
			if s > 0.0:
				for sg: Array in segs:
					dp = minf(dp, _dist_to_segment(wp, sg[0], sg[1]))
			var path := 1.0 - smoothstep(0.35, 0.95, dp)
			var rock := 1.0 if (cl > 0.5 and s < -0.05) else 0.0
			cols[idx] = Color(grass, clampf((-0.15 - h) / 0.5, 0.0, 1.0) if rock < 0.5 else 0.0, path, rock)
	for iz in n:
		for ix in n:
			var hl := (verts[iz * n + maxi(ix - 1, 0)] as Vector3).y
			var hr := (verts[iz * n + mini(ix + 1, n - 1)] as Vector3).y
			var hu := (verts[maxi(iz - 1, 0) * n + ix] as Vector3).y
			var hd := (verts[mini(iz + 1, n - 1) * n + ix] as Vector3).y
			norms[iz * n + ix] = Vector3(hl - hr, 2.0 * grid, hu - hd).normalized()
	# falaises des plateaux : les sommets au bord d'une marche haute prennent la couleur de la roche
	for iz in range(1, n - 1):
		for ix in range(1, n - 1):
			var hc := (verts[iz * n + ix] as Vector3).y
			var steep := 0.0
			for nb: int in [iz * n + ix - 1, iz * n + ix + 1, (iz - 1) * n + ix, (iz + 1) * n + ix]:
				steep = maxf(steep, absf((verts[nb] as Vector3).y - hc))
			if steep > (WALK_SLOPE * grid if relief else 0.45) and sdfs[iz * n + ix] > 0.0:
				var col := cols[iz * n + ix]
				col.a = 1.0
				col.b = 0.0
				cols[iz * n + ix] = col
	var idxs := PackedInt32Array()
	for iz in n - 1:
		for ix in n - 1:
			var a := iz * n + ix
			var b := a + 1
			var d := a + n
			var e := d + 1
			if maxf(maxf(sdfs[a], sdfs[b]), maxf(sdfs[d], sdfs[e])) < -SLOPE:
				continue
			idxs.append_array([a, b, d, b, e, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Hauteur d'une falaise : presque à pic.
static func cliff_height(s: float) -> float:
	if s >= 0.0:
		return 0.0
	var t := clampf(-s / 0.9, 0.0, 1.0)
	return -DROP * t * t * (3.0 - 2.0 * t)


## Eaux peu profondes autour de l'île : une nappe plate dont la couleur de sommet porte la distance au bord.
func _shallows_mesh(i: int) -> ArrayMesh:
	var isl: Dictionary = islands[i]
	var c: Vector2 = isl["center"]
	var step := 1.0
	var ext: float = float(isl["radius"]) + SHALLOW_WIDTH + 1.0
	var n := int(ceil(ext * 2.0 / step)) + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var sdfs := PackedFloat32Array()
	for iz in n:
		for ix in n:
			var lx := -ext + ix * step
			var lz := -ext + iz * step
			var s := sdf(i, c + Vector2(lx, lz))
			verts.append(Vector3(lx, 0.0, lz))
			sdfs.append(s)
			cols.append(Color(clampf((s + 12.0) / 24.0, 0.0, 1.0), 0, 0))
	var idxs := PackedInt32Array()
	for iz in n - 1:
		for ix in n - 1:
			var a := iz * n + ix
			var b := a + 1
			var d := a + n
			var e := d + 1
			if maxf(maxf(sdfs[a], sdfs[b]), maxf(sdfs[d], sdfs[e])) < -SHALLOW_WIDTH or minf(minf(sdfs[a], sdfs[b]), minf(sdfs[d], sdfs[e])) > 1.0:
				continue
			idxs.append_array([a, d, b, b, d, e])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_slash_mesh() -> void:
	# un croissant plat devant le pirate (coup de sabre), de -70° à +70°
	var verts := PackedVector3Array()
	var idxs := PackedInt32Array()
	var segs := 14
	for k in segs + 1:
		var a := deg_to_rad(-70.0 + 140.0 * k / segs)
		var w := sin(PI * k / segs)
		verts.append(Vector3(sin(a), 0, cos(a)) * (1.0 + 0.45 * w))
		verts.append(Vector3(sin(a), 0, cos(a)) * (1.0 - 0.1 * w))
	for k in segs:
		var o := k * 2
		idxs.append_array([o, o + 1, o + 2, o + 1, o + 3, o + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idxs
	_slash_mesh = ArrayMesh.new()
	_slash_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Coup de sabre du joueur : croissant blanc qui s'éteint en 0,18 s.
func spawn_slash(origin: Vector2, dir: Vector2) -> void:
	if _root == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _slash_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.97, 0.8, 0.85)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(origin.x, 0.9, origin.y)
	mi.rotation.y = atan2(dir.x, dir.y)
	mi.scale = Vector3.ONE * float(player_cfg.get("swing_range", 1.9)) * 0.75
	_root.add_child(mi)
	_slashes.append({"node": mi, "t": 0.0})


## Chaque image, chez tout le monde : animations des ennemis, des coffres, des coups de sabre.
func update_visuals(delta: float, authority: bool) -> void:
	if _root == null:
		return
	_time += delta
	for en in enemies:
		en.ground_y = height(en.island, en.pos)
		en.update_visual(delta, _time, authority)
	for ch: Dictionary in chests:
		var target := -1.9 if ch["open"] else 0.0
		ch["lid_angle"] = lerpf(float(ch["lid_angle"]), target, 1.0 - exp(-delta * 9.0))
		(ch["lid"] as Node3D).rotation.x = float(ch["lid_angle"])
		(ch["pile"] as Node3D).visible = ch["open"]
		var glint := ch["glint"] as Node3D
		glint.visible = not ch["open"]
		glint.position.y = 1.05 + sin(_time * 3.0 + (ch["pos"] as Vector2).x) * 0.1
	var keep: Array = []
	for s: Dictionary in _slashes:
		s["t"] = float(s["t"]) + delta
		var k := float(s["t"]) / 0.18
		var node := s["node"] as MeshInstance3D
		if k >= 1.0:
			node.queue_free()
			continue
		(node.material_override as StandardMaterial3D).albedo_color.a = 0.85 * (1.0 - k)
		keep.append(s)
	_slashes = keep
	var fx_keep: Array = []
	for f: Dictionary in _fx:
		f["t"] = float(f["t"]) + delta
		var u := clampf(float(f["t"]) / float(f["dur"]), 0.0, 1.0)
		var node := f["node"] as MeshInstance3D
		if u >= 1.0:
			node.queue_free()
			continue
		node.scale = (f["from"] as Vector3).lerp(f["to"], 1.0 - (1.0 - u) * (1.0 - u))
		var m := f["mat"] as StandardMaterial3D
		m.albedo_color.a = 0.75 * (1.0 - u)
		fx_keep.append(f)
	_fx = fx_keep


# ------------------------------------------------------------------ simulation (hôte ou solo)

## Fait vivre les ennemis. `players` : [{id, pos}] des joueurs à terre. Renvoie les coups portés aux joueurs.
func step(delta: float, players: Array) -> Array:
	var events: Array = []
	for i in islands.size():
		var isl: Dictionary = islands[i]
		var near: Array = []
		var on_island: Array = []
		for p: Dictionary in players:
			var d := (p["pos"] as Vector2).distance_to(isl["center"])
			if d <= float(isl["radius"]) + active_range:
				near.append(p)
			if sdf(i, p["pos"]) >= -1.0:
				on_island.append(p)
		var held_here := held.has(str(isl["id"]))   # île capturée : ni ennemis ni coffres ne reviennent
		for en_id: int in isl["enemies"]:
			var en := enemies[en_id]
			if en.is_dead():
				en.step(delta, on_island, self, _rng)
				if en.timer <= 0.0 and on_island.is_empty() and near.is_empty() and not held_here:
					en.revive()
				continue
			if near.is_empty():
				continue
			events.append_array(en.step(delta, on_island, self, _rng))
		for ch_id: int in isl["chests"]:
			var ch: Dictionary = chests[ch_id]
			if ch["open"]:
				ch["timer"] = float(ch["timer"]) - delta
				if float(ch["timer"]) <= 0.0 and near.is_empty() and not held_here:
					ch["open"] = false
		for k: int in isl["breakable_ids"]:
			var b: Dictionary = breakables[k]
			if b["broken"]:
				b["timer"] = float(b["timer"]) - delta
				if float(b["timer"]) <= 0.0 and near.is_empty():
					_restore(k)
	return events


## Coup de sabre de `peer` depuis `origin` vers `dir`. Renvoie [{gold, at, killed}] pour chaque ennemi touché.
func swing(origin: Vector2, dir: Vector2) -> Array:
	var out: Array = []
	var reach := float(player_cfg.get("swing_range", 1.9))
	var half_arc := deg_to_rad(float(player_cfg.get("swing_arc_deg", 140.0)) * 0.5)
	var dmg := int(player_cfg.get("swing_damage", 1))
	var power := float(player_cfg.get("knockback", 2.4))
	for en in enemies:
		if en.is_dead():
			continue
		var to := en.pos - origin
		var body := 0.4 * float(en.cfg["scale"])
		if to.length() > reach + body:
			continue
		if to.length() > 0.3 and absf(dir.angle_to(to)) > half_arc:
			continue
		var killed := en.hurt(dmg, origin, power)
		var gold := 0
		if killed:
			var g: Array = en.cfg["gold"]
			gold = _rng.randi_range(int(g[0]), int(g[1]))
			en.timer = respawn_secs
		out.append({"gold": gold, "at": en.pos, "killed": killed, "enemy": en.id})
	for br: Dictionary in hit_breakables(origin, dir, reach, half_arc, dmg):
		out.append({"gold": 0, "at": br["pos"], "killed": false, "enemy": -1, "prop": true, "kind": br["kind"]})
	return out


## Lot 5 (6.8) : un boulet de canon tombe en `at` (monde x/z) à la hauteur `y` : il touche les ennemis tout près (PV en moins,
## sonnés un instant). Renvoie comme `swing`.
func cannonball(at: Vector2, y: float) -> Array:
	var out: Array = []
	for en in enemies:
		if en.is_dead():
			continue
		if en.pos.distance_to(at) > GameConfig.MOB_BALL_RADIUS * float(en.cfg["scale"]):
			continue
		if y < en.ground_y - 0.3 or y > en.ground_y + 2.2 * float(en.cfg["scale"]):
			continue
		var killed := en.hurt(GameConfig.MOB_BALL_DAMAGE, at, 1.5)
		en.slow_t = GameConfig.MOB_SLOW_TIME
		var gold := 0
		if killed:
			var g: Array = en.cfg["gold"]
			gold = _rng.randi_range(int(g[0]), int(g[1]))
			en.timer = respawn_secs
		out.append({"gold": gold, "at": en.pos, "killed": killed, "enemy": en.id})
	return out


## Un tir d'arme à feu depuis `origin` vers `dir` (définition `w` de data/weapons.json). Chaque projectile suit sa ligne : il touche
## le premier ennemi (ou tous, si la balle traverse) et le premier tonneau ou caisse de son chemin. Renvoie comme `swing`
## [{gold, at, killed, enemy}] et, pour les objets cassés, [{prop, kind, at}].
func shoot(origin: Vector2, dir: Vector2, w: Dictionary) -> Array:
	var out: Array = []
	var pellets := int(w.get("pellets", 1))
	var spread := float(w.get("spread", 0.0))
	var reach := float(w.get("range", 10.0))
	var dmg := int(w.get("damage", 1))
	var power := float(w.get("knock", 2.0))
	var pierce := bool(w.get("pierce", false))
	for p in pellets:
		var d := dir.rotated(_rng.randf_range(-spread, spread)) if spread > 0.0 else dir
		var stop := reach   # distance où le projectile s'arrête (premier obstacle touché)
		# les ennemis le long de la ligne, du plus proche au plus lointain
		var cands: Array = []
		for en in enemies:
			if en.is_dead():
				continue
			var to := en.pos - origin
			var along := to.dot(d)
			if along < 0.0 or along > reach:
				continue
			if absf(to.cross(d)) < 0.4 * float(en.cfg["scale"]) + 0.2:
				cands.append([along, en])
		cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for c: Array in cands:
			if float(c[0]) > stop:
				break
			var en2: IslandEnemy = c[1]
			var killed := en2.hurt(dmg, origin, power * GameConfig.GUN_KNOCK_SCALE, true)   # (13/11 : petit recul, il continue d'avancer)
			var gold := 0
			if killed:
				var g: Array = en2.cfg["gold"]
				gold = _rng.randi_range(int(g[0]), int(g[1]))
				en2.timer = respawn_secs
			out.append({"gold": gold, "at": en2.pos, "killed": killed, "enemy": en2.id})
			if not pierce:
				stop = float(c[0])
				break
		# le premier tonneau ou la première caisse touché(e) avant `stop`
		var best_k := -1
		var best_along := stop
		for k in breakables.size():
			var b: Dictionary = breakables[k]
			if b["broken"]:
				continue
			var tb: Vector2 = (b["pos"] as Vector2) - origin
			var al := tb.dot(d)
			if al < 0.0 or al > best_along:
				continue
			if absf(tb.cross(d)) < 0.5:
				best_along = al
				best_k = k
		if best_k >= 0:
			var bb: Dictionary = breakables[best_k]
			bb["hp"] = int(bb["hp"]) - dmg
			if int(bb["hp"]) <= 0:
				_break(best_k)
				out.append({"gold": 0, "at": bb["pos"], "killed": false, "enemy": -1, "prop": true, "kind": bb["kind"]})
			else:
				_wobble(best_k)
	return out


# ------------------------------------------------------------------ tonneaux et caisses

## Un coup depuis `origin` vers `dir` (portée `reach`, demi-ouverture `half_arc` en rad, PI = tout autour) abîme les tonneaux et
## caisses à portée. Renvoie [{pos, kind}] de ceux qui cèdent. À appeler chez l'hôte (ou en solo).
func hit_breakables(origin: Vector2, dir: Vector2, reach: float, half_arc: float, dmg: int = 1) -> Array:
	var out: Array = []
	for k in breakables.size():
		var b: Dictionary = breakables[k]
		if b["broken"]:
			continue
		var to: Vector2 = (b["pos"] as Vector2) - origin
		var d := to.length()
		if d > reach + 0.45:
			continue
		if d > 0.6 and half_arc < PI and absf(dir.angle_to(to)) > half_arc:
			continue
		b["hp"] = int(b["hp"]) - dmg
		if int(b["hp"]) <= 0:
			_break(k)
			out.append({"pos": b["pos"], "kind": b["kind"]})
		else:
			_wobble(k)
	return out


## Ce que lâche un tonneau ou une caisse brisé : liste de genres de butin (voir WorldLoot) : « plank », « ball », « g:<or> »,
## « t:<trésor> » (une caisse rarement). Il y a toujours au moins une planche ou un boulet.
func prop_loot(kind: String) -> Array:
	var out: Array = []
	var crate := kind == "crate"
	if _rng.randf() < (0.8 if crate else 0.55):
		for n in _rng.randi_range(1, 3 if crate else 2):
			out.append("plank")
	if _rng.randf() < (0.7 if crate else 0.5):
		for n in _rng.randi_range(1, 3 if crate else 2):
			out.append("ball")
	if _rng.randf() < (0.35 if crate else 0.2):
		out.append("g:%d" % (_rng.randi_range(8, 20) if crate else _rng.randi_range(3, 9)))
	if crate and _rng.randf() < 0.06:
		out.append("t:" + Treasure.roll(_rng, 0.8))
	if out.is_empty():
		out.append("plank" if _rng.randf() < 0.5 else "ball")
	return out


func _break(k: int) -> void:
	var b: Dictionary = breakables[k]
	b["broken"] = true
	b["timer"] = BREAK_RESPAWN
	_set_block(k, false)
	_break_visual(k)


func _restore(k: int) -> void:
	var b: Dictionary = breakables[k]
	b["broken"] = false
	b["hp"] = int(BREAKABLE[str(b["kind"])])
	b["timer"] = 0.0
	_set_block(k, true)
	if b["node"] != null:
		(b["node"] as Node3D).visible = true


## Un objet cassé ne bloque plus le passage (chez l'hôte comme chez les clients), et bloque de nouveau quand il se reforme.
func _set_block(k: int, on: bool) -> void:
	var b: Dictionary = breakables[k]
	var blk: Vector3 = b["block"]
	if blk == Vector3.INF:
		return
	var arr: Array = (islands[int(b["island"])] as Dictionary)["blockers_c"]
	var entry := [blk.x, -blk.y, blk.z]
	if on:
		if not arr.has(blk):
			arr.append(blk)
		if _land_ref != null and not _land_ref.circles.has(entry):
			_land_ref.circles.append(entry)
	else:
		arr.erase(blk)
		if _land_ref != null:
			_land_ref.circles.erase(entry)


## Un petit tremblement quand le coup ne suffit pas (la caisse tient encore).
func _wobble(k: int) -> void:
	var n := (breakables[k] as Dictionary)["node"] as Node3D
	if n == null:
		return
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(1.12, 0.9, 1.12), 0.06)
	tw.tween_property(n, "scale", Vector3.ONE, 0.12)


## Éclats de bois : l'objet disparaît, des planchettes giclent et retombent.
func _break_visual(k: int) -> void:
	var b: Dictionary = breakables[k]
	var n := b["node"] as Node3D
	if n != null:
		n.visible = false
	if _root == null:
		return
	var at: Vector2 = b["pos"]
	var y := ground_h(at)
	for c in 10:
		var chip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.28, 0.05, 0.08)
		chip.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = IslandDecor.WOOD if c % 2 == 0 else IslandDecor.WOOD_D
		chip.material_override = m
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(chip)
		chip.position = Vector3(at.x, y + 0.5, at.y)
		chip.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.7, 1.9)
		var tw := chip.create_tween()
		tw.set_parallel(true)
		tw.tween_property(chip, "position:x", at.x + dir.x, 0.5)
		tw.tween_property(chip, "position:z", at.y + dir.z, 0.5)
		tw.tween_property(chip, "position:y", y + randf_range(1.0, 1.7), 0.22).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(chip, "position:y", y + 0.05, 0.28).set_ease(Tween.EASE_IN)
		tw.chain().tween_interval(0.6)
		tw.chain().tween_callback(chip.queue_free)


func nearest_chest(p: Vector2) -> int:
	var best := -1
	var best_d := CHEST_REACH
	for k in chests.size():
		var ch: Dictionary = chests[k]
		if ch["open"]:
			continue
		var d := (ch["pos"] as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best = k
	return best


## Ouvre le coffre `k` ; renvoie l'or qu'il contenait, ou -1 s'il était déjà ouvert.
func open_chest(k: int) -> int:
	if k < 0 or k >= chests.size():
		return -1
	var ch: Dictionary = chests[k]
	if ch["open"]:
		return -1
	ch["open"] = true
	ch["timer"] = chest_respawn_secs
	return int(ch["gold"])


# ------------------------------------------------------------------ baies des dieux

func _berry_record(island: int, at: Vector2, berry: String, dropped: bool) -> Dictionary:
	return {"island": island, "pos": at, "berry": berry, "taken": false, "timer": 0.0, "dropped": dropped,
			"node": null, "fruit": null, "glint": null}


func _build_berry_node(k: int) -> void:
	var s: Dictionary = berry_spots[k]
	if _root == null or s["node"] != null or (s["dropped"] and s["taken"]):
		return
	var made := IslandDecor.berry_spot(_root, s["pos"], BerryBook.color_of(str(s["berry"])), not s["dropped"], k)
	(made["root"] as Node3D).position.y = ground_h(s["pos"])
	s["node"] = made["root"]
	s["fruit"] = made["fruit"]
	s["glint"] = made["glint"]
	(made["fruit"] as Node3D).visible = s["dropped"] and not s["taken"]


## La baie cueillable la plus proche de `p` (indice dans berry_spots), ou -1.
func nearest_berry(p: Vector2) -> int:
	var best := -1
	var best_d := BERRY_REACH
	for k in berry_spots.size():
		var s: Dictionary = berry_spots[k]
		if s["taken"]:
			continue
		var d := (s["pos"] as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best = k
	return best


## Cueille la baie `k` ; renvoie son identifiant, ou « » si elle n'est plus là.
func take_berry(k: int) -> String:
	if k < 0 or k >= berry_spots.size():
		return ""
	var s: Dictionary = berry_spots[k]
	if s["taken"]:
		return ""
	s["taken"] = true
	s["timer"] = BERRY_RESPAWN
	_hide_taken_berry(s)
	return str(s["berry"])


## Une baie lâchée à terre en `pos` (le pirate en a mangé une autre). Renvoie son indice.
func drop_berry(id: String, pos: Vector2) -> int:
	# elle tombe à 1,9 m du pirate, sur la terre ferme et hors de portée de cueillette (sinon il la rechangerait aussitôt)
	var at := pos
	var i0 := island_at(pos, 2.0)
	if i0 >= 0:
		for a in 8:
			var cand := pos + Vector2.from_angle(TAU * a / 8.0) * (BERRY_REACH + 0.3)
			if island_at(cand, 0.0) >= 0 and walkable(i0, cand, 0.3):
				at = cand
				break
	var s := _berry_record(island_at(at, 2.0), at, id, true)
	berry_spots.append(s)
	_build_berry_node(berry_spots.size() - 1)
	return berry_spots.size() - 1


func _hide_taken_berry(s: Dictionary) -> void:
	if s["node"] == null:
		return
	if s["dropped"]:
		(s["node"] as Node3D).queue_free()
		s["node"] = null
		s["fruit"] = null
	else:
		(s["fruit"] as Node3D).visible = false


## Chaque image : les baies cachées scintillent quand on s'approche, et (chez l'hôte) repoussent après un moment.
func update_berries(delta: float, p: Vector2, authority: bool) -> void:
	for s: Dictionary in berry_spots:
		if s["taken"]:
			if authority and not s["dropped"]:
				s["timer"] = float(s["timer"]) - delta
				if float(s["timer"]) <= 0.0:
					s["taken"] = false
			continue
		var fruit := s["fruit"] as Node3D
		if fruit == null:
			continue
		if not s["dropped"]:
			fruit.visible = (s["pos"] as Vector2).distance_to(p) < BERRY_REVEAL
		if fruit.visible:
			fruit.rotation.y += delta * 1.4
			(s["glint"] as Node3D).position.y = 0.55 + sin(_time * 3.0 + (s["pos"] as Vector2).x) * 0.08


# ------------------------------------------------------------------ sorts des baies

## Hôte (ou solo) : un sort lancé depuis `origin` vers `dir`. Blesse les ennemis atteints ; renvoie [{gold, at, killed, enemy}]
## comme `swing`. Les effets sur le lanceur lui-même (soin, bouclier, ruée) sont appliqués chez lui.
func cast(spell: Dictionary, origin: Vector2, dir: Vector2) -> Array:
	var out: Array = []
	var kind := str(spell.get("kind", ""))
	var dmg := int(spell.get("damage", 0))
	if dmg <= 0 or not kind in ["bolt", "nova", "cone", "dash", "pull"]:
		return out
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.DOWN
	for en in enemies:
		if en.is_dead():
			continue
		var to: Vector2 = en.pos - origin
		var body := 0.4 * float(en.cfg["scale"])
		var power := float(spell.get("knock", 2.0))
		var hit := false
		match kind:
			"bolt":
				var along := to.dot(d)
				hit = along > -0.2 and along < float(spell.get("range", 8.0)) + body and absf(to.cross(d)) < float(spell.get("width", 0.6)) * 0.5 + body
				power = 2.6
			"nova", "pull":
				hit = to.length() <= float(spell.get("radius", 3.0)) + body
			"cone":
				hit = to.length() <= float(spell.get("range", 4.0)) + body and (to.length() < 0.3 or absf(d.angle_to(to)) <= deg_to_rad(float(spell.get("arc", 100.0)) * 0.5))
			"dash":
				var dist := float(spell.get("dist", 4.0))
				var along2 := clampf(to.dot(d), 0.0, dist)
				hit = (to - d * along2).length() < 0.9 + body
				power = 2.0
		if not hit:
			continue
		var killed := en.hurt(dmg, origin, power)
		var gold := 0
		if killed:
			var g: Array = en.cfg["gold"]
			gold = _rng.randi_range(int(g[0]), int(g[1]))
			en.timer = respawn_secs
		out.append({"gold": gold, "at": en.pos, "killed": killed, "enemy": en.id})
	# les sorts brisent aussi les tonneaux et les caisses sur leur passage
	var reach := 0.0
	var arc := PI
	match kind:
		"nova", "pull":
			reach = float(spell.get("radius", 3.0))
		"cone":
			reach = float(spell.get("range", 4.0))
			arc = deg_to_rad(float(spell.get("arc", 100.0)) * 0.5)
		"bolt":
			reach = float(spell.get("range", 8.0))
			arc = 0.12
		"dash":
			reach = float(spell.get("dist", 4.0))
			arc = 0.3
	for br: Dictionary in hit_breakables(origin, d, reach, arc, 2):
		out.append({"gold": 0, "at": br["pos"], "killed": false, "enemy": -1, "prop": true, "kind": br["kind"]})
	return out


## Effet visuel d'un sort (chez celui qui le lance). Un aplat translucide qui grandit puis s'efface.
func spawn_fx(spell: Dictionary, origin: Vector2, dir: Vector2, color: Color) -> void:
	if _root == null:
		return
	var kind := str(spell.get("kind", ""))
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.DOWN
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y := ground_h(origin) + 0.12
	var from_scale := Vector3.ONE
	var to_scale := Vector3.ONE
	var dur := 0.45
	match kind:
		"nova", "pull", "heal", "shield":
			var r := float(spell.get("radius", 1.6 if kind != "shield" else 1.2))
			var cyl := CylinderMesh.new()
			cyl.top_radius = 1.0
			cyl.bottom_radius = 1.0
			cyl.height = 0.05
			cyl.radial_segments = 24
			mi.mesh = cyl
			mi.position = Vector3(origin.x, y, origin.y)
			from_scale = Vector3(r, 1, r) * (1.0 if kind == "pull" else 0.2)
			to_scale = Vector3(r, 1, r) * (0.2 if kind == "pull" else 1.0)
			if kind == "shield":
				dur = float(spell.get("secs", 3.0)) * 0.25
		"cone":
			mi.mesh = _sector_mesh(float(spell.get("range", 4.0)), deg_to_rad(float(spell.get("arc", 100.0))))
			mi.position = Vector3(origin.x, y, origin.y)
			mi.rotation.y = atan2(d.x, d.y)
			from_scale = Vector3(0.4, 1, 0.4)
			dur = 0.3
		"bolt", "dash":
			var length := float(spell.get("range", spell.get("dist", 5.0)))
			var box := BoxMesh.new()
			box.size = Vector3(float(spell.get("width", 1.1)), 0.06, length)
			mi.mesh = box
			mi.position = Vector3(origin.x + d.x * length * 0.5, y, origin.y + d.y * length * 0.5)
			mi.rotation.y = atan2(d.x, d.y)
			from_scale = Vector3(1, 1, 0.15)
			dur = 0.28
		_:
			mi.queue_free()
			return
	mi.scale = from_scale
	_root.add_child(mi)
	_fx.append({"node": mi, "mat": mat, "t": 0.0, "dur": dur, "from": from_scale, "to": to_scale})


func _sector_mesh(radius: float, arc: float) -> ArrayMesh:
	var verts := PackedVector3Array([Vector3.ZERO])
	var steps := 10
	for i in steps + 1:
		var a := -arc * 0.5 + arc * float(i) / steps
		verts.append(Vector3(sin(a), 0.0, cos(a)) * radius)
	var idx := PackedInt32Array()
	for i in steps:
		idx.append_array([0, i + 1, i + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# ------------------------------------------------------------------ réseau

## L'état complet [e, c, b, br, chunks] (essais, premier envoi) : voir net_dynamic et net_static.
func net_state(interest: Array = []) -> Array:
	return [net_dynamic(interest)] + net_static()


## Ce qui bouge vite : les ennemis, sous forme de paires [indice, état]. `interest` : points du monde (le bateau, les joueurs à
## terre) ; seuls les ennemis des îles proches d'un de ces points sont envoyés (le message resterait sinon trop gros pour un
## paquet quand le monde grandit). Vide : tous.
func net_dynamic(interest: Array = []) -> Array:
	var e: Array = []
	for i in islands.size():
		var isl: Dictionary = islands[i]
		if not interest.is_empty():
			var near := false
			for p: Vector2 in interest:
				if p.distance_to(isl["center"]) <= float(isl["radius"]) + active_range + 80.0:
					near = true
					break
			if not near:
				continue
		for en_id: int in isl["enemies"]:
			e.append([en_id, enemies[en_id].net_state()])
	return e


## Ce qui change rarement : coffres ouverts, baies, tonneaux cassés, et les cases d'îles tirées au hasard déjà générées.
func net_static() -> Array:
	var c: Array = []
	for ch: Dictionary in chests:
		c.append(1 if ch["open"] else 0)
	var b: Array = []
	for s: Dictionary in berry_spots:
		var p: Vector2 = s["pos"]
		b.append([str(s["berry"]), p.x, p.y, 1 if s["taken"] else 0, 1 if s["dropped"] else 0])
	var br: Array = []
	for bk: Dictionary in breakables:
		br.append(1 if bk["broken"] else 0)
	return [c, b, br, chunk_order.duplicate(true)]


func apply_net(s: Array, snap: bool = false) -> void:
	apply_static(s.slice(1))
	apply_dynamic(s[0], snap)


## Client : les ennemis envoyés par l'hôte (paires [indice, état]) ; un indice inconnu (île pas encore refaite) est ignoré.
func apply_dynamic(e: Array, snap: bool = false) -> void:
	for pair: Array in e:
		var k := int(pair[0])
		if k >= 0 and k < enemies.size():
			enemies[k].apply_net(pair[1], snap)


## Client : coffres, baies, tonneaux et îles générées, tels que l'hôte les a. `s` = [c, b, br, chunks].
func apply_static(s: Array) -> void:
	if s.size() > 3:   # les îles tirées au hasard que l'hôte a déjà générées : on les refait, dans le même ordre
		for ck: Array in s[3]:
			ensure_chunk(Vector2i(int(ck[0]), int(ck[1])))
	var c: Array = s[0]
	for k in mini(c.size(), chests.size()):
		(chests[k] as Dictionary)["open"] = int(c[k]) == 1
	if s.size() > 2:
		var br: Array = s[2]
		for k in mini(br.size(), breakables.size()):
			var bk: Dictionary = breakables[k]
			var gone := int(br[k]) == 1
			if gone and not bk["broken"]:
				bk["broken"] = true
				_set_block(k, false)
				_break_visual(k)
			elif not gone and bk["broken"]:
				_restore(k)
	if s.size() > 1:
		var b: Array = s[1]
		for k in b.size():
			var r: Array = b[k]
			if k >= berry_spots.size():   # une baie lâchée par un autre joueur
				berry_spots.append(_berry_record(island_at(Vector2(float(r[1]), float(r[2])), 2.0), Vector2(float(r[1]), float(r[2])), str(r[0]), int(r[4]) == 1))
				_build_berry_node(berry_spots.size() - 1)
			var spot: Dictionary = berry_spots[k]
			var taken := int(r[3]) == 1
			if taken and not spot["taken"]:
				spot["taken"] = true
				_hide_taken_berry(spot)
			elif not taken and spot["taken"]:
				spot["taken"] = false


# ------------------------------------------------------------------ informations pour la carte

func chests_left(i: int) -> int:
	var n := 0
	for ch_id: int in (islands[i] as Dictionary)["chests"]:
		if not (chests[ch_id] as Dictionary)["open"]:
			n += 1
	return n


## Île vaincue : elle a des ennemis ou des coffres, et il n'en reste ni vivant ni fermé (voir Outpost).
func is_cleared(i: int) -> bool:
	var isl: Dictionary = islands[i]
	if (isl["enemies"] as Array).is_empty() and (isl["chests"] as Array).is_empty():
		return false
	return enemies_alive(i) == 0 and chests_left(i) == 0


func enemies_alive(i: int) -> int:
	var n := 0
	for en_id: int in (islands[i] as Dictionary)["enemies"]:
		if not enemies[en_id].is_dead():
			n += 1
	return n


## Indice de l'île dont le bord est à moins de `reveal_range` du point (le bateau), ou -1.
func island_in_sight(p: Vector2) -> Array:
	var out: Array = []
	for i in islands.size():
		var isl: Dictionary = islands[i]
		if p.distance_to(isl["center"]) <= float(isl["radius"]) + reveal_range:
			out.append(i)
	return out
