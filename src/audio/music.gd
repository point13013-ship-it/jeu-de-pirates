class_name Music
extends Node
## Le jukebox : fabrique les trois airs (MusicSynth) dans un fil à part, puis joue celui qui va avec la situation, avec un
## fondu enchaîné : « mer » au large, « escale » à terre, « combat » quand l'ennemi est là. Les airs arrivent un par un ;
## tant que celui voulu n'est pas prêt, on joue un autre déjà prêt (ou rien).

const FADE_SECS := 3.5
const BASE := 0.55               ## volume de base d'un air (le curseur de musique s'applique en plus, via le bus)

var _tracks: Dictionary = {}     ## id -> AudioStreamWAV, rempli par le fil
var _mutex := Mutex.new()
var _thread: Thread
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _playing_id := ""
var _want := "mer"
var _level := 0.0                ## 0…1 : volume de l'air en cours (monte et descend aux fondus)
var _fading_out: AudioStreamPlayer
var _fade_out_level := 0.0
var enabled := true


func start() -> void:
	_a = _make_player()
	_b = _make_player()
	_active = _a
	_thread = Thread.new()
	_thread.start(_build_all)


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = AudioSettings.BUS_MUSIC
	p.volume_db = -80.0
	add_child(p)
	return p


func _build_all() -> void:
	for id: String in MusicSynth.IDS:
		var stream := MusicSynth.build(id)
		_mutex.lock()
		_tracks[id] = stream
		_mutex.unlock()


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func ready_ids() -> Array:
	_mutex.lock()
	var ids := _tracks.keys()
	_mutex.unlock()
	return ids


## `mood` : "mer", "escale" ou "combat" ; `duck` : 0…1, on baisse la musique (pluie forte, menu, cale…).
func update(delta: float, mood: String, duck: float = 1.0) -> void:
	if _thread == null:
		return
	_want = mood
	_mutex.lock()
	var wanted: AudioStreamWAV = _tracks.get(_want)
	var fallback: AudioStreamWAV = null
	var fallback_id := ""
	for id: String in _tracks:
		fallback = _tracks[id]
		fallback_id = id
		break
	_mutex.unlock()
	var target_id := _want
	var target: AudioStreamWAV = wanted
	if target == null:   # l'air voulu n'est pas encore fabriqué : on garde celui qui joue, sinon un autre prêt
		target_id = _playing_id if _playing_id != "" else fallback_id
		target = _tracks.get(target_id) if target_id != "" else null
	if target != null and target_id != _playing_id:
		# fondu enchaîné : l'ancien air s'éteint, le nouveau (sur l'autre lecteur) monte
		if _playing_id != "":
			_fading_out = _active
			_fade_out_level = _level
		_active = _b if _active == _a else _a
		_active.stream = target
		_active.play(randf() * 4.0 if _playing_id == "" else 0.0)
		_playing_id = target_id
		_level = 0.0
	if _playing_id != "":
		_level = move_toward(_level, 1.0, delta / FADE_SECS)
		_active.volume_db = linear_to_db(maxf(_level * BASE * duck, 0.0001))
	if _fading_out != null:
		_fade_out_level = move_toward(_fade_out_level, 0.0, delta / FADE_SECS)
		_fading_out.volume_db = linear_to_db(maxf(_fade_out_level * BASE * duck, 0.0001))
		if _fade_out_level <= 0.0:
			_fading_out.stop()
			_fading_out = null


func current() -> String:
	return _playing_id
