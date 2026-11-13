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
const ISLAND_RATE := 12.0   ## fois par seconde : état des ennemis et des coffres des îles
const LOOT_RATE := 6.0      ## fois par seconde : butin du monde
const FLEET_RATE := 10.0    ## fois par seconde : bateaux ennemis
const META_RATE := 2.0      ## fois par seconde : coffres, baies, tonneaux, îles générées
const PROTOCOL := 17   # 17 : balles et cartouches dans le coffre du bateau (état du bateau, indices 30 et 31) ; 16 : corde (ligoter, délier, s'attacher au bateau : événements bind, unbind, tether), silex ; 15 : la longue-vue du bord (une par bateau, son détenteur dans l'état du bateau) ; 14 : visée des canons diffusée, trésors du naufrage ; 13 : ventes partagées (message à un seul joueur), rangs des ennemis ; 12 : à terre / relever / mort et réapparition, sirène et requins ; 11 : objet porté envoyé avec la position (trésor compris), hisser un camarade, échelle de coque (lieu 8), actions longues ; 10 : réputation (points envoyés par l'hôte), tir de canon visé (angle dans l'événement de tir) ; 9 : îles capturées et cabanes (coffre partagé) ; 8 : grappin visé, radeaux des joueurs

var game: Node
var active := false
var is_host := false
var ship_name := ""
var _ship_timer := 0.0
var _player_timer := 0.0
var _island_timer := 0.0
var _loot_timer := 0.0
var _fleet_timer := 0.0
var _meta_timer := 0.0
var _raft_sent := false   ## le dernier envoi portait un radeau (il faut encore dire quand il disparaît)


## Code d'invitation à donner aux amis (vide tant qu'il n'est pas connu).
var invite_code := ""
## Adresse IP publique de l'hôte (celle qu'un ami tape pour le rejoindre), "" tant qu'elle n'est pas connue.
var public_address := ""
## L'adresse de l'hôte sur son réseau (un ami chez lui, ou sur un VPN, utilise celle-ci).
var local_ip := ""
## La box a ouvert le port toute seule (UPnP) : un ami d'ailleurs peut rejoindre sans réglage.
var port_open := false
## Ce qu'il faut dire à l'hôte sur l'état de l'invitation (recherche en cours, box qui refuse…).
var invite_note := ""
var _opener: PortOpener
var _ip_request: HTTPRequest
var _client_wired := false
var _failed_text := ""

const JOIN_TIMEOUT := 12.0   ## secondes avant de dire qu'on n'arrive pas à joindre l'hôte
const IP_SERVICE := "https://api.ipify.org"

## L'invitation a changé (adresse trouvée, port ouvert…) : le cadre « Inviter un ami » se met à jour.
signal invite_changed


## Ce que le cadre « Inviter un ami » affiche : { ip, port, code, local, port_open, note }.
func invite_info() -> Dictionary:
	return {"ip": public_address, "port": PORT, "code": invite_code, "local": local_ip, "port_open": port_open, "note": invite_note}


## Héberge une partie avec le bateau `p_ship`. Si `open_box`, demande à la box Internet d'ouvrir le
## port (UPnP, refermé en quittant) pour que des amis d'ailleurs puissent rejoindre. L'adresse IP et le
## code d'invitation arrivent ensuite par `invite_changed` (et `invite_info`). Renvoie OK ou le code
## d'erreur d'ENet.
func host(p_ship: String, open_box: bool = true, local_only: bool = false) -> Error:
	var peer := ENetMultiplayerPeer.new()
	if local_only:
		peer.set_bind_ip("127.0.0.1")   # essais : la partie n'écoute que cet ordinateur (pas d'alerte du pare-feu)
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	active = true
	ship_name = p_ship
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	local_ip = local_address()
	invite_code = Invite.encode(local_ip, PORT)
	if open_box:
		_opener = PortOpener.new()
		add_child(_opener)
		_opener.finished.connect(_on_port_opened)
		_opener.open(PORT)
		invite_note = "Recherche de ton adresse sur Internet…"
	else:
		invite_note = "La box n'a pas été touchée : seuls les amis du même réseau peuvent te rejoindre."
	status.emit("Partie hébergée")
	invite_changed.emit()
	if not open_box and not local_only:
		_fetch_public_ip()
	return OK


func _on_port_opened(result: Dictionary) -> void:
	if bool(result["ok"]):
		public_address = String(result["address"])
		port_open = true
		invite_code = Invite.encode(public_address, PORT)
		DisplayServer.clipboard_set(public_address)
		invite_note = "Port ouvert automatiquement : ton ami peut te rejoindre d'où il veut. L'adresse IP est copiée."
		invite_changed.emit()
		return
	port_open = false
	if bool(result.get("shared", false)):
		invite_note = "Ton fournisseur partage une adresse entre plusieurs foyers : il faut un VPN gratuit (Radmin VPN ou ZeroTier) ; ton ami utilise alors l'adresse « même réseau »."
		invite_changed.emit()
		return
	invite_note = "%s Ouvre le port UDP %d de ta box vers ce PC (ou utilisez un VPN) : sans ça, seuls les amis du même réseau peuvent te rejoindre." % [String(result["why"]), PORT]
	invite_changed.emit()
	_fetch_public_ip()


## Demande son adresse publique à un petit service web : même si la box refuse d'ouvrir le port, l'hôte voit son adresse IP
## (il pourra ouvrir le port à la main).
func _fetch_public_ip() -> void:
	if _ip_request != null:
		return
	_ip_request = HTTPRequest.new()
	_ip_request.timeout = 6.0
	add_child(_ip_request)
	_ip_request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var ip := body.get_string_from_utf8().strip_edges()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and Invite.encode(ip, PORT) != "" and not port_open and public_address == "":
			public_address = ip
			invite_code = Invite.encode(ip, PORT)
			invite_changed.emit())
	if _ip_request.request(IP_SERVICE) != OK:
		_ip_request.queue_free()
		_ip_request = null


## Quitte la partie (hôte ou ami) : coupe le réseau. La box referme le port quand ce nœud disparaît (voir PortOpener).
func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	active = false
	is_host = false
	port_open = false


## Rejoint la partie d'un ami : `text` est son adresse IP (« 82.12.34.56 »), son code d'invitation, ou une
## adresse avec port (« 192.168.1.20:7777 »). Le bateau est chargé à la réception de l'accueil.
func join(text: String) -> Error:
	var target := Invite.parse(text, PORT)
	if not bool(target["ok"]):
		status.emit(String(target["why"]))
		return ERR_INVALID_PARAMETER
	var address := String(target["address"])
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, int(target["port"]))
	if err != OK:
		status.emit("Impossible de commencer la connexion à %s (erreur %d)." % [address, err])
		return err
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = peer
	active = true
	var failed := "Impossible de joindre %s. Vérifie l'adresse, que ton ami a bien cliqué sur « Héberger une partie », que vous avez la même version du jeu (lanceur : « Mettre à jour ») et que le port UDP %d est ouvert chez lui." % [address, PORT]
	_failed_text = failed
	if not _client_wired:   # une seule fois, même si le joueur réessaie plusieurs fois
		_client_wired = true
		multiplayer.connected_to_server.connect(func() -> void: status.emit("Connecté — chargement du bateau…"))
		multiplayer.connection_failed.connect(func() -> void:
			active = false
			status.emit(_failed_text))
		multiplayer.server_disconnected.connect(func() -> void:
			active = false
			status.emit("L'hôte a quitté la partie")
			game.on_host_left())
		multiplayer.peer_connected.connect(func(id: int) -> void:
			_look.rpc_id(id, game.local_look_json())
			game.on_peers_changed())
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	status.emit("Connexion à %s…" % address)
	# ENet met longtemps à renoncer : au bout de quelques secondes on le dit au joueur au lieu de le laisser attendre.
	get_tree().create_timer(JOIN_TIMEOUT).timeout.connect(func() -> void:
		if is_instance_valid(self) and multiplayer.multiplayer_peer == peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
			peer.close()
			multiplayer.multiplayer_peer = null
			active = false
			status.emit(failed))
	return OK


## Adresse IPv4 locale (réseau domestique ou VPN) à donner aux amis sur le même réseau.
func local_address() -> String:
	var a := PortOpener.local_address()
	return a if a != "" else "127.0.0.1"


func _on_peer_connected(id: int) -> void:
	if is_host:
		_welcome.rpc_id(id, PROTOCOL, ship_name)
		_skin.rpc_id(id, game.skin_json())
	_look.rpc_id(id, game.local_look_json())
	game.on_peers_changed()


func _on_peer_disconnected(id: int) -> void:
	game.on_peer_left(id)


@rpc("authority", "call_remote", "reliable")
func _welcome(protocol: int, p_ship: String) -> void:
	if protocol != PROTOCOL:
		status.emit("Ta version du jeu n'est pas la même que celle de l'hôte : mets-la à jour avec le lanceur (bouton « Mettre à jour »), puis réessaie.")
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.close()
			multiplayer.multiplayer_peer = null
		active = false
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
		_player_state.rpc(p["pos"], p["carry"], p["loc"], p["pz"], p["lh"])
		var raft: Array = game.raft_net_state()
		if not raft.is_empty() or _raft_sent:
			_raft_state.rpc(raft)
		_raft_sent = not raft.is_empty()
	if is_host:
		_ship_timer += delta
		if _ship_timer >= 1.0 / SHIP_RATE:
			_ship_timer = 0.0
			_ship_state.rpc(game.ship_state())
		_island_timer += delta
		if _island_timer >= 1.0 / ISLAND_RATE:
			_island_timer = 0.0
			_islands_state.rpc(game.islands_net_state())
		_meta_timer += delta
		if _meta_timer >= 1.0 / META_RATE:
			_meta_timer = 0.0
			_islands_static.rpc(game.islands_static_state())
			_outposts_state.rpc(game.outposts_net_state())
		_loot_timer += delta
		if _loot_timer >= 1.0 / LOOT_RATE:
			_loot_timer = 0.0
			_loot_state.rpc(game.loot_net_state())
		_fleet_timer += delta
		if _fleet_timer >= 1.0 / FLEET_RATE:
			_fleet_timer = 0.0
			_fleet_state.rpc(game.fleet_net_state())


@rpc("authority", "call_remote", "unreliable_ordered")
func _ship_state(s: Array) -> void:
	game.apply_ship_state(s)


## Hôte -> tous : ennemis (position, vie, phase) et coffres ouverts des îles.
@rpc("authority", "call_remote", "unreliable_ordered")
func _islands_state(s: Array) -> void:
	game.apply_islands_state(s)


## Hôte -> tous : coffres ouverts, baies, tonneaux cassés, îles générées. Fiable (le message dépasse un paquet : ENet le découpe),
## mais rare.
@rpc("authority", "call_remote", "reliable")
func _islands_static(s: Array) -> void:
	game.apply_islands_static(s)


## Hôte -> tous : le butin posé dans le monde (trésors flottants, boulets, planches, bourses).
@rpc("authority", "call_remote", "unreliable_ordered")
func _loot_state(s: Array) -> void:
	game.apply_loot_state(s)


## Hôte -> tous : les bateaux ennemis (position, cap, vie, état).
@rpc("authority", "call_remote", "unreliable_ordered")
func _fleet_state(s: Array) -> void:
	game.apply_fleet_state(s)


## Hôte -> tous : le canon `idx` de l'ennemi `id` tire un boulet qui part de `start` à la vitesse `vel`.
func broadcast_enemy_fire(id: int, idx: int, start: Vector3, vel: Vector3) -> void:
	_enemy_fire_event.rpc(id, idx, start, vel)


@rpc("authority", "call_local", "reliable")
func _enemy_fire_event(id: int, idx: int, start: Vector3, vel: Vector3) -> void:
	game.apply_enemy_fire(id, idx, start, vel)


## Client -> hôte : un coup de sabre depuis `pos` vers `dir`. L'hôte décide qui est touché.
func send_swing(pos: Vector2, dir: Vector2) -> void:
	_swing.rpc_id(1, pos, dir)


@rpc("any_peer", "call_remote", "reliable")
func _swing(pos: Vector2, dir: Vector2) -> void:
	if is_host:
		game.apply_swing(multiplayer.get_remote_sender_id(), pos, dir)


## Client -> hôte : un tir de l'arme `weapon` depuis `pos` vers `dir`. L'hôte décide ce qui est touché.
func send_shot(weapon: String, pos: Vector2, dir: Vector2) -> void:
	_shot.rpc_id(1, weapon, pos, dir)


@rpc("any_peer", "call_remote", "reliable")
func _shot(weapon: String, pos: Vector2, dir: Vector2) -> void:
	if is_host:
		game.apply_shot(multiplayer.get_remote_sender_id(), weapon, pos, dir)


## Client -> hôte : un sort de la baie `berry` (emplacement `slot`) lancé depuis `pos` vers `dir`.
func send_cast(berry: String, slot: int, pos: Vector2, dir: Vector2) -> void:
	_cast.rpc_id(1, berry, slot, pos, dir)


@rpc("any_peer", "call_remote", "reliable")
func _cast(berry: String, slot: int, pos: Vector2, dir: Vector2) -> void:
	if is_host:
		game.apply_cast(multiplayer.get_remote_sender_id(), berry, slot, pos, dir)


## Une action visible d'un joueur (coup de sabre, tir, pouvoir) : tout le monde la voit (animation du pirate et effet).
## `kind` : "slash", "shot" ou "cast" ; `arg` : l'arme (« pistolet »…) ou « baie|emplacement » ; `pos` et `dir` : d'où et vers où.
## Un client l'envoie à l'hôte, qui la relaie aux autres ; l'hôte l'envoie directement à tous.
func send_action(kind: String, arg: String, pos: Vector2, dir: Vector2) -> void:
	if not active:
		return
	if is_host:
		_action_event.rpc(multiplayer.get_unique_id(), kind, arg, pos, dir)
	else:
		_action_up.rpc_id(1, kind, arg, pos, dir)


@rpc("any_peer", "call_remote", "reliable")
func _action_up(kind: String, arg: String, pos: Vector2, dir: Vector2) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	game.apply_action(sender, kind, arg, pos, dir)                   # l'hôte la voit aussi
	_action_event.rpc(sender, kind, arg, pos, dir)                    # et la relaie à tous les clients


@rpc("authority", "call_remote", "reliable")
func _action_event(peer: int, kind: String, arg: String, pos: Vector2, dir: Vector2) -> void:
	game.apply_action(peer, kind, arg, pos, dir)


## Client -> hôte : je cueille la baie `spot` ; `old` est la baie que je porte déjà (elle tombera en `pos`).
func send_berry_pick(spot: int, old: String, pos: Vector2) -> void:
	_berry_pick.rpc_id(1, spot, old, pos)


@rpc("any_peer", "call_remote", "reliable")
func _berry_pick(spot: int, old: String, pos: Vector2) -> void:
	if is_host:
		game.apply_berry_pick(multiplayer.get_remote_sender_id(), spot, old, pos)


## Hôte -> un joueur : la baie qu'il vient de cueillir.
func send_berry_got(peer: int, berry: String) -> void:
	_berry_got.rpc_id(peer, berry)


@rpc("authority", "call_remote", "reliable")
func _berry_got(berry: String) -> void:
	game.apply_berry_got(berry)


## Hôte -> un joueur : il vient d'être frappé par un ennemi venu de `from`.
func send_hurt(peer: int, damage: int, from: Vector2) -> void:
	_hurt.rpc_id(peer, damage, from)


@rpc("authority", "call_remote", "reliable")
func _hurt(damage: int, from: Vector2) -> void:
	game.apply_hurt(damage, from)


## Hôte -> un joueur : de l'or gagné (ennemi vaincu ou coffre ouvert) en `at`.
func send_loot(peer: int, gold: int, at: Vector2) -> void:
	_loot.rpc_id(peer, gold, at)


@rpc("authority", "call_remote", "reliable")
func _loot(gold: int, at: Vector2) -> void:
	game.apply_loot(gold, at)


## Hôte -> un joueur : des points de réputation gagnés (trésors vendus, bateau coulé, île capturée…).
func send_rep(peer: int, n: int, why: String) -> void:
	_rep.rpc_id(peer, n, why)


@rpc("authority", "call_remote", "reliable")
func _rep(n: int, why: String) -> void:
	game.apply_rep(n, why)


## Hôte -> un joueur : un objet qu'il reçoit (trésor « t:<id> », « ball », « plank », bourse « g:<or> »).
func send_item(peer: int, kind: String) -> void:
	_item.rpc_id(peer, kind)


@rpc("authority", "call_remote", "reliable")
func _item(kind: String) -> void:
	game.apply_item_got(kind)


## Chaque joueur -> tous : son radeau (x, z, cap, ouverture et orientation de la voile), ou vide s'il n'en a pas (ou plus).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _raft_state(s: Array) -> void:
	game.apply_remote_raft(multiplayer.get_remote_sender_id(), s)


## `carry` : ce que le joueur porte ("", "ball", "plank", "t:<trésor>") : tout le monde le voit entre ses mains.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _player_state(pos: Vector2, carry: String, loc: int, pz: float, lh: float) -> void:
	game.apply_remote_player(multiplayer.get_remote_sender_id(), pos, carry, loc, pz, lh)


## Hôte -> un joueur à la nage : un camarade l'a attrapé, il remonte à bord par l'échelle.
func send_hoist(peer: int) -> void:
	if active and is_host:
		_hoisted.rpc_id(peer)


@rpc("authority", "call_remote", "reliable")
func _hoisted() -> void:
	game.apply_hoisted()


## Hôte -> un joueur (lot 8) : un message pour lui seul (sa part d'une vente…).
func send_tell(peer: int, text: String) -> void:
	if active and is_host:
		_tell.rpc_id(peer, text)


@rpc("authority", "call_remote", "reliable")
func _tell(text: String) -> void:
	game.show_notice(text)


## Hôte -> un joueur à terre (lot 4) : un camarade l'a relevé.
func send_revive(peer: int) -> void:
	if active and is_host:
		_revived.rpc_id(peer)


@rpc("authority", "call_remote", "reliable")
func _revived() -> void:
	game.apply_revived()


## Chaque joueur envoie son apparence (JSON) à chaque nouvel arrivant, et reçoit la leur.
@rpc("any_peer", "call_remote", "reliable")
func _look(json: String) -> void:
	game.apply_remote_look(multiplayer.get_remote_sender_id(), json)


## L'hôte dit à l'équipage de quelles couleurs est le bateau (voiles, coque, pavillon : son skin).
@rpc("authority", "call_remote", "reliable")
func _skin(json: String) -> void:
	game.apply_ship_skin_json(json)


## Hôte : renvoie le skin du bateau à tout l'équipage (après un achat à la voilerie).
func broadcast_skin() -> void:
	if active and is_host and multiplayer.multiplayer_peer != null and not multiplayer.get_peers().is_empty():
		_skin.rpc(game.skin_json())


## Renvoie mon apparence à tout l'équipage (après un achat chez le tailleur).
func broadcast_look() -> void:
	if active and multiplayer.multiplayer_peer != null and not multiplayer.get_peers().is_empty():
		_look.rpc(game.local_look_json())


## Hôte -> tous : îles capturées et cabanes avec le contenu de leur coffre (voir Outpost). Envoyé aussi à chaque changement.
@rpc("authority", "call_remote", "reliable")
func _outposts_state(s: Dictionary) -> void:
	game.apply_outposts_state(s)


func broadcast_outposts() -> void:
	if active and is_host and multiplayer.multiplayer_peer != null and not multiplayer.get_peers().is_empty():
		_outposts_state.rpc(game.outposts_net_state())


## Client : capturer l'île `island` (« capture »), y bâtir une cabane en `pos` (« build »), ranger (« put ») ou reprendre
## (« take ») `n` de `kind` dans son coffre.
func send_cabin(op: String, island: int, kind: String, n: int, pos: Vector2) -> void:
	_cabin.rpc_id(1, op, island, kind, n, pos)


@rpc("any_peer", "call_remote", "reliable")
func _cabin(op: String, island: int, kind: String, n: int, pos: Vector2) -> void:
	if is_host:
		game.apply_cabin(multiplayer.get_remote_sender_id(), op, island, kind, n, pos)


## Client : demande une action à l'hôte (barre, voiles, ancre, canons).
func send_request(kind: String, value: int) -> void:
	_request.rpc_id(1, kind, value)


@rpc("any_peer", "call_remote", "reliable")
func _request(kind: String, value: int) -> void:
	if is_host:
		game.apply_request(multiplayer.get_remote_sender_id(), kind, value)


## Hôte : fait partir le boulet du canon `i` chez tout le monde.
func broadcast_fire(i: int, human: bool = false, aim: float = 0.0) -> void:
	_fire_event.rpc(i, human, aim)


@rpc("authority", "call_local", "reliable")
func _fire_event(i: int, human: bool, aim: float) -> void:
	game.fire_visual(i, human, aim)


## Hôte : un choc a ouvert des voies d'eau ; chez tout le monde, secousse, éclats de bois et message.
func broadcast_hit(kind: int, bx: float, side: int, opened: int) -> void:
	_hit_event.rpc(kind, bx, side, opened)


@rpc("authority", "call_local", "reliable")
func _hit_event(kind: int, bx: float, side: int, opened: int) -> void:
	game.hit_visual(kind, bx, side, opened)


## Hôte : un message à afficher chez tout le monde (bateau débloqué, ramené au port…).
func broadcast_notice(text: String) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.get_peers().is_empty():
		_notice_event.rpc(text)


@rpc("authority", "call_remote", "reliable")
func _notice_event(text: String) -> void:
	game.show_notice(text)


## Hôte : le bateau a coulé ; remorqué au port chez tout le monde.
func broadcast_sunk() -> void:
	_sunk_event.rpc()


@rpc("authority", "call_local", "reliable")
func _sunk_event() -> void:
	game.sunk_visual()
