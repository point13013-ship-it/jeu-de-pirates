class_name IslandGen
extends RefCounted
## Les îles tirées au hasard sur la route du bateau. Le monde est découpé en cases de CELL m de côté ; chaque case porte
## une île (ou rien) qui ne dépend que de ses coordonnées et de la graine du monde : tous les joueurs, et chaque nouvelle
## partie avec la même graine, voient les mêmes îles. Le résultat est un dictionnaire du même format que
## data/islands.json (centre, lobes, ennemis, coffres, accessoires, semis, relief, baies), prêt pour IslandWorld.

const CELL := 520.0               ## m : côté d'une case
const FILL := 0.55                ## probabilité qu'une case porte une île
const MARGIN := 150.0             ## m : une île reste à cette distance des bords de sa case (deux îles ne se touchent jamais)
const KEEP_OUT_ISLAND := 150.0    ## m : écart minimal au centre d'une île du fichier
const PORT_RECT := Rect2(-170.0, -150.0, 330.0, 270.0)   ## le port et ses abords : pas d'île générée ici
const BERRY_CHANCE := 0.04        ## une île sur 25 cache une baie des dieux : c'est le plus rare des trésors
const BERRY_IDS := ["aquilon", "ignis", "thalassa", "nyx", "gaia"]

const NAMES_A := ["de la Tortue", "du Perroquet", "du Requin", "du Corail", "du Kraken", "du Flibustier", "du Brouillard",
		"du Cormoran", "de la Mouette", "du Boucanier", "du Rhum", "du Lagon", "de l'Ancre", "du Naufrage", "de la Sirène",
		"du Hibou", "du Crabe Rouge", "de la Brume", "du Pélican", "du Vieux Marin", "de l'Albatros", "du Sable Noir"]
const BLURBS_LUSH := ["Une plage claire, des palmiers, et peut-être un coffre.", "Un coin tranquille, ou qui en a l'air.",
		"Des traces de pas sur le sable. Pas les vôtres."]
const BLURBS_DEAD := ["Rien ne pousse ici, sauf les ennuis.", "Des os blanchis par le soleil. Mauvais présage.",
		"Les mouettes évitent cet endroit."]


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


static func key_of(c: Vector2i) -> String:
	return "%d_%d" % [c.x, c.y]


## L'île de la case `c` pour la graine `world_seed`, ou {} s'il n'y en a pas. `avoid` : cercles (x, z, rayon) à éviter
## (îles du fichier, île déjà posée).
static func generate(c: Vector2i, world_seed: int, avoid: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d/%d/%d" % [world_seed, c.x, c.y])
	if rng.randf() > FILL:
		return {}
	var center := Vector2(
		float(c.x) * CELL + rng.randf_range(MARGIN, CELL - MARGIN),
		float(c.y) * CELL + rng.randf_range(MARGIN, CELL - MARGIN))
	if PORT_RECT.has_point(center):
		return {}
	for a: Vector3 in avoid:
		if center.distance_to(Vector2(a.x, a.y)) < a.z + KEEP_OUT_ISLAND:
			return {}
	# taille : îlot, île ou grande île
	var roll := rng.randf()
	var radius := rng.randf_range(13.0, 19.0) if roll < 0.3 else (rng.randf_range(24.0, 36.0) if roll < 0.8 else rng.randf_range(38.0, 52.0))
	var big := radius >= 24.0
	var tone := "dead" if rng.randf() < 0.28 else "lush"
	var danger := 0
	if radius >= 24.0:
		danger = 1 + (1 if rng.randf() < 0.55 else 0) + (1 if radius >= 38.0 and rng.randf() < 0.5 else 0)
	elif rng.randf() < 0.3:
		danger = 1
	if tone == "dead":
		danger = maxi(danger, 2)
	var lobes: Array = [[0.0, 0.0, radius]]
	var lobe_count := 1 if radius < 20.0 else rng.randi_range(2, 4)
	for k in lobe_count - 1:
		var a := rng.randf() * TAU
		var d := radius * rng.randf_range(0.55, 0.95)
		lobes.append([snappedf(cos(a) * d, 0.1), snappedf(sin(a) * d, 0.1), snappedf(radius * rng.randf_range(0.4, 0.7), 0.1)])
	var out := {
		"id": "proc_" + key_of(c),
		"name": "Île %s" % NAMES_A[rng.randi() % NAMES_A.size()],
		"blurb": (BLURBS_DEAD if tone == "dead" else BLURBS_LUSH)[rng.randi() % 3],
		"danger": danger,
		"tone": tone,
		"scale": 1.0,
		"center": [center.x, center.y],
		"lobes": lobes,
		"cliffs": 0.2 if big else 0.0,
	}
	var placed: Array = []   # points déjà pris [Vector2, rayon libre]
	# coffres : un de base, plus s'il y a du danger ; l'un d'eux sur un plateau s'il y en a un
	var plateaus: Array = []
	if big and rng.randf() < 0.75:
		var pp := _land_point(lobes, rng, radius * 0.3 + 4.0)
		if pp != Vector2.INF:
			var pr := clampf(radius * 0.2, 4.0, 8.0)
			plateaus.append({"at": [pp.x, pp.y], "r": pr, "h": 1.5, "ramp": {"angle": rng.randi_range(0, 359), "width": 50, "len": pr}})
			placed.append([pp, pr + 2.5])
	out["plateaus"] = plateaus
	var chests: Array = []
	if not plateaus.is_empty():
		chests.append({"at": plateaus[0]["at"], "gold": int(30 + 35 * danger + rng.randi_range(0, 30))})
	var extra_chests := 1 + (1 if big else 0) + (1 if danger >= 2 else 0) - chests.size()
	for k in maxi(extra_chests, 0):
		var cp := _free_point(lobes, rng, 3.5, placed, 4.0)
		if cp != Vector2.INF:
			chests.append({"at": [snappedf(cp.x, 0.1), snappedf(cp.y, 0.1)], "gold": int(20 + 30 * danger + rng.randi_range(0, 25))})
			placed.append([cp, 3.0])
	out["chests"] = chests
	# ennemis
	var enemies: Array = []
	var kinds: Array = ["crab"] if danger <= 1 else (["skeleton", "marine"] if tone == "dead" else ["marine", "crab", "skeleton"])
	var enemy_count := int(round(danger * 2.0 + radius / 12.0)) if danger > 0 else 0
	for k in enemy_count:
		var ep := _free_point(lobes, rng, 3.0, placed, 3.0)
		if ep != Vector2.INF:
			var kind: String = kinds[rng.randi() % kinds.size()]
			if danger >= 3 and k == 0:
				kind = "officer"
			enemies.append({"kind": kind, "at": [snappedf(ep.x, 0.1), snappedf(ep.y, 0.1)]})
			placed.append([ep, 2.5])
	out["enemies"] = enemies
	# accessoires
	var props: Array = []
	var prop_pool: Array = ["bones", "grave", "grave", "skull_rock"] if tone == "dead" else ["rowboat", "tent", "campfire", "bones", "sandcastle", "pond"]
	for k in (2 if radius < 20.0 else 4):
		var kind: String = prop_pool[rng.randi() % prop_pool.size()]
		var tight := 5.0 if kind in ["skull_rock", "pond", "tent"] else 3.0
		var pp2 := _free_point(lobes, rng, 3.0, placed, tight)
		if pp2 != Vector2.INF:
			props.append({"kind": kind, "at": [snappedf(pp2.x, 0.1), snappedf(pp2.y, 0.1)], "rot": rng.randi_range(0, 359)})
			placed.append([pp2, tight])
	# tonneaux et caisses : de quoi récolter des planches et des boulets
	var breakables := int(round(radius / 7.0)) + 1
	for k in breakables:
		var bp := _free_point(lobes, rng, 2.0, placed, 1.6)
		if bp != Vector2.INF:
			props.append({"kind": "barrel" if rng.randf() < 0.5 else "crate", "at": [snappedf(bp.x, 0.1), snappedf(bp.y, 0.1)]})
			placed.append([bp, 1.6])
	out["props"] = props
	var scatter := {
		"bush": int(radius / 2.2), "fern": int(radius / 2.8), "rock": int(radius / 7.0), "driftwood": 2,
	}
	if tone == "dead":
		scatter["dead_tree"] = int(radius / 4.0)
		scatter["rock_spire"] = int(radius / 9.0)
	else:
		scatter["palm"] = int(radius / 2.0)
	out["scatter"] = scatter
	# une baie des dieux, très rarement : cachée loin du bord
	if rng.randf() < BERRY_CHANCE:
		var bp2 := _free_point(lobes, rng, maxf(radius * 0.35, 5.0), placed, 3.0)
		if bp2 != Vector2.INF:
			out["berries"] = [{"berry": BERRY_IDS[rng.randi() % BERRY_IDS.size()], "at": [snappedf(bp2.x, 0.1), snappedf(bp2.y, 0.1)]}]
	return out


## Un point de terre (distance au bord au moins `min_sdf`), tiré au hasard, ou Vector2.INF.
static func _land_point(lobes: Array, rng: RandomNumberGenerator, min_sdf: float) -> Vector2:
	for attempt in 60:
		var l: Array = lobes[rng.randi() % lobes.size()]
		var a := rng.randf() * TAU
		var d := float(l[2]) * sqrt(rng.randf())
		var p := Vector2(float(l[0]) + cos(a) * d, float(l[1]) + sin(a) * d)
		if _sdf(lobes, p) >= min_sdf:
			return p
	return Vector2.INF


## Comme _land_point, en gardant `gap` m d'écart avec les points déjà posés (`placed` : [point, rayon]).
static func _free_point(lobes: Array, rng: RandomNumberGenerator, min_sdf: float, placed: Array, gap: float) -> Vector2:
	for attempt in 40:
		var p := _land_point(lobes, rng, min_sdf)
		if p == Vector2.INF:
			return Vector2.INF
		var ok := true
		for e: Array in placed:
			if p.distance_to(e[0]) < float(e[1]) + gap * 0.5:
				ok = false
				break
		if ok:
			return p
	return Vector2.INF


static func _sdf(lobes: Array, p: Vector2) -> float:
	var best := -INF
	for l: Array in lobes:
		best = maxf(best, float(l[2]) - Vector2(float(l[0]), float(l[1])).distance_to(p))
	return best
