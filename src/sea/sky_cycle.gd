class_name SkyCycle
extends RefCounted
## Le ciel : l'heure du jour (soleil, couleurs du crépuscule, nuit de lune) et la météo (brume, pluie, orage avec éclairs).
## L'heure et le temps se déduisent de l'horloge : tous les joueurs voient donc le même ciel, sans rien envoyer sur le réseau.
## Le jeu appelle `update` à chaque image ; `night`, `rain`, `storm` et `mist` servent aussi aux sons et à la vie des îles.

const DAY_SECS := GameConfig.DAY_SECS            ## s : durée d'un jour complet (lot 6 : 25 -> 35 minutes)
const WEATHER_SECS := GameConfig.WEATHER_SECS    ## s : le temps est retiré à chaque tranche
const FADE := 0.08              ## vitesse du changement de temps (par seconde)
const FOG_CAM_DIST := 60.0      ## m : distance de la caméra au point qu'elle regarde (voir SailingGame._update_camera)

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
var swell := 0.0                 ## force de la houle (0 : mer calme … 1 : tempête) : vagues, tangage, caméra, son de coque, maniabilité
var flash := 0.0                 ## éclair en cours (0…1)
var lightning := false           ## vrai à l'image où un éclair part (le jeu lance alors le tonnerre)
var enabled := true
var grade := {}                  ## étalonnage de l'image pour le filtre (voir _compute_grade)
var phase := 0.4               ## heure du jour, 0…1 (0,5 = midi, 0 = minuit)

var _env: Environment
var _sun: DirectionalLight3D
var _rain_fx: GPUParticles3D
var _splash_fx: GPUParticles3D
var sea_y := -1.45               ## hauteur de la mer dans la scène (SailingGame.SEA_Y) : la pluie finit là, les impacts y naissent
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
	if args.has("swell"):
		args_swell = clampf(float(str(args["swell"])), 0.0, 1.0)
	enabled = not args.has("no-cycle")
	_build_rain(world)
	_apply(0.0)
	# on démarre directement dans le temps du moment
	var t := _weather_target()
	mist = t.x
	rain = t.y
	storm = t.z
	swell = swell_target()


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
	# lot 6 (8.2) : moins souvent du mauvais temps, et moins longtemps (il ne dure qu'une partie de sa tranche)
	var now := _time_now()
	var slot := int(now / WEATHER_SECS)
	var r := float(absi(hash(slot * 7919 + 13)) % 1000) / 1000.0
	var into := fmod(now, WEATHER_SECS) / WEATHER_SECS
	var w: Dictionary = GameConfig.WEATHER_ODDS
	var c_clear := float(w["clear"])
	var c_mist := c_clear + float(w["mist"])
	var c_rain := c_mist + float(w["rain"])
	if r < c_clear:
		return Vector3.ZERO
	if r < c_mist:
		return Vector3(1.0, 0.0, 0.0) if into < float(GameConfig.WEATHER_SHARE["mist"]) else Vector3.ZERO
	if r < c_rain:
		return Vector3(0.35, 1.0, 0.0) if into < float(GameConfig.WEATHER_SHARE["rain"]) else Vector3.ZERO
	return Vector3(0.45, 1.0, 1.0) if into < float(GameConfig.WEATHER_SHARE["storm"]) else Vector3.ZERO


## La houle visée (lot 3, 3.7) : elle suit le gros temps (pluie, orage). Comme le reste du temps, elle se déduit de l'horloge :
## tous les joueurs ont la même mer. (Le lot 6 y ajoute des périodes de houle plus forte hors tempête.)
func swell_target() -> float:
	if args_swell >= 0.0:
		return args_swell
	var t := _weather_target()
	# lot 6 (8.3) : hors tempête, des périodes de houle plus forte (tirées de l'horloge, les mêmes pour tous)
	var now := _time_now()
	var sslot := int(now / GameConfig.SWELL_PERIOD)
	var roll := float(absi(hash(sslot * 104729 + 7)) % 1000) / 1000.0
	var swell_period := 0.0
	if roll < GameConfig.SWELL_ODDS:
		var into := fmod(now, GameConfig.SWELL_PERIOD) / GameConfig.SWELL_PERIOD
		swell_period = GameConfig.SWELL_PERIOD_STRENGTH * sin(PI * clampf(into, 0.0, 1.0))   # elle monte puis retombe
	return clampf(maxf(maxf(t.z, t.y * GameConfig.SWELL_FROM_RAIN), swell_period), 0.0, 1.0)


var args_swell := -1.0           ## essai : --swell=0.8 fixe la houle


## Lot 6 (8.1) : le nom du moment de la journée (Aube, Matin, Midi, Après-midi, Soir, Crépuscule, Nuit).
func moment() -> String:
	var name := "Nuit"
	for m: Array in GameConfig.DAY_MOMENTS:
		if phase >= float(m[0]):
			name = str(m[1])
	return name


## Chaque image. `focus` : le point de la scène que la caméra regarde (la pluie le suit).
func update(delta: float, focus: Vector3, paused: bool = false) -> void:
	lightning = false
	var t := _weather_target()
	mist = move_toward(mist, t.x, FADE * delta * 2.0)
	rain = move_toward(rain, t.y, FADE * delta * 2.0)
	storm = move_toward(storm, t.z, FADE * delta * 2.0)
	swell = move_toward(swell, swell_target(), GameConfig.SWELL_FADE * delta)
	phase = _fixed_phase if _fixed_phase >= 0.0 else fmod(_time_now(), DAY_SECS) / DAY_SECS
	if storm > 0.5:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash_t = randf_range(7.0, 20.0)
			flash = 1.0
			lightning = true
	flash = maxf(flash - delta * 3.5, 0.0)
	if _rain_fx != null:
		# La pluie couvre toute la vue (mer, îles, autres bateaux) : un grand carré centré sur ce que regarde la caméra, pas une
		# colonne au-dessus du bateau. Les gouttes vivent dans le monde (elles ne suivent pas le bateau une fois lâchées) et
		# finissent à la surface de la mer, où naissent les impacts.
		var on := rain > 0.05 and not paused
		var density := clampf(rain * (0.55 + 0.45 * storm), 0.0, 1.0)
		_rain_fx.position = Vector3(focus.x, sea_y + GameConfig.RAIN_TOP, focus.z)
		_rain_fx.emitting = on
		_rain_fx.amount_ratio = lerpf(0.08, 1.0, density)   # (amount_ratio : la densité change sans relancer l'émetteur)
		_splash_fx.position = Vector3(focus.x, sea_y + 0.03, focus.z)
		_splash_fx.emitting = on
		_splash_fx.amount_ratio = lerpf(0.08, 1.0, density)
	if enabled and not paused:
		_apply(delta)


## La pluie (bug 1.6) : des traits de pluie sur tout le carré GameConfig.RAIN_AREA autour de la vue, et des impacts (petits anneaux
## clairs qui s'ouvrent et s'éteignent) à la surface de la mer. Particules calculées par la carte graphique : des milliers de gouttes
## sans coût notable pour le processeur.
func _build_rain(world: Node3D) -> void:
	var half := GameConfig.RAIN_AREA * 0.5
	var fall := GameConfig.RAIN_FALL_SPEED
	_rain_fx = GPUParticles3D.new()
	_rain_fx.amount = GameConfig.RAIN_DROPS
	_rain_fx.lifetime = GameConfig.RAIN_TOP / fall   # elles meurent en touchant la mer
	_rain_fx.preprocess = _rain_fx.lifetime
	_rain_fx.local_coords = false
	_rain_fx.visibility_aabb = AABB(Vector3(-half, -GameConfig.RAIN_TOP - 2.0, -half), Vector3(half * 2.0, GameConfig.RAIN_TOP + 4.0, half * 2.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(half, 0.4, half)
	pm.direction = Vector3(0.12, -1.0, 0.04)
	pm.spread = 1.5
	pm.initial_velocity_min = fall * 0.95
	pm.initial_velocity_max = fall * 1.05
	pm.gravity = Vector3.ZERO
	pm.particle_flag_align_y = true   # chaque trait dans le sens de sa chute
	_rain_fx.process_material = pm
	var bm := BoxMesh.new()
	bm.size = Vector3(GameConfig.RAIN_DROP_WIDTH, GameConfig.RAIN_DROP_LENGTH, GameConfig.RAIN_DROP_WIDTH)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.80, 0.90, 1.0, GameConfig.RAIN_ALPHA)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# LA cause du bug 1.6 : la surface de la mer est transparente et passait devant la pluie au tri des objets transparents ;
	# on ne voyait donc les gouttes qu'au-dessus du bateau et des rochers. La pluie est dessinée après la mer.
	m.render_priority = GameConfig.RAIN_RENDER_PRIORITY
	bm.material = m
	_rain_fx.draw_pass_1 = bm
	_rain_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_fx.emitting = false
	world.add_child(_rain_fx)
	# impacts sur l'eau : un petit anneau à plat qui s'agrandit en s'effaçant
	_splash_fx = GPUParticles3D.new()
	_splash_fx.amount = GameConfig.RAIN_SPLASHES
	_splash_fx.lifetime = 0.35
	_splash_fx.local_coords = false
	_splash_fx.visibility_aabb = AABB(Vector3(-half, -1.0, -half), Vector3(half * 2.0, 2.0, half * 2.0))
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(half, 0.0, half)
	sp.gravity = Vector3.ZERO
	sp.initial_velocity_min = 0.0
	sp.initial_velocity_max = 0.0
	sp.scale_min = 0.6
	sp.scale_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	sp.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.75))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	sp.color_ramp = fade_tex
	_splash_fx.process_material = sp
	var ring := TorusMesh.new()
	ring.inner_radius = 0.07
	ring.outer_radius = 0.11
	ring.rings = 10
	ring.ring_segments = 3
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.86, 0.94, 1.0)
	rm.vertex_color_use_as_albedo = true   # (le dégradé d'effacement passe par la couleur des particules)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.render_priority = GameConfig.RAIN_RENDER_PRIORITY
	ring.material = rm
	_splash_fx.draw_pass_1 = ring
	_splash_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_splash_fx.emitting = false
	world.add_child(_splash_fx)


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
	# (prototype de refonte : en lumière à paliers, la face éclairée prend tout le soleil d'un coup ; on le tempère pour ne pas
	# « brûler » les couleurs claires, et on renforce l'ambiance froide qui colore les ombres)
	if ToonLook.enabled:
		sun_e *= GameConfig.TOON_SUN_SCALE
		_env.ambient_light_energy *= GameConfig.TOON_AMBIENT_SCALE
	_sun.light_energy = sun_e + 1.6 * flash
	# soleil haut à midi, bas le matin et le soir ; la lune garde une hauteur moyenne
	var elev := lerpf(14.0, 52.0, clampf(sun_h, 0.0, 1.0)) if sun_h > 0.0 else 48.0
	_sun.rotation_degrees = Vector3(-elev, -40.0, 0.0)
	# la brume (12/11, refaite : « le brouillard est vraiment mal fait », un voile blanc uniforme sur tout l'écran). Elle est
	# maintenant dans la 3D, comme dans les jeux actuels :
	# - brume de profondeur : nette autour du pirate, elle s'épaissit vers le lointain (le haut de l'écran). La caméra est
	#   toujours à FOG_CAM_DIST m du point visé : la brume commence un peu avant ce point et devient opaque au loin ;
	# - brume basse : plus dense au ras de l'eau, les mâts et les toits en sortent.
	var fog_amount := clampf(mist + rain * 0.35, 0.0, 1.0)
	_env.fog_enabled = fog_amount > 0.02
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_light_color = Color(0.22, 0.26, 0.38).lerp(Color(0.70, 0.77, 0.82), daylight)
	_env.fog_light_energy = 1.0
	_env.fog_density = clampf(GameConfig.FOG_DENSITY_BASE + GameConfig.FOG_DENSITY_GAIN * fog_amount, 0.0, 0.95)   # opacité maximale au loin
	_env.fog_depth_begin = FOG_CAM_DIST - lerpf(2.0, 8.0, fog_amount)
	_env.fog_depth_end = FOG_CAM_DIST + lerpf(70.0, 18.0, fog_amount)
	_env.fog_depth_curve = 1.6
	_env.fog_height = 1.5
	_env.fog_height_density = 0.12 * fog_amount
	_env.fog_sun_scatter = 0.0
	_env.fog_aerial_perspective = 0.0
	# tout au loin (au-delà de la mer dessinée, en vue rasante) : la couleur de la brume plutôt qu'un fond sombre
	_env.background_color = _env.fog_light_color.darkened(0.15)
	_env.fog_enabled = true
	_env.fog_density = maxf(_env.fog_density, 0.35)
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
		"warm_keep": GameConfig.NIGHT_WARM_KEEP * (1.0 - day),
		"haze_color": haze_c, "haze": fog_amount * GameConfig.FOG_SCREEN_BANKS,   # (13/11 : coupés, ils s'amassaient d'un côté en traînées opaques)
	}
