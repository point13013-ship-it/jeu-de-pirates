class_name HullDamage
extends RefCounted
## État de la coque d'un bateau : voies d'eau, planches clouées, eau dans la cale.
## Un choc (récif, quai, boulet) ouvre des voies d'eau sur des emplacements fixes le long des deux flancs ;
## chaque voie d'eau fait monter l'eau dans la cale ; on la bouche avec une planche et on écope.
## Tout est calculé ici, sans rien de graphique, pour être testé tel quel. Les valeurs de jeu viennent de
## data/hull.json.

const CONFIG_PATH := "res://data/hull.json"

var slots_per_side := 6
var span_start := -0.30        ## début de la cale, en fraction de la longueur du bateau (0 = milieu)
var span_end := 0.24
var inflow_per_leak := 0.008   ## part de la cale remplie par seconde et par voie d'eau
var bail_amount := 0.05        ## part de la cale vidée à chaque seau
var bail_cooldown := 0.35
var min_impact_speed := 1.6    ## m/s : en dessous, un contact ne casse rien
var impact_cooldown := 1.0
var speed_per_extra_leak := 2.2
var max_leaks_per_impact := 3
var cannon_leaks := 1
var speed_penalty := 0.45      ## perte de vitesse maximale quand la cale est pleine
var sink_water := 1.0
var walk_slow_in_water := 0.35

var length := 16.0             ## longueur du bateau (unités du modèle)
var leaks := 0                 ## masque de bits : voies d'eau ouvertes
var patched := 0               ## masque de bits : voies d'eau bouchées par une planche
var water := 0.0               ## 0..sink_water


## Lit data/hull.json (dictionnaire vide si le fichier manque : les valeurs par défaut servent).
static func load_config() -> Dictionary:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func configure(cfg: Dictionary, ship_length: float) -> void:
	slots_per_side = int(cfg.get("slots_per_side", slots_per_side))
	span_start = float(cfg.get("span_start", span_start))
	span_end = float(cfg.get("span_end", span_end))
	inflow_per_leak = float(cfg.get("inflow_per_leak", inflow_per_leak))
	bail_amount = float(cfg.get("bail_amount", bail_amount))
	bail_cooldown = float(cfg.get("bail_cooldown", bail_cooldown))
	min_impact_speed = float(cfg.get("min_impact_speed", min_impact_speed))
	impact_cooldown = float(cfg.get("impact_cooldown", impact_cooldown))
	speed_per_extra_leak = float(cfg.get("speed_per_extra_leak", speed_per_extra_leak))
	max_leaks_per_impact = int(cfg.get("max_leaks_per_impact", max_leaks_per_impact))
	cannon_leaks = int(cfg.get("cannon_leaks", cannon_leaks))
	speed_penalty = float(cfg.get("speed_penalty", speed_penalty))
	sink_water = float(cfg.get("sink_water", sink_water))
	walk_slow_in_water = float(cfg.get("walk_slow_in_water", walk_slow_in_water))
	length = ship_length


# ------------------------------------------------------------------ emplacements


func slot_count() -> int:
	return slots_per_side * 2


## +1 : bâbord (y > 0 dans le repère du modèle), -1 : tribord. Les emplacements 0..N-1 sont à bâbord.
func slot_side(slot: int) -> int:
	return 1 if slot < slots_per_side else -1


## Rang de l'emplacement le long de la cale, de l'arrière (0) à l'avant (N-1).
func slot_rank(slot: int) -> int:
	return slot % slots_per_side


## Abscisse (repère du modèle) du centre de l'emplacement.
func slot_bx(slot: int) -> float:
	var a := span_start * length
	var b := span_end * length
	return a + (float(slot_rank(slot)) + 0.5) * (b - a) / float(slots_per_side)


## Emplacement le plus proche d'un impact à l'abscisse `bx`, du côté `side` (+1 bâbord, -1 tribord).
func slot_for_impact(bx: float, side: int) -> int:
	var a := span_start * length
	var b := span_end * length
	var rank := clampi(int(floorf((bx - a) / (b - a) * float(slots_per_side))), 0, slots_per_side - 1)
	return rank if side >= 0 else rank + slots_per_side


# ------------------------------------------------------------------ voies d'eau


func has_leak(slot: int) -> bool:
	return (leaks >> slot) & 1 == 1


func is_patched(slot: int) -> bool:
	return (patched >> slot) & 1 == 1


func leak_count() -> int:
	var n := 0
	for s in slot_count():
		if has_leak(s):
			n += 1
	return n


## Nombre de voies d'eau ouvertes par un choc à la vitesse `speed` (0 si le contact est trop doux).
func leaks_for_speed(speed: float) -> int:
	if absf(speed) < min_impact_speed:
		return 0
	return clampi(1 + int((absf(speed) - min_impact_speed) / speed_per_extra_leak), 1, max_leaks_per_impact)


## Ouvre `count` voies d'eau autour de l'impact : l'emplacement visé d'abord, puis ses voisins de proche en
## proche, sur le même flanc. Renvoie les emplacements ouverts (moins que demandé si le flanc est plein).
func add_leaks(bx: float, side: int, count: int) -> Array[int]:
	var opened: Array[int] = []
	var center := slot_for_impact(bx, side)
	var base := 0 if side >= 0 else slots_per_side
	var rank := slot_rank(center)
	var d := 0
	while opened.size() < count and d < slots_per_side:
		for r in ([rank] if d == 0 else [rank - d, rank + d]):
			if r < 0 or r >= slots_per_side or opened.size() >= count:
				continue
			var slot: int = base + r
			if not has_leak(slot):
				leaks |= 1 << slot
				patched &= ~(1 << slot)
				opened.append(slot)
		d += 1
	return opened


## Bouche la voie d'eau `slot` avec une planche. Renvoie false s'il n'y avait rien à boucher.
func patch(slot: int) -> bool:
	if slot < 0 or slot >= slot_count() or not has_leak(slot):
		return false
	leaks &= ~(1 << slot)
	patched |= 1 << slot
	return true


# ------------------------------------------------------------------ eau


## Fait monter l'eau de `dt` secondes.
func step(dt: float) -> void:
	water = minf(sink_water, water + float(leak_count()) * inflow_per_leak * dt)


## Un seau d'eau jeté par-dessus bord. Renvoie false si la cale était déjà sèche.
func bail() -> bool:
	if water <= 0.0:
		return false
	water = maxf(0.0, water - bail_amount)
	return true


func is_sunk() -> bool:
	return water >= sink_water


## Facteur sur la vitesse du bateau : 1 à sec, 1 - speed_penalty cale pleine.
func speed_factor() -> float:
	return 1.0 - speed_penalty * clampf(water / sink_water, 0.0, 1.0)


## Part de la cale remplie, 0..1.
func fill() -> float:
	return clampf(water / sink_water, 0.0, 1.0)


## Remet la coque à neuf.
func reset() -> void:
	leaks = 0
	patched = 0
	water = 0.0


## Reprend l'état reçu de l'hôte.
func apply_state(p_leaks: int, p_patched: int, p_water: float) -> void:
	leaks = p_leaks
	patched = p_patched
	water = p_water
