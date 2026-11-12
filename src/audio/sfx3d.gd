class_name Sfx3D
extends Node3D
## Les bruitages placés dans le monde (lot 2) : un son part d'un point de la scène et s'entend d'autant moins qu'on en est loin,
## jusqu'à GameConfig.SFX_HEAR_RANGE où il s'éteint. L'oreille est le pirate du joueur (un AudioListener3D qui le suit), pas la
## caméra, qui est à 60 m au-dessus de la scène. Chaque joueur joue chez lui les sons des actions des autres (reçues par le
## réseau) à l'endroit où ils sont : un pote qui cloue une planche à l'autre bout du bateau s'entend de loin.
## Un petit lot de lecteurs réutilisés (pas de création de nœud à chaque son).

const POOL := 16

var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _listener: AudioListener3D
var _loops: Dictionary = {}   ## nom -> AudioStreamPlayer3D (sons qui durent : une action en cours)


func _ready() -> void:
	for i in POOL:
		var p := _make_player()
		add_child(p)
		_players.append(p)
	_listener = AudioListener3D.new()
	add_child(_listener)
	_listener.make_current()


func _make_player() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = AudioSettings.BUS_SFX
	p.max_distance = GameConfig.SFX_HEAR_RANGE
	p.unit_size = GameConfig.SFX_UNIT_SIZE
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.panning_strength = 0.6
	return p


## Place l'oreille (le pirate du joueur), en coordonnées de la scène.
func set_listener(at: Vector3) -> void:
	if _listener != null:
		_listener.global_position = at


## Un son bref en `at` (scène), volume linéaire `vol`, hauteur `pitch`.
func play_at(stream: AudioStream, at: Vector3, vol: float = 1.0, pitch: float = 1.0) -> void:
	if stream == null or vol <= 0.01:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.global_position = at
	p.volume_db = linear_to_db(vol) + GameConfig.SFX_DB
	p.pitch_scale = pitch
	p.play()


## Un son qui dure tant qu'on ne l'arrête pas (`key` : par ex. l'action en cours d'un joueur). Relancé s'il tourne déjà.
func loop_at(key: String, stream: AudioStream, at: Vector3, vol: float = 1.0, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer3D = _loops.get(key)
	if p == null:
		p = _make_player()
		add_child(p)
		_loops[key] = p
	p.global_position = at
	if p.stream != stream or not p.playing:
		p.stream = stream
		p.play()
	p.volume_db = linear_to_db(maxf(vol, 0.001)) + GameConfig.SFX_DB
	p.pitch_scale = pitch


func move_loop(key: String, at: Vector3) -> void:
	var p: AudioStreamPlayer3D = _loops.get(key)
	if p != null:
		p.global_position = at


func stop_loop(key: String) -> void:
	var p: AudioStreamPlayer3D = _loops.get(key)
	if p != null:
		p.stop()
