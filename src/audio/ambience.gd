class_name Ambience
extends Node
## L'ambiance sonore : mer, vent, oiseaux, feu, pluie, pas… Tout est calculé ici d'après la position du joueur (à terre ou en
## mer) ; les sons eux-mêmes viennent de Synth. Aucun fichier audio. Le jeu appelle `update` à chaque image avec un contexte
## décrivant la situation (voir `update`) et `play_*` pour les sons ponctuels (coup, cueillette…).

const STEP_EVERY := 1.15       ## m parcourus entre deux pas
const MASTER_DB := -3.0

var master := 1.0              ## 0…1 : volume général (réglé par le menu)
var islands: IslandWorld
var _loops: Dictionary = {}    ## nom -> {player, vol (visé), cur (actuel)}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _bird_t := 3.0
var _gull_t := 6.0
var _creak_t := 9.0
var _thunder_t := 14.0
var _hull_splash_t := 2.0
var _step_acc := 0.0
var _step_flip := 0
var _near_t := 0.0
var _near := {"s": -99.0, "tone": "lush", "fire": INF}
var _rng := RandomNumberGenerator.new()


func setup(p_islands: IslandWorld) -> void:
	islands = p_islands
	_rng.randomize()
	for spec: Array in [["waves", Synth.waves()], ["wind", Synth.wind()], ["hull", Synth.hull()], ["fire", Synth.fire()], ["rain", Synth.rain()],
			["insects", Synth.insects()]]:
		var p := AudioStreamPlayer.new()
		p.stream = spec[1]
		p.volume_db = -80.0
		p.autoplay = false
		p.bus = AudioSettings.BUS_AMBIENT
		add_child(p)
		_loops[spec[0]] = {"player": p, "vol": 0.0, "cur": 0.0}
	for i in 8:
		var q := AudioStreamPlayer.new()
		add_child(q)
		_pool.append(q)


## Un son bref (à `vol` linéaire, hauteur `pitch`).
func play(stream: AudioStream, vol: float = 1.0, pitch: float = 1.0, bus: String = AudioSettings.BUS_SFX) -> void:
	if stream == null or vol <= 0.01 or master <= 0.01:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = linear_to_db(vol * master) + MASTER_DB
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


func play_chime() -> void:
	play(Synth.chime(), 0.7)


func play_rustle(vol: float = 0.8) -> void:
	play(Synth.rustle(), vol, _rng.randf_range(0.9, 1.1))


func play_splash(vol: float = 0.8) -> void:
	play(Synth.splash(), vol, _rng.randf_range(0.9, 1.15))


## Contexte attendu : pos (Vector2 monde), where ("land", "ship", "swim", "hold", "other"), speed (m/s), moved (m parcourus
## depuis la dernière image à pied), night (bool), rain (0…1), storm (0…1), muted (bool : menu, cale…).
func update(delta: float, ctx: Dictionary) -> void:
	if islands == null:
		return
	var pos: Vector2 = ctx["pos"]
	_near_t -= delta
	if _near_t <= 0.0:
		_near_t = 0.25
		_find_near(pos)
	var s: float = _near["s"]
	var tone: String = _near["tone"]
	var where := str(ctx.get("where", "ship"))
	var night := bool(ctx.get("night", false))
	var rain := float(ctx.get("rain", 0.0))
	var storm := float(ctx.get("storm", 0.0))
	var muted := bool(ctx.get("muted", false))
	var in_hold := where == "hold"
	# la mer : plus forte près du rivage, un fond discret au large (étouffée dans la cale)
	var near_coast := clampf(1.0 - absf(s + 1.0) / 14.0, 0.0, 1.0)
	var waves := 0.16 + 0.55 * near_coast + 0.18 * clampf(float(ctx.get("speed", 0.0)) / 8.0, 0.0, 1.0)
	if in_hold:
		waves *= 0.5
	# le vent : plus fort au large et sur les îles de morts, et par temps de tempête
	var wind := 0.30 if where != "land" else 0.18
	if tone == "dead" and s > -8.0:
		wind += 0.2
	wind += 0.35 * storm
	if in_hold:
		wind *= 0.4
	var land_life := s > -6.0 and where != "hold"
	var insects := 0.0
	if tone == "lush" and s > 2.0 and where == "land":
		insects = 0.16 if night else 0.1
	var fire := 0.0
	var fd: float = _near["fire"]
	if fd < 18.0 and where != "hold":
		fire = pow(1.0 - fd / 18.0, 1.6) * 0.8
	_vol("waves", 0.0 if muted else waves)
	_vol("wind", 0.0 if muted else wind)
	# la coque qui frotte les vagues : de plus en plus fort et aigu avec la vitesse du bateau (étouffée dans la cale, absente à terre et à la nage)
	var pace := clampf(float(ctx.get("speed", 0.0)) / 8.0, 0.0, 1.0)
	var swell := float(ctx.get("swell", 0.0))
	# lot 3 (3.8) : quasi muet à l'arrêt, fort à pleine vitesse ; la houle le renforce (la coque cogne les vagues)
	var hull := pow(pace, 1.3) * 0.75 + swell * GameConfig.HULL_SWELL_VOL * (0.3 + 0.7 * pace)
	if where == "land" or where == "swim":
		hull = 0.0
	elif in_hold:
		hull *= 0.55
	_vol("hull", 0.0 if muted else hull)
	((_loops["hull"] as Dictionary)["player"] as AudioStreamPlayer).pitch_scale = 0.8 + 0.5 * pace
	# des gerbes au hasard contre l'étrave : plus souvent et plus fort avec la vitesse et la houle (la boucle ne s'entend plus)
	if not muted and (where == "ship" or where == "hold" or where == "other") and pace > 0.08:
		_hull_splash_t -= delta * (0.4 + pace + swell)
		if _hull_splash_t <= 0.0:
			_hull_splash_t = _rng.randf_range(GameConfig.HULL_SPLASH_MIN, GameConfig.HULL_SPLASH_MAX)
			var v := (0.12 + 0.4 * pace + 0.2 * swell) * (0.5 if in_hold else 1.0)
			play(Synth.splash(), v, _rng.randf_range(0.8, 1.25), AudioSettings.BUS_AMBIENT)
	_vol("insects", 0.0 if muted else insects)
	_vol("fire", 0.0 if muted else fire)
	_vol("rain", 0.0 if muted else rain * (0.45 if in_hold else 0.8))
	_fade_loops(delta)
	if muted:
		return
	# sons ponctuels, tirés au hasard
	if land_life and tone == "lush" and not night:
		_bird_t -= delta
		if _bird_t <= 0.0:
			_bird_t = _rng.randf_range(2.5, 7.0)
			play(Synth.bird(_rng.randi() % 3), _rng.randf_range(0.18, 0.32), _rng.randf_range(0.9, 1.2), AudioSettings.BUS_AMBIENT)
	if s > -30.0 and s < 18.0 and not in_hold and not night:
		_gull_t -= delta
		if _gull_t <= 0.0:
			_gull_t = _rng.randf_range(7.0, 16.0)
			play(Synth.gull(), _rng.randf_range(0.18, 0.32), _rng.randf_range(0.9, 1.15), AudioSettings.BUS_AMBIENT)
	if tone == "dead" and s > 0.0 and where == "land":
		_creak_t -= delta
		if _creak_t <= 0.0:
			_creak_t = _rng.randf_range(8.0, 17.0)
			play(Synth.creak(), 0.25, _rng.randf_range(0.8, 1.15), AudioSettings.BUS_AMBIENT)
	# les pas
	var moved := float(ctx.get("moved", 0.0))
	if moved > 0.0001 and (where == "land" or where == "ship"):
		_step_acc += moved
		if _step_acc >= STEP_EVERY:
			_step_acc = 0.0
			_step_flip = (_step_flip + 1) % 3
			var kind := 2 if where == "ship" else (0 if (s < 3.4 or tone == "dead") else 1)
			if where == "land" and s < 0.2:
				kind = 3
			play(Synth.step(kind, _step_flip), 0.4, _rng.randf_range(0.92, 1.1))
	else:
		_step_acc = maxf(_step_acc, STEP_EVERY * 0.6)   # le premier pas part vite après l'arrêt


func _vol(name: String, vol: float) -> void:
	(_loops[name] as Dictionary)["vol"] = vol


func _fade_loops(delta: float) -> void:
	for name: String in _loops:
		var l: Dictionary = _loops[name]
		var cur := lerpf(float(l["cur"]), float(l["vol"]), 1.0 - exp(-delta * 1.8))
		l["cur"] = cur
		var p := l["player"] as AudioStreamPlayer
		if cur < 0.012:
			if p.playing:
				p.stop()
			continue
		if not p.playing:
			p.play(_rng.randf() * 2.0)
		p.volume_db = linear_to_db(cur * master) + MASTER_DB


## L'île la plus proche (distance signée au bord : positif dedans), sa nature et le feu de camp le plus proche.
func _find_near(pos: Vector2) -> void:
	var best_s := -99.0
	var best_tone := "lush"
	var fire := INF
	for i in islands.islands.size():
		var isl: Dictionary = islands.islands[i]
		var c: Vector2 = isl["center"]
		if pos.distance_to(c) > float(isl["radius"]) + 80.0:
			continue
		var s := islands.sdf(i, pos)
		if s > best_s:
			best_s = s
			best_tone = str(isl.get("tone", "lush"))
		for it: Dictionary in isl["items"]:
			if it["kind"] == "campfire":
				fire = minf(fire, pos.distance_to(it["pos"]))
	_near = {"s": best_s, "tone": best_tone, "fire": fire}
