class_name Atmosphere
extends Node
## Le coordinateur de l'ambiance : le ciel (heure, météo), les sons, la musique et la vie des îles. Le jeu n'a qu'un objet à tenir
## à jour : `update` à chaque image avec la situation du joueur, plus quelques événements (coup, ramassage, plongeon).

var sky := SkyCycle.new()
var life := IslandLife.new()
var audio := Ambience.new()
var music := Music.new()
var _prev_where := ""
var _thunder_in := -1.0
var _muted_by_player := false


## `sky_parent` : la scène (repère de la caméra : la pluie la suit) ; `life_parent` : le monde fixe (coordonnées des îles) ;
## `env` et `sun` : à piloter ; `args` : arguments d'essai du jeu.
func setup(sky_parent: Node3D, life_parent: Node3D, p_islands: IslandWorld, env: Environment, sun: DirectionalLight3D, args: Dictionary) -> void:
	AudioSettings.setup()
	sky.setup(env, sun, sky_parent, args)
	life.setup(p_islands)
	life_parent.add_child(life)
	audio.setup(p_islands)
	add_child(audio)
	add_child(music)
	if not args.has("no-music"):
		music.start()
	if args.has("mute"):
		_set_muted(true)


## Ctx : pos (Vector2 monde du joueur), where ("land", "ship", "swim", "hold", "other"), speed (m/s), moved (m à pied,
## cette image), face (Vector2), focus (Vector3 : ce que regarde la caméra), paused (bool : un menu ouvert), battle (bool : l'ennemi
## est là : bateau ennemi en chasse, ennemi d'île près du joueur).
func update(delta: float, ctx: Dictionary) -> void:
	var paused := bool(ctx.get("paused", false))
	var where := str(ctx.get("where", "ship"))
	sky.update(delta, ctx.get("focus", Vector3.ZERO), where == "hold")
	if sky.lightning:
		_thunder_in = randf_range(0.3, 1.4)
	if _thunder_in >= 0.0:
		_thunder_in -= delta
		if _thunder_in < 0.0:
			audio.play(Synth.thunder(), randf_range(0.7, 1.0), randf_range(0.85, 1.1), AudioSettings.BUS_AMBIENT)
	if where == "swim" and _prev_where != "swim" and _prev_where != "":
		var p: Vector2 = ctx["pos"]
		life.splash(p, 1.2)
		audio.play_splash(0.9)
	_prev_where = where
	var lctx := ctx.duplicate()
	lctx["night"] = sky.night
	lctx["rain"] = sky.rain
	lctx["storm"] = sky.storm
	life.update(delta, lctx)
	var actx := ctx.duplicate()
	actx["night"] = sky.night
	actx["rain"] = sky.rain
	actx["storm"] = sky.storm
	actx["swell"] = sky.swell
	actx["muted"] = paused
	audio.update(delta, actx)
	# la musique : l'air suit la situation, et se fait plus discrète sous l'orage, dans la cale ou quand un menu est ouvert
	var mood := "mer"
	if bool(ctx.get("battle", false)):
		mood = "combat"
	elif bool(ctx.get("sharks", false)):
		mood = "requins"   # des requins rôdent autour du nageur : musique angoissante, qui monte quand ils approchent
	elif where == "land":
		mood = "escale"
	elif sky.storm >= GameConfig.MUSIC_STORM_AT:
		mood = "tempete"
	var duck := 1.0
	if where == "hold":
		duck = 0.55
	if paused:
		duck *= 0.6
	duck *= 1.0 - 0.35 * sky.storm
	music.update(delta, mood, duck, float(ctx.get("intensity", 0.0)))


## Le joueur frappe de son sabre vers `dir` depuis `origin` : les palmiers et buissons devant lui frémissent.
func on_swing(origin: Vector2, dir: Vector2) -> void:
	if life.swing(origin, dir):
		audio.play_rustle(0.9)


## Coupe ou remet tout le son (touche M) : on coupe le bus principal.
func toggle_mute() -> bool:
	_set_muted(not _muted_by_player)
	return _muted_by_player


func _set_muted(on: bool) -> void:
	_muted_by_player = on
	AudioServer.set_bus_mute(0, on)
