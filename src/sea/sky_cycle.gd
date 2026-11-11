class_name SkyCycle
extends RefCounted
## Le ciel : l'heure du jour (soleil, couleurs du crépuscule, nuit de lune) et la météo (brume, pluie, orage avec éclairs).
## L'heure et le temps se déduisent de l'horloge : tous les joueurs voient donc le même ciel, sans rien envoyer sur le réseau.
## Le jeu appelle `update` à chaque image ; `night`, `rain`, `storm` et `mist` servent aussi aux sons et à la vie des îles.

const DAY_SECS := 1500.0        ## s : durée d'un jour complet (25 minutes)
const WEATHER_SECS := 360.0     ## s : le temps est retiré toutes les 6 minutes
const FADE := 0.08              ## vitesse du changement de temps (par seconde)

const DAY_AMBIENT := Color(0.52, 0.60, 0.80)
const DAY_SUN := Color(1.0, 0.90, 0.72)
const DUSK_AMBIENT := Color(0.60, 0.50, 0.70)
const DUSK_SUN := Color(1.0, 0.58, 0.34)
const NIGHT_AMBIENT := Color(0.30, 0.36, 0.66)
const NIGHT_SUN := Color(0.55, 0.68, 1.0)
const GREY := Color(0.50, 0.54, 0.62)

var night := false
var daylight := 1.0
var rain := 0.0
var storm := 0.0
var mist := 0.0
var flash := 0.0                 ## éclair en cours (0…1)
var lightning := false           ## vrai à l'image où un éclair part (le jeu lance alors le tonnerre)
var enabled := true
var grade := {}                  ## étalonnage de l'image pour le filtre (voir _compute_grade)
var phase := 0.4               ## heure du jour, 0…1 (0,5 = midi, 0 = minuit)

var _env: Environment
var _sun: DirectionalLight3D
var _rain_fx: CPUParticles3D
var _fixed_phase := -1.0
var _fixed_weather := ""
var _flash_t := 8.0
var _target := Vector3.ZERO      ## météo visée : x = brume, y = pluie, z = orage


func setup(env: Environment, sun: DirectionalLight3D, world: Node3D, args: Dictionary) -> void:
	_env = env
	_sun = sun
	if args.has("tod"):
		_fixed_phase = float(str(args["tod"]))
	elif args.has("light"):   # ancien réglage d'essai : --light=jour / nuit
		_fixed_phase = 0.42 if str(args["light"]) == "jour" else 0.02
	if args.has("weather"):
		_fixed_weather = str(args["weather"])
	enabled = not args.has("no-cycle")
	_rain_fx = CPUParticles3D.new()
	_rain_fx.amount = 420
	_rain_fx.lifetime = 0.75
	_rain_fx.preprocess = 0.8
	_rain_fx.local_coords = false
	_rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain_fx.emission_box_extents = Vector3(15.0, 0.5, 13.0)
	_rain_fx.direction = Vector3(0.18, -1.0, 0.05)
	_rain_fx.spread = 2.0
	_rain_fx.initial_velocity_min = 24.0
	_rain_fx.initial_velocity_max = 28.0
	_rain_fx.gravity = Vector3.ZERO
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.7, 0.025)
	_rain_fx.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.78, 0.88, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rain_fx.material_override = m
	_rain_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_fx.emitting = false
	world.add_child(_rain_fx)
	_apply(0.0)
	# on démarre directement dans le temps du moment
	var t := _weather_target()
	mist = t.x
	rain = t.y
	storm = t.z


func _time_now() -> float:
	return Time.get_unix_time_from_system()


## Le temps du moment (brume, pluie, orage), tiré de l'horloge : le même pour tout le monde.
func _weather_target() -> Vector3:
	match _fixed_weather:
		"clear", "beau":
			return Vector3.ZERO
		"mist", "brume":
			return Vector3(1.0, 0.0, 0.0)
		"rain", "pluie":
			return Vector3(0.35, 1.0, 0.0)
		"storm", "orage":
			return Vector3(0.45, 1.0, 1.0)
	var slot := int(_time_now() / WEATHER_SECS)
	var r := float(absi(hash(slot * 7919 + 13)) % 1000) / 1000.0
	if r < 0.62:
		return Vector3.ZERO
	if r < 0.78:
		return Vector3(1.0, 0.0, 0.0)
	if r < 0.92:
		return Vector3(0.35, 1.0, 0.0)
	return Vector3(0.45, 1.0, 1.0)


## Chaque image. `focus` : le point de la scène que la caméra regarde (la pluie le suit).
func update(delta: float, focus: Vector3, paused: bool = false) -> void:
	lightning = false
	var t := _weather_target()
	mist = move_toward(mist, t.x, FADE * delta * 2.0)
	rain = move_toward(rain, t.y, FADE * delta * 2.0)
	storm = move_toward(storm, t.z, FADE * delta * 2.0)
	phase = _fixed_phase if _fixed_phase >= 0.0 else fmod(_time_now(), DAY_SECS) / DAY_SECS
	if storm > 0.5:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash_t = randf_range(7.0, 20.0)
			flash = 1.0
			lightning = true
	flash = maxf(flash - delta * 3.5, 0.0)
	if _rain_fx != null:
		_rain_fx.position = focus + Vector3(0.0, 13.0, 0.0)
		_rain_fx.emitting = rain > 0.05 and not paused
		var want := int(lerpf(60.0, 460.0, clampf(rain * (0.55 + 0.45 * storm), 0.0, 1.0)))
		if absi(want - _rain_fx.amount) > 50:   # (changer le nombre de gouttes relance l'émetteur : on ne le fait que par paliers)
			_rain_fx.amount = want
	if enabled and not paused:
		_apply(delta)


func _apply(_delta: float) -> void:
	var sun_h := sin((phase - 0.25) * TAU)          # 1 à midi, -1 à minuit
	daylight = smoothstep(-0.05, 0.45, sun_h)
	night = sun_h < 0.02
	var dusk := 1.0 - clampf(absf(sun_h - 0.06) / 0.26, 0.0, 1.0)
	var oc := clampf(maxf(maxf(mist * 0.55, rain * 0.75), storm), 0.0, 1.0)
	var amb := NIGHT_AMBIENT.lerp(DAY_AMBIENT, daylight).lerp(DUSK_AMBIENT, dusk * 0.7)
	var sun_c := NIGHT_SUN.lerp(DAY_SUN, daylight).lerp(DUSK_SUN, dusk * 0.85)
	var sun_e := lerpf(0.75, 1.9, daylight) * lerpf(1.0, 0.82, dusk)
	var amb_e := lerpf(1.1, 0.88, daylight)
	amb = amb.lerp(GREY, oc * 0.55)
	sun_e *= 1.0 - 0.55 * oc
	_env.ambient_light_color = amb
	_env.ambient_light_energy = amb_e + 1.8 * flash
	_env.background_color = Color(0.04, 0.05, 0.12).lerp(Color(0.10, 0.10, 0.22), daylight)
	_sun.light_color = sun_c
	_sun.light_energy = sun_e + 1.6 * flash
	# soleil haut à midi, bas le matin et le soir ; la lune garde une hauteur moyenne
	var elev := lerpf(14.0, 52.0, clampf(sun_h, 0.0, 1.0)) if sun_h > 0.0 else 48.0
	_sun.rotation_degrees = Vector3(-elev, -40.0, 0.0)
	# la brume : un voile uniforme qui délave tout
	var fog_amount := clampf(mist + rain * 0.35, 0.0, 1.0)
	_env.fog_enabled = fog_amount > 0.02
	_env.fog_light_color = Color(0.25, 0.28, 0.40).lerp(Color(0.74, 0.80, 0.84), daylight)
	_env.fog_density = 0.0004 + 0.0018 * fog_amount   # le gros de la brume est dans le filtre d'image (nuages de brume animés)
	_env.fog_sun_scatter = 0.0
	# lueur (bloom) : discrète le jour, nette la nuit pour les lanternes et les fenêtres
	_env.glow_enabled = true
	_env.glow_intensity = lerpf(0.95, 0.35, daylight)
	_env.glow_bloom = lerpf(0.10, 0.02, daylight)
	_env.glow_hdr_threshold = lerpf(0.85, 1.0, daylight)
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_compute_grade(daylight, dusk, fog_amount)


## Étalonnage de l'image (lu par le jeu et envoyé au filtre) : lumière chaude et ombres froides le jour, or et violet
## au crépuscule, nuit de lune bleue et contrastée, brume en nuages qui dérivent, orage sombre et délavé.
func _compute_grade(day: float, dusk: float, fog_amount: float) -> void:
	var tint := Vector3(0.80, 0.90, 1.06).lerp(Vector3(1.03, 1.0, 0.95), day)
	tint = tint.lerp(Vector3(1.13, 0.94, 0.84), dusk * 0.85)
	var shadow := Vector3(0.0, 0.012, 0.055).lerp(Vector3(0.0, 0.008, 0.035), day)
	shadow = shadow.lerp(Vector3(0.035, 0.0, 0.075), dusk)
	var high := Vector3(0.0, 0.02, 0.07).lerp(Vector3(0.045, 0.028, 0.0), day)
	high = high.lerp(Vector3(0.11, 0.05, -0.02), dusk)
	var sat := lerpf(0.66, 1.12, day) + 0.1 * dusk
	var con := lerpf(1.12, 1.06, day) + 0.04 * dusk
	var vig := lerpf(0.55, 0.2, day) + 0.1 * dusk
	var haze_c := Vector3(0.11, 0.14, 0.24).lerp(Vector3(0.80, 0.85, 0.88), day)
	haze_c = haze_c.lerp(Vector3(0.95, 0.66, 0.58), dusk * 0.5)
	var dark := clampf(maxf(storm, rain * 0.6), 0.0, 1.0)
	tint *= 1.0 - 0.3 * dark
	sat *= 1.0 - 0.28 * dark - 0.12 * mist
	con *= 1.0 - 0.1 * mist
	vig += 0.25 * dark
	haze_c = haze_c.lerp(Vector3(0.30, 0.33, 0.40) * lerpf(0.4, 1.0, day), dark * 0.7)
	grade = {
		"tint": tint, "shadow": shadow, "high": high, "sat": sat, "contrast": con, "vignette": vig,
		"haze_color": haze_c, "haze": fog_amount * 0.62,
	}
