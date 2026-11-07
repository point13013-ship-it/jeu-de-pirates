class_name SailingNet
extends Node
## Réseau de la navigation : un joueur héberge (ENet, port 7777), jusqu'à 3 amis rejoignent le
## même bateau.
## - L'hôte fait autorité sur le bateau : position, cap, vitesse, voiles, ancre, barre, canons.
##   Il diffuse cet état SHIP_RATE fois par seconde ; les autres le prédisent et se recalent.
## - Chaque joueur fait autorité sur sa propre position sur le pont (PLAYER_RATE fois par seconde).
## - Les actions aux postes (barre, voiles, ancre, canons) sont des demandes envoyées à l'hôte, qui
##   les vérifie et les applique ; les tirs sont rejoués chez tout le monde.
## Le jeu (sailing_game.gd) fournit : local_player_state(), ship_state(), apply_ship_state(),
## apply_remote_player(), apply_request(), fire_visual(), on_peer_left(), on_host_left(),
## on_peers_changed().

signal welcomed(ship_name: String)
signal status(text: String)

const PORT := 7777
const MAX_PLAYERS := 4
const SHIP_RATE := 30.0
const PLAYER_RATE := 20.0
const PROTOCOL := 1

var game: Node
var active := false
var is_host := false
var ship_name := ""
var _ship_timer := 0.0
var _player_timer := 0.0


## Héberge une partie avec le bateau `p_ship`. Renvoie OK ou le code d'erreur d'ENet.
func host(p_ship: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	active = true
	ship_name = p_ship
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	status.emit("Partie hébergée — adresse : %s (port %d)" % [local_address(), PORT])
	return OK


## Rejoint la partie hébergée à `address`. Le bateau est chargé à la réception de l'accueil.
func join(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	multiplayer.connected_to_server.connect(func() -> void: status.emit("Connecté — chargement du bateau…"))
	multiplayer.connection_failed.connect(func() -> void:
		active = false
		status.emit("Connexion impossible à %s" % address))
	multiplayer.server_disconnected.connect(func() -> void:
		active = false
		status.emit("L'hôte a quitté la partie")
		game.on_host_left())
	multiplayer.peer_connected.connect(func(_id: int) -> void: game.on_peers_changed())
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	status.emit("Connexion à %s…" % address)
	return OK


## Adresse IPv4 locale (réseau domestique) à donner aux amis sur le même réseau.
func local_address() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "127.0.0.1"


func _on_peer_connected(id: int) -> void:
	_welcome.rpc_id(id, PROTOCOL, ship_name)
	game.on_peers_changed()


func _on_peer_disconnected(id: int) -> void:
	game.on_peer_left(id)


@rpc("authority", "call_remote", "reliable")
func _welcome(protocol: int, p_ship: String) -> void:
	if protocol != PROTOCOL:
		status.emit("Version différente de celle de l'hôte")
		return
	ship_name = p_ship
	status.emit("À bord !")
	welcomed.emit(p_ship)


## À appeler à chaque image : envoie l'état du joueur (et du bateau pour l'hôte) à bon rythme.
func tick(delta: float) -> void:
	if not active or multiplayer.multiplayer_peer == null or multiplayer.get_peers().is_empty():
		return
	_player_timer += delta
	if _player_timer >= 1.0 / PLAYER_RATE:
		_player_timer = 0.0
		var p: Dictionary = game.local_player_state()
		_player_state.rpc(p["pos"], p["flip"], p["carrying"])
	if is_host:
		_ship_timer += delta
		if _ship_timer >= 1.0 / SHIP_RATE:
			_ship_timer = 0.0
			_ship_state.rpc(game.ship_state())


@rpc("authority", "call_remote", "unreliable_ordered")
func _ship_state(s: Array) -> void:
	game.apply_ship_state(s)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _player_state(pos: Vector2, flip: bool, carrying: bool) -> void:
	game.apply_remote_player(multiplayer.get_remote_sender_id(), pos, flip, carrying)


## Client : demande une action à l'hôte (barre, voiles, ancre, canons).
func send_request(kind: String, value: int) -> void:
	_request.rpc_id(1, kind, value)


@rpc("any_peer", "call_remote", "reliable")
func _request(kind: String, value: int) -> void:
	if is_host:
		game.apply_request(multiplayer.get_remote_sender_id(), kind, value)


## Hôte : fait partir le boulet du canon `i` chez tout le monde.
func broadcast_fire(i: int) -> void:
	_fire_event.rpc(i)


@rpc("authority", "call_local", "reliable")
func _fire_event(i: int) -> void:
	game.fire_visual(i)
