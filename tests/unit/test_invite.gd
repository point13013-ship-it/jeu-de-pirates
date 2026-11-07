extends SceneTree
## Tests du code d'invitation (src/net/invite.gd), sans réseau.
## Lancer : godot --headless --path . -s tests/unit/test_invite.gd

var _failed := 0


func _initialize() -> void:
	_check("aller-retour adresse publique",
			Invite.parse(Invite.encode("82.64.12.200", 7777), 7777), {"ok": true, "address": "82.64.12.200", "port": 7777})
	_check("aller-retour réseau local",
			Invite.parse(Invite.encode("192.168.1.86", 7777), 7777), {"ok": true, "address": "192.168.1.86", "port": 7777})
	var code := Invite.encode("82.64.12.200", 7777)
	_check_true("le code fait 3 groupes de 4", code.length() == 14 and code.count("-") == 2)
	_check_true("minuscules et espaces acceptés", bool(Invite.parse(code.to_lower().replace("-", " "), 7777)["ok"]))
	var typo := code.substr(0, 3) + ("B" if code[3] != "B" else "C") + code.substr(4)
	_check_true("une faute de frappe est détectée", not bool(Invite.parse(typo, 7777)["ok"]))
	_check("adresse simple : port par défaut", Invite.parse("127.0.0.1", 7777), {"ok": true, "address": "127.0.0.1", "port": 7777})
	_check("adresse avec port", Invite.parse("10.0.0.5:9000", 7777), {"ok": true, "address": "10.0.0.5", "port": 9000})
	_check_true("champ vide refusé", not bool(Invite.parse("   ", 7777)["ok"]))
	_check_true("adresse invalide : pas de code", Invite.encode("pas une adresse", 7777) == "")
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(name: String, got: Dictionary, expected: Dictionary) -> void:
	for k in expected:
		if not got.has(k) or got[k] != expected[k]:
			_failed += 1
			print("ÉCHEC %s : attendu %s, obtenu %s" % [name, expected, got])
			return
	print("ok  %s" % name)


func _check_true(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)
