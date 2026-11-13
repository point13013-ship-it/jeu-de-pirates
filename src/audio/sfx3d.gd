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
var _last_play: Dictionary = {}   ## id du son -> instant de sa dernière lecture (s)


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
	p.attenuation_filter_cutoff_hz = GameConfig.SFX_FAR_CUTOFF_HZ   # de loin, un son perd ses aigus
	return p


## Place l'oreille (le pirate du joueur), en coordonnées de la scène.
func set_listener(at: Vector3) -> void:
	if _listener != null:
		_listener.global_position = at


## Un son bref en `at` (scène), volume linéaire `vol`, hauteur `pitch`.
## Anti-saturation (pratique courante : limite de voix par son, délai minimal entre deux déclenchements) : un même son n'est
## pas relancé à moins de GameConfig.SFX_MIN_GAP s, et pas plus de SFX_MAX_VOICES fois en même temps (on coupe la plus ancienne).
## `far` : un son fort qui porte loin (canon, impact de boulet) : il s'entend jusqu'à GameConfig.SFX_FAR_RANGE.
func play_at(stream: AudioStream, at: Vector3, vol: float = 1.0, pitch: float = 1.0, far: bool = false) -> void:
	if stream == null or vol <= 0.01:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var sid := stream.get_instance_id()
	if now - float(_last_play.get(sid, -1.0)) < GameConfig.SFX_MIN_GAP:
		return
	_last_play[sid] = now
	var same: Array[AudioStreamPlayer3D] = []
	for q in _players:
		if q.playing and q.stream == stream:
			same.append(q)
	var p := _players[_next]
	if same.size() >= GameConfig.SFX_MAX_VOICES:
		p = same[0]   # (l'ordre du lot suit l'ordre de lancement : la première trouvée est la plus ancienne… à peu près)
	else:
		_next = (_next + 1) % _players.size()
	p.stream = stream
	p.global_position = at
	p.max_distance = GameConfig.SFX_FAR_RANGE if far else GameConfig.SFX_HEAR_RANGE
	p.unit_size = GameConfig.SFX_FAR_UNIT_SIZE if far else GameConfig.SFX_UNIT_SIZE
	p.volume_db = linear_to_db(vol) + GameConfig.SFX_DB
	p.pitch_scale = pitch
	p.play()
	if OS.has_environment("SFX_DEBUG"):
		print("[sfx] %s à %.1f m de l'oreille (oreille active : %s, bus %s %.1f dB muet %s)" % [stream.resource_path.get_file() if stream.resource_path != "" else str(stream),
				at.distance_to(_listener.global_position), _listener.is_current(), p.bus, AudioServer.get_bus_volume_db(AudioServer.get_bus_index(p.bus)),
				AudioServer.is_bus_mute(AudioServer.get_bus_index(p.bus))])


## Un son qui dure tant qu'on ne l'arrête pas (`key` : par ex. l'action en cours d'un joueur). Relancé s'il tourne déjà.
## `sync` : la boucle démarre là où elle en serait si elle tournait depuis le lancement du jeu (les instruments de musique :
## deux pirates qui jouent le même air tombent ensemble, quel que soit le moment où chacun a commencé).
func loop_at(key: String, stream: AudioStream, at: Vector3, vol: float = 1.0, pitch: float = 1.0, sync: bool = false) -> void:
	var p: AudioStreamPlayer3D = _loops.get(key)
	if p == null:
		p = _make_player()
		add_child(p)
		_loops[key] = p
	p.global_position = at
	if p.stream != stream or not p.playing:
		p.stream = stream
		var from := 0.0
		if sync and stream != null and stream.get_length() > 0.0:
			from = fmod(Time.get_ticks_msec() / 1000.0, stream.get_length())
		p.play(from)
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
