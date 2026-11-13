extends Node2D
## Prototype réseau : un joueur héberge, les autres rejoignent, chacun choisit un bateau
## de 2, 3 ou 4 places et navigue sur une mer partagée.
## Arguments de test : --host / --join=IP / --seats=N / --quit-after-secs=N (après « -- »).

const PORT := 7777
const MAX_PLAYERS := 4
const SHIPS_PATH := "res://data/ships.json"

var _ship_defs: Dictionary = {}
var _ships: Dictionary = {}  # id du pair -> Ship
var _my_seats: int = 2
var _menu: Control
var _ip_edit: LineEdit
var _status: Label
var _camera: Camera2D


func _ready() -> void:
	UiTheme.apply_cursor()   # (13/11 : le curseur du jeu)
	DisplaySettings.setup()   # le mode d'affichage choisi (fenêtré, plein écran…)
	_ship_defs = _load_ships()
	_camera = Camera2D.new()
	add_child(_camera)
	_build_menu()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _set_status("Connexion impossible."))
	multiplayer.server_disconnected.connect(func() -> void: _set_status("L'hôte est parti."))
	var args := _parse_args()
	_my_seats = int(args.get("seats", "2"))
	if args.has("quit-after-secs"):
		get_tree().create_timer(float(args["quit-after-secs"])).timeout.connect(_quit_report)
	if args.has("shot"):
		get_tree().create_timer(float(args.get("shot-after-secs", "4"))).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(str(args["shot"])))
	if args.has("host"):
		_host()
	elif args.has("join"):
		_join(str(args["join"]))


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else true
	return out


func _load_ships() -> Dictionary:
	var file := FileAccess.open(SHIPS_PATH, FileAccess.READ)
	if file == null:
		push_error("ships.json introuvable")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _build_menu() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_menu = VBoxContainer.new()
	_menu.position = Vector2(20, 20)
	layer.add_child(_menu)
	var seats_row := HBoxContainer.new()
	_menu.add_child(seats_row)
	var title := Label.new()
	title.text = "Bateau : "
	seats_row.add_child(title)
	for n in [2, 3, 4]:
		var b := Button.new()
		b.text = "%d places (%s)" % [n, _ship_defs.get(str(n), {}).get("name", "?")]
		b.pressed.connect(func() -> void: _my_seats = n; _set_status("Bateau choisi : %d places." % n))
		seats_row.add_child(b)
	var host_button := Button.new()
	host_button.text = "Héberger une partie"
	host_button.pressed.connect(_host)
	_menu.add_child(host_button)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_menu.add_child(_ip_edit)
	var join_button := Button.new()
	join_button.text = "Rejoindre"
	join_button.pressed.connect(func() -> void: _join(_ip_edit.text))
	_menu.add_child(join_button)
	_status = Label.new()
	_menu.add_child(_status)


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text
	print("[statut] ", text)


func _host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS - 1)
	if error != OK:
		_set_status("Impossible d'héberger (erreur %d)." % error)
		return
	multiplayer.multiplayer_peer = peer
	_start_playing("Partie hébergée sur le port %d." % PORT)


func _join(address: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		_set_status("Impossible de rejoindre (erreur %d)." % error)
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Connexion à %s..." % address)


func _on_connected() -> void:
	_start_playing("Connecté.")


func _start_playing(message: String) -> void:
	_menu.hide()
	_set_status(message)
	var start := Vector2(randf_range(-200, 200), randf_range(-200, 200))
	_spawn_ship(multiplayer.get_unique_id(), _my_seats, start)
	# Les pairs déjà connectés ont pu nous voir arriver avant que notre bateau existe.
	var targets: Array = Array(multiplayer.get_peers())
	if not multiplayer.is_server() and not targets.has(1):
		targets.append(1)  # l'hôte a toujours l'id 1
	print("[réseau] présentation envoyée à ", targets)
	for id: int in targets:
		_introduce.rpc_id(id, _my_seats, start)


func _spawn_ship(peer_id: int, seats: int, at: Vector2) -> void:
	if _ships.has(peer_id):
		return
	var ship := Ship.new()
	ship.position = at
	ship.setup(seats, _ship_defs.get(str(seats), {}), peer_id == multiplayer.get_unique_id(), peer_id)
	ship.name = "ship_%d" % peer_id
	add_child(ship)
	_ships[peer_id] = ship


func _on_peer_connected(id: int) -> void:
	print("[réseau] pair connecté : ", id)
	# Chaque pair se présente au nouvel arrivant.
	if _ships.has(multiplayer.get_unique_id()):
		var mine: Ship = _ships[multiplayer.get_unique_id()]
		_introduce.rpc_id(id, mine.seats, mine.position)
	else:
		# Pas encore prêt (connexion en cours) : on se présentera à la fin du démarrage.
		pass


func _on_peer_disconnected(id: int) -> void:
	if _ships.has(id):
		_ships[id].queue_free()
		_ships.erase(id)


@rpc("any_peer", "reliable")
func _introduce(seats: int, at: Vector2) -> void:
	var sender := multiplayer.get_remote_sender_id()
	print("[réseau] présentation reçue de %d (%d places)" % [sender, seats])
	if seats < 2 or seats > 4:
		return
	_spawn_ship(sender, seats, at)


@rpc("any_peer", "unreliable_ordered")
func _state(at: Vector2, heading: float) -> void:
	var ship: Ship = _ships.get(multiplayer.get_remote_sender_id())
	if ship != null:
		ship.target_pos = at
		ship.target_rot = heading


func _physics_process(_delta: float) -> void:
	var mine: Ship = _ships.get(multiplayer.get_unique_id())
	if mine == null or multiplayer.multiplayer_peer == null:
		return
	_camera.position = mine.position
	if multiplayer.get_peers().size() > 0:
		_state.rpc(mine.position, mine.rotation)


func _draw() -> void:
	# Mer provisoire : grille de repères pour sentir le déplacement.
	draw_rect(Rect2(-20000, -20000, 40000, 40000), Color("1d4e6b"))
	for i in range(-100, 101):
		draw_line(Vector2(i * 200, -20000), Vector2(i * 200, 20000), Color("2b6a8a"), 2.0)
		draw_line(Vector2(-20000, i * 200), Vector2(20000, i * 200), Color("2b6a8a"), 2.0)


func _quit_report() -> void:
	print("[rapport] pair=%d bateaux_vus=%d" % [multiplayer.get_unique_id(), _ships.size()])
	for id in _ships:
		var s: Ship = _ships[id]
		print("[rapport]   bateau du pair %d : %d places, position %s" % [id, s.seats, s.position.round()])
	get_tree().quit()
