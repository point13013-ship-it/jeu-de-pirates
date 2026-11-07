class_name PortOpener
extends Node
## Opens the port of an online game on the player's internet box by itself (UPnP), so that friends can join over
## the internet without any setting to change: it asks the box to send what arrives on the UDP port to this computer,
## and learns the public address of the box. It runs in the background (the box may take a few seconds to answer) and
## tells the result with `finished`. The port is closed again when the node leaves the tree.
## Free, nothing but the box is talked to. A box that refuses (UPnP off, a provider that shares one address between
## several homes) gives `ok = false` and a reason; the invitation then only works on the same network or through a VPN.

## `result` = { ok: bool, address: String (the public address when ok), local: String (this computer's address on its
## network, "" if unknown), why: String (what to tell the player when not ok), shared: bool (the box has a private
## "public" address: the provider shares one address, friends cannot reach it) }.
signal finished(result: Dictionary)

const DISCOVER_MS: int = 2500
const DESCRIPTION: String = "Jeu de pirates"

var _thread: Thread
var _port: int = 0
var _upnp: UPNP
var _mapped: bool = false


## Starts opening `port` (UDP). Calls `finished` later, from the main thread.
func open(port: int) -> void:
	_port = port
	_thread = Thread.new()
	_thread.start(_work.bind(port))


func _work(port: int) -> void:
	var result: Dictionary = {"ok": false, "address": "", "local": local_address(), "why": "", "shared": false}
	var upnp := UPNP.new()
	var found: int = upnp.discover(DISCOVER_MS, 2, "InternetGatewayDevice")
	var gateway: UPNPDevice = upnp.get_gateway() if found == UPNP.UPNP_RESULT_SUCCESS else null
	if gateway == null or not gateway.is_valid_gateway():
		result["why"] = "Votre box internet n'a pas répondu (UPnP désactivé ?)."
	else:
		var mapping: int = upnp.add_port_mapping(port, port, DESCRIPTION, "UDP", 0)
		var address: String = upnp.query_external_address()
		if mapping != UPNP.UPNP_RESULT_SUCCESS:
			result["why"] = "Votre box a refusé d'ouvrir le port %d." % port
		elif address == "":
			result["why"] = "Impossible de connaître l'adresse publique de votre box."
		else:
			_upnp = upnp
			result["ok"] = true
			result["address"] = address
			result["shared"] = _is_private(address)
			if result["shared"]:
				result["ok"] = false
				result["why"] = "Votre fournisseur partage une seule adresse entre plusieurs foyers : vos amis ne peuvent pas vous joindre directement."
	call_deferred("_done", result)


func _done(result: Dictionary) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	_mapped = bool(result["ok"])
	finished.emit(result)


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
	if _mapped and _upnp != null:
		_upnp.delete_port_mapping(_port, "UDP")


## This computer's address on its own network (a friend in the same home or on a VPN uses it), or "".
static func local_address() -> String:
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254.") and _is_private(address):
			return address
	return ""


## True for an address that is not reachable from the internet (a home network, a shared provider address).
static func _is_private(address: String) -> bool:
	var parts: PackedStringArray = address.split(".")
	if parts.size() != 4:
		return false
	var a: int = int(parts[0])
	var b: int = int(parts[1])
	return a == 10 or a == 127 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 100 and b >= 64 and b <= 127)
