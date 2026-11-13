class_name AudioSettings
extends RefCounted
## Les volumes du joueur : général, musique, ambiance (mer, vent, oiseaux, feu, pluie) et effets (pas, éclaboussures…).
## Trois bus audio (créés ici au besoin) sous le bus principal ; les réglages sont gardés dans user://audio.json.

const PATH := "user://audio.json"
static var path := PATH   ## (les essais le détournent pour ne pas toucher aux réglages du joueur)
const BUS_MUSIC := "Musique"
const BUS_AMBIENT := "Ambiance"
const BUS_SFX := "Effets"
const KEYS := ["master", "music", "ambient", "sfx", "rain"]   # (13/11 : « rain » n'est pas un bus : un volume à part pour la pluie)
const LABELS := {"master": "Volume général", "music": "Musique", "ambient": "Ambiance (mer, vent, oiseaux…)", "sfx": "Effets (pas, éclaboussures…)", "rain": "Pluie"}
const DEFAULTS := {"master": 1.0, "music": 0.7, "ambient": 0.9, "sfx": 0.9, "rain": 0.8}

static var volumes: Dictionary = DEFAULTS.duplicate()
static var _inited := false


## À appeler au lancement : crée les bus, lit le fichier de réglages et l'applique (une seule fois).
static func setup() -> void:
	if _inited:
		return
	_inited = true
	for bus_name: String in [BUS_MUSIC, BUS_AMBIENT, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				for k: String in KEYS:
					if (data as Dictionary).has(k):
						volumes[k] = clampf(float((data as Dictionary)[k]), 0.0, 1.0)
	apply()


## 13/11 (Jimmy : « dans la cale, la mer et les boulets plus étouffés ») : `k` de 0 (dehors) à 1 (dans la cale). Un filtre
## passe-bas sur l'ambiance (la mer, le vent, la pluie) et sur les bruitages (canons, chocs) : les aigus s'éteignent.
static var _muffle_fx: Dictionary = {}


static func set_muffle(k: float) -> void:
	for spec: Array in [[BUS_AMBIENT, 1500.0], [BUS_SFX, 3800.0]]:
		var idx := AudioServer.get_bus_index(str(spec[0]))
		if idx < 0:
			continue
		if not _muffle_fx.has(spec[0]):
			var fx := AudioEffectLowPassFilter.new()
			fx.cutoff_hz = 20000.0
			AudioServer.add_bus_effect(idx, fx)
			_muffle_fx[spec[0]] = fx
		var f := _muffle_fx[spec[0]] as AudioEffectLowPassFilter
		f.cutoff_hz = 20000.0 * pow(float(spec[1]) / 20000.0, clampf(k, 0.0, 1.0))


static func bus_of(key: String) -> String:
	match key:
		"music":
			return BUS_MUSIC
		"ambient":
			return BUS_AMBIENT
		"sfx":
			return BUS_SFX
		_:
			return "Master"


static func apply() -> void:
	for k: String in KEYS:
		if k == "rain":
			continue   # (lu par l'ambiance, voir Ambience : rain_gain)
		var idx := AudioServer.get_bus_index(bus_of(k))
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, to_db(float(volumes[k])))


## Un curseur de 0 à 1 → décibels ; le milieu du curseur reste confortable (courbe en carré), 0 = silence.
static func to_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v * v)


## Le volume de la pluie choisi par le joueur (0…1, courbe en carré comme les autres curseurs).
static func rain_gain() -> float:
	var v := float(volumes.get("rain", 0.8))
	return v * v / 0.64   # (0,8, la valeur par défaut, laisse le mixage tel qu'il est réglé)


static func set_volume(key: String, v: float, save_now: bool = true) -> void:
	volumes[key] = clampf(v, 0.0, 1.0)
	apply()
	if save_now:
		save()


static func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(volumes, "\t"))
