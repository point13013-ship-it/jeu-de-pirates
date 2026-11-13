class_name Music
extends Node
## Le jukebox. La musique suit la situation (« état ») : « mer » au large, « escale » à terre, « tempete » sous l'orage,
## « combat » quand l'ennemi est là.
##
## 13/11 — au calme, la musique respire (réglages GameConfig.MUSIC_FIRST_GAP_*, MUSIC_CHANGE_*, MUSIC_SOFT_IN, MUSIC_SWELL_*,
## MUSIC_CUT_*) : du silence au début de la partie ; un morceau entre tout doucement, monte lentement jusqu'à son volume ; une
## fois sur trois il s'éteint avant sa fin ; puis du silence, puis un autre. Changer de lieu (accoster, reprendre la mer, sortir
## d'un combat) éteint le morceau en cours et laisse un silence au lieu d'enchaîner aussitôt sur le thème suivant. Seuls le
## combat et les requins entrent tout de suite.
##
## Pratiques reprises du son de jeu (voir design/refonte-journal.md, « Son ») :
## - Pas de musique en continu au calme : un morceau, puis un silence de MUSIC_GAP_MIN à MUSIC_GAP_MAX s (on n'entend que la mer
##   et le vent), puis un autre morceau du même état, jamais le même deux fois de suite. Évite la lassitude.
## - En changeant d'état (on accoste, la tempête se lève), le nouveau thème démarre tout de suite, en fondu enchaîné.
## - Combat : musique continue ; elle entre vite (MUSIC_FADE_COMBAT_IN) et ne s'arrête qu'après MUSIC_COMBAT_EXIT s sans combat
##   (hystérésis : pas de va-et-vient quand un ennemi sort et revient de portée), avec un fondu lent.
##
## Morceaux : res://assets/audio/music/<état>_1.ogg, _2… (Epidemic Sound). Un état sans fichier garde l'air fabriqué
## (MusicSynth), joué en boucle comme avant.

const DIR := "res://assets/audio/music/"
const STATES := ["mer", "escale", "combat", "tempete", "requins"]
const CONTINUOUS := ["combat", "requins"]   ## états sans silence entre deux morceaux (la tension ne retombe pas)
const BASE := 0.55               ## volume de base d'un air (le curseur de musique s'applique en plus, via le bus)

var _files: Dictionary = {}      ## état -> Array[String] (chemins des morceaux)
var _tracks: Dictionary = {}     ## id -> AudioStreamWAV (airs fabriqués, en secours), rempli par le fil
var _mutex := Mutex.new()
var _thread: Thread
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _playing_id := ""            ## état du morceau en cours (ou "" : silence)
var _last_file: Dictionary = {}  ## état -> dernier morceau joué (pour ne pas le rejouer tout de suite)
var _level := 0.0                ## 0…1 : volume du morceau en cours (monte et descend aux fondus)
var _fade_in := 3.0
var _fading_out: AudioStreamPlayer
var _fade_out_level := 0.0
var _fade_out_secs := 3.0
var _combat_boost := 0.0         ## 1 à l'entrée en combat, retombe à 0 : la musique arrive fort puis se pose
var _track_gain := 1.0           ## volume du morceau en cours (tiré à son départ)
var _gap := 0.0                  ## s de silence restant avant le prochain morceau
var _swell := 1.0                ## 0…1 : montée lente du morceau en cours (au calme)
var _played := 0.0               ## s depuis le départ du morceau en cours
var _cut_at := INF               ## s : le morceau en cours s'éteint à ce moment (INF : joué en entier)
var _state := ""                 ## état voulu (après hystérésis du combat)
var _combat_hold := 0.0
var _punch := 0.0               ## 0…1 : creux de volume après un coup de canon (« ducking »)
var _tops: Dictionary = {}       ## lecteur principal -> son lecteur « couche du dessus » (la mélodie du combat)
var _picked_top: AudioStream     ## couche du dessus du dernier morceau choisi (null : morceau d'un seul tenant)
var _top_gain := 0.0             ## 0…1 : volume de la couche du dessus (suit l'intensité du combat, lissé)
var enabled := true


func start() -> void:
	_a = _make_player()
	_b = _make_player()
	_active = _a
	_tops[_a] = _make_player()
	_tops[_b] = _make_player()
	for st: String in STATES:
		var list: Array = []
		for k in range(1, 13):
			var path := "%s%s_%d.ogg" % [DIR, st, k]
			if not ResourceLoader.exists(path):
				break
			list.append(path)
		_files[st] = list
	_thread = Thread.new()
	_thread.start(_build_all)


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = AudioSettings.BUS_MUSIC
	p.volume_db = -80.0
	add_child(p)
	return p


## Les airs fabriqués ne servent qu'aux états sans fichier.
func _build_all() -> void:
	for id: String in MusicSynth.IDS:
		if not (_files.get(id, []) as Array).is_empty():
			continue
		var stream := MusicSynth.build(id)
		_mutex.lock()
		_tracks[id] = stream
		_mutex.unlock()


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func ready_ids() -> Array:
	var ids: Array = []
	for st: String in _files:
		if not (_files[st] as Array).is_empty():
			ids.append(st)
	_mutex.lock()
	ids.append_array(_tracks.keys())
	_mutex.unlock()
	return ids


## `mood` : "mer", "escale", "tempete" ou "combat" ; `duck` : 0…1, on baisse la musique (menu, cale…).
## `intensity` : 0…1, l'ardeur du combat (ennemis engagés, leur rang, coups reçus). Musique « verticale » : un morceau livré en
## pistes séparées joue l'accompagnement, et la mélodie s'y ajoute quand le combat se corse.
func update(delta: float, mood: String, duck: float = 1.0, intensity: float = 0.0) -> void:
	if _thread == null:
		return
	# un coup de canon creuse la musique (GameConfig.MUSIC_DUCK_DB), qui remonte en MUSIC_DUCK_RELEASE s
	_punch = move_toward(_punch, 0.0, delta / GameConfig.MUSIC_DUCK_RELEASE)
	duck *= db_to_linear(GameConfig.MUSIC_DUCK_DB * _punch)
	var top_target := smoothstep(GameConfig.MUSIC_LAYER_FROM, GameConfig.MUSIC_LAYER_FULL, intensity)
	_top_gain = move_toward(_top_gain, top_target,
			delta / (GameConfig.MUSIC_LAYER_IN if top_target > _top_gain else GameConfig.MUSIC_LAYER_OUT))
	# hystérésis du combat : on y entre tout de suite, on n'en sort qu'après un moment de calme
	if mood == "combat":
		_combat_hold = GameConfig.MUSIC_COMBAT_EXIT
	else:
		_combat_hold = maxf(_combat_hold - delta, 0.0)
	var want := "combat" if _combat_hold > 0.0 else mood
	# 13/11 (2.3) : la musique de combat arrive plus fort que le reste, puis redescend à son niveau en MUSIC_COMBAT_BOOST_TIME s
	_combat_boost = move_toward(_combat_boost, 0.0, delta / GameConfig.MUSIC_COMBAT_BOOST_TIME)
	if want == "combat" and _state != "combat":
		_combat_boost = 1.0
	if want != _state:
		var was := _state
		_state = want
		if want in CONTINUOUS:
			# le danger entre tout de suite
			_gap = 0.0
			_switch_to(want, GameConfig.MUSIC_FADE_COMBAT_IN if want == "combat" else GameConfig.MUSIC_FADE, GameConfig.MUSIC_FADE)
		else:
			# au calme : le morceau en cours s'éteint, puis un silence avant le thème du nouveau lieu
			_fade_to_silence(GameConfig.MUSIC_FADE_COMBAT_OUT if was == "combat" else GameConfig.MUSIC_CHANGE_FADE)
			_gap = randf_range(GameConfig.MUSIC_FIRST_GAP_MIN, GameConfig.MUSIC_FIRST_GAP_MAX) if was == "" \
					else randf_range(GameConfig.MUSIC_CHANGE_GAP_MIN, GameConfig.MUSIC_CHANGE_GAP_MAX)
	elif _playing_id != "" and _active.playing and _played >= _cut_at:
		# un morceau écourté : il s'éteint lentement, puis le silence ordinaire entre deux morceaux
		_fade_to_silence(GameConfig.MUSIC_CUT_FADE)
		_gap = randf_range(GameConfig.MUSIC_GAP_MIN, GameConfig.MUSIC_GAP_MAX)
	elif _playing_id != "" and not _active.playing:
		# le morceau est fini : silence, puis un autre (le combat et les airs fabriqués enchaînent sans pause)
		_playing_id = ""
		_gap = 0.0 if (_state in CONTINUOUS or _files_of(_state).is_empty()) \
				else randf_range(GameConfig.MUSIC_GAP_MIN, GameConfig.MUSIC_GAP_MAX)
	elif _playing_id == "":
		_gap -= delta
		if _gap <= 0.0:
			_switch_to(_state, GameConfig.MUSIC_FADE if _state in CONTINUOUS else GameConfig.MUSIC_SOFT_IN, GameConfig.MUSIC_FADE)
	if _playing_id != "":
		_played += delta
		_swell = move_toward(_swell, 1.0, delta / GameConfig.MUSIC_SWELL_TIME)
		_level = move_toward(_level, 1.0, delta / maxf(_fade_in, 0.05))
		var push := (GameConfig.MUSIC_COMBAT_GAIN + GameConfig.MUSIC_COMBAT_BOOST * _combat_boost) if _state == "combat" else 1.0
		push *= lerpf(GameConfig.MUSIC_SWELL_FROM, 1.0, smoothstep(0.0, 1.0, _swell))
		_active.volume_db = linear_to_db(maxf(_level * BASE * duck * _track_gain * push, 0.0001))
		(_tops[_active] as AudioStreamPlayer).volume_db = linear_to_db(maxf(_level * BASE * duck * _top_gain * _track_gain * push, 0.0001))
	if _fading_out != null:
		_fade_out_level = move_toward(_fade_out_level, 0.0, delta / maxf(_fade_out_secs, 0.05))
		_fading_out.volume_db = linear_to_db(maxf(_fade_out_level * BASE * duck, 0.0001))
		(_tops[_fading_out] as AudioStreamPlayer).volume_db = linear_to_db(maxf(_fade_out_level * BASE * duck * _top_gain, 0.0001))
		if _fade_out_level <= 0.0:
			_fading_out.stop()
			(_tops[_fading_out] as AudioStreamPlayer).stop()
			_fading_out = null


func _files_of(st: String) -> Array:
	return _files.get(st, []) as Array


## Le morceau en cours s'éteint en `secs` s, sans rien lancer après (le silence).
func _fade_to_silence(secs: float) -> void:
	if _playing_id != "" and _active.playing:
		_fading_out = _active
		_fade_out_level = _level * lerpf(GameConfig.MUSIC_SWELL_FROM, 1.0, smoothstep(0.0, 1.0, _swell))
		_fade_out_secs = secs
		_active = _b if _active == _a else _a
	_playing_id = ""


## Fondu enchaîné vers un morceau de l'état `st` (l'ancien s'éteint en `fade_out` s, le nouveau monte en `fade_in` s).
func _switch_to(st: String, fade_in: float, fade_out: float) -> void:
	var stream := _pick(st)
	if _playing_id != "" and _active.playing:
		_fading_out = _active
		_fade_out_level = _level
		_fade_out_secs = fade_out
		_active = _b if _active == _a else _a
	if stream == null:   # rien de prêt pour cet état (air fabriqué pas encore fini) : silence, on réessaie bientôt
		_playing_id = ""
		_gap = 1.0
		return
	_active.stream = stream
	var top := _tops[_active] as AudioStreamPlayer
	top.stop()
	top.stream = _picked_top
	top.volume_db = -80.0
	_active.play()
	if _picked_top != null:
		top.play()   # même longueur, même départ : les deux couches restent calées
	_playing_id = st
	_level = 0.0
	# 13/11 : chaque morceau a son volume (au calme, de 55 % à 100 % : certains passent en fond, d'autres au premier plan) ;
	# le combat et la tempête restent pleins
	_track_gain = 1.0 if st in CONTINUOUS else randf_range(GameConfig.MUSIC_TRACK_GAIN_MIN, 1.0)
	# au calme : le morceau part bas et monte lentement ; une fois sur trois il ne sera pas joué en entier
	_played = 0.0
	_swell = 1.0 if st in CONTINUOUS else 0.0
	_cut_at = INF
	if not (st in CONTINUOUS) and randf() < GameConfig.MUSIC_CUT_CHANCE \
			and stream.get_length() > GameConfig.MUSIC_CUT_MAX + GameConfig.MUSIC_CUT_FADE + 15.0:
		_cut_at = randf_range(GameConfig.MUSIC_CUT_MIN, GameConfig.MUSIC_CUT_MAX)
	_fade_in = fade_in


## Un morceau de l'état, jamais celui d'avant ; sinon l'air fabriqué (en boucle) ; sinon null.
func _pick(st: String) -> AudioStream:
	_picked_top = null
	var list := _files_of(st)
	if not list.is_empty():
		var choices := list.duplicate()
		if choices.size() > 1:
			choices.erase(_last_file.get(st, ""))
		var path: String = choices[randi() % choices.size()]
		_last_file[st] = path
		# livré en pistes séparées (stems/<état>_N_instruments.ogg + _melody.ogg) : on le joue en deux couches
		var stem := DIR + "stems/" + path.get_file().get_basename()
		if ResourceLoader.exists(stem + "_instruments.ogg") and ResourceLoader.exists(stem + "_melody.ogg"):
			_picked_top = load(stem + "_melody.ogg") as AudioStream
			path = stem + "_instruments.ogg"
		var s := load(path) as AudioStreamOggVorbis
		if s != null and st in CONTINUOUS:
			s = s.duplicate() as AudioStreamOggVorbis
			s.loop = false   # (le combat enchaîne les morceaux : fin de morceau -> pas de silence, un autre)
		return s
	_mutex.lock()
	var w: AudioStreamWAV = _tracks.get(st, _tracks.get("mer"))
	_mutex.unlock()
	return w


## Un son fort vient d'éclater (canon) : la musique se creuse un instant pour lui laisser la place.
func punch() -> void:
	_punch = 1.0


func current() -> String:
	return _playing_id
