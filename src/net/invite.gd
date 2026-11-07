class_name Invite
extends RefCounted
## The invitation code of an online game: the address of the host and the port, written as twelve letters and digits
## in three groups ("K7QD-M2XP-9WAB") that are easy to read out loud, type and paste. The last characters are a check, so
## that a typo is noticed instead of ending in a connection that never answers. Pure rules, no network.
##
## A friend types the code (or, for a test, a plain address "192.168.1.20" or "192.168.1.20:24565") in the join field.

## No 0/O, no 1/I: they are mixed up when read.
const ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const GROUP: int = 4
## 4 bytes of address, 2 of port and 1 of check, five bits per character: 56 bits, 12 characters (60 bits).
const LENGTH: int = 12


## The code of an IPv4 address and a port ("" if the address is not an IPv4 address or the port is not valid).
static func encode(address: String, port: int) -> String:
	var parts: PackedStringArray = address.split(".")
	if parts.size() != 4 or port < 1 or port > 65535:
		return ""
	var bytes: Array[int] = []
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return ""
		bytes.append(int(part))
	bytes.append(port >> 8)
	bytes.append(port & 255)
	bytes.append(_check(bytes))
	var bits: int = 0
	for value in bytes:
		bits = (bits << 8) | value
	var text: String = ""
	for i in LENGTH:
		var shift: int = 5 * (LENGTH - 1 - i)
		text += ALPHABET[(bits >> shift) & 31]
	var grouped: PackedStringArray = []
	for i in range(0, LENGTH, GROUP):
		grouped.append(text.substr(i, GROUP))
	return "-".join(grouped)


## What a text typed by the player means: { ok: true, address, port } for a code or an address, or { ok: false, why }.
## `default_port` is used when the text is an address without a port.
static func parse(text: String, default_port: int) -> Dictionary:
	var clean: String = text.strip_edges()
	if clean == "":
		return {"ok": false, "why": "Entrez le code d'invitation de votre ami."}
	var plain: String = clean.to_upper().replace("-", "").replace(" ", "")
	if plain.length() == LENGTH and _is_code(plain):
		return _decode(plain)
	if clean.contains(".") or clean.begins_with("[") or clean.to_lower() == "localhost":
		var address: String = clean
		var port: int = default_port
		if clean.count(":") == 1:
			address = clean.get_slice(":", 0)
			var port_text: String = clean.get_slice(":", 1)
			if not port_text.is_valid_int() or int(port_text) < 1 or int(port_text) > 65535:
				return {"ok": false, "why": "Le port est invalide."}
			port = int(port_text)
		return {"ok": true, "address": address, "port": port}
	return {"ok": false, "why": "Ce code d'invitation n'est pas valide : vérifiez les lettres."}


static func _is_code(plain: String) -> bool:
	for i in plain.length():
		if not ALPHABET.contains(plain[i]):
			return false
	return true


static func _decode(plain: String) -> Dictionary:
	var bits: int = 0
	for i in plain.length():
		bits = (bits << 5) | ALPHABET.find(plain[i])
	var bytes: Array[int] = []
	for i in 7:
		bytes.append((bits >> (8 * (6 - i))) & 255)
	var check: int = bytes.pop_back()
	if check != _check(bytes):
		return {"ok": false, "why": "Ce code d'invitation n'est pas valide : vérifiez les lettres."}
	return {"ok": true, "address": "%d.%d.%d.%d" % [bytes[0], bytes[1], bytes[2], bytes[3]], "port": (bytes[4] << 8) | bytes[5]}


static func _check(bytes: Array[int]) -> int:
	var sum: int = 0x5A
	for value in bytes:
		sum = ((sum * 31) + value) & 255
	return sum
