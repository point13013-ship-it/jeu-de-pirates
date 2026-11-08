extends SceneTree
## Tests du grappin (Hook) : le crochet s'accroche à la première chose qu'il touche — butin, bateau ennemi, bateau des joueurs, rocher,
## rivage, mur — et à rien au-delà de la portée ; les codes de direction font l'aller-retour. Lancer : godot --headless --path . -s tests/unit/test_hook.gd

var _failed := 0

# --- un petit monde de sondes : un rocher en (10, 0), un mur en (20, 5), de l'eau partout ailleurs, la terre à partir de x = 30 ---
var _rock := Vector2(10.0, 0.0)
var _loot_at := Vector2(6.0, 8.0)
var _water_seen := false


func _initialize() -> void:
	_test_first_thing_wins()
	_test_range()
	_test_codes()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _probes() -> Dictionary:
	_water_seen = true
	return {
		"loot": func(p: Vector2) -> Dictionary: return {"id": 7, "pos": _loot_at} if p.distance_to(_loot_at) < 0.9 else {},
		"enemy": func(p: Vector2) -> Dictionary: return {"id": 3} if Rect2(Vector2(14.0, -12.0), Vector2(6.0, 4.0)).has_point(p) else {},
		"ship": func(p: Vector2) -> bool: return Rect2(Vector2(-2.0, 12.0), Vector2(8.0, 4.0)).has_point(p),
		"solid": func(p: Vector2) -> String:
			if p.distance_to(_rock) < 1.5:
				return "rocher"
			if p.x > 30.0:
				return "terre"
			return "",
	}


func _test_first_thing_wins() -> void:
	var o := Vector2.ZERO
	var rock := Hook.trace(o, Vector2.RIGHT, _probes())
	_check("un rocher dans l'axe est saisi", rock["kind"] == Hook.KIND_FIXED and str(rock["name"]) == "un rocher")
	_check("le point d'accroche est sur le rocher", (rock["pos"] as Vector2).distance_to(_rock) < 1.6)
	var loot := Hook.trace(o, (_loot_at - o).normalized(), _probes())
	_check("un butin est saisi (kind loot, id retransmis)", loot["kind"] == Hook.KIND_LOOT and int(loot["id"]) == 7)
	var enemy := Hook.trace(o, Vector2(0.0, -1.0).rotated(deg_to_rad(60.0)), _probes())
	_check("un bateau ennemi est saisi", enemy["kind"] == Hook.KIND_ENEMY and int(enemy["id"]) == 3)
	var ship := Hook.trace(o, Vector2(0.0, 1.0), _probes())
	_check("le bateau des joueurs est saisi", ship["kind"] == Hook.KIND_SHIP)
	var land := Hook.trace(Vector2(8.0, 20.0), Vector2.RIGHT, _probes(), 40.0)
	_check("le rivage est saisi plus loin si on a la portée", land["kind"] == Hook.KIND_FIXED and (land["pos"] as Vector2).x > 29.0)
	# le premier obstacle l'emporte sur le second, même plus gros ou plus intéressant
	var blocked := Hook.trace(Vector2(-5.0, 0.0), Vector2.RIGHT, _probes(), 60.0)
	_check("derrière le rocher, rien d'autre n'est atteint", (blocked["pos"] as Vector2).x < 10.0)


func _test_range() -> void:
	var far := Hook.trace(Vector2(8.0, 20.0), Vector2.RIGHT, _probes(), 10.0)
	_check("hors de portée : rien", far["kind"] == Hook.KIND_NONE)
	_check("hors de portée : le tir s'arrête à la portée", is_equal_approx((far["pos"] as Vector2).x, 18.0))
	var near := Hook.trace(Vector2(9.5, 0.0), Vector2.RIGHT, _probes())
	_check("on ne saisit pas ce qui est sous ses pieds (distance minimale)", near["kind"] == Hook.KIND_FIXED and float(near["dist"]) >= Hook.START)
	var none := Hook.trace(Vector2(0.0, 0.0), Vector2(-1.0, 0.0), _probes())
	_check("dans le vide : rien", none["kind"] == Hook.KIND_NONE and is_equal_approx(float(none["dist"]), Hook.RANGE))
	var zero := Hook.trace(Vector2(0.0, 0.0), Vector2.ZERO, _probes())
	_check("direction nulle : pas de plantage", zero.has("kind"))


func _test_codes() -> void:
	for deg in [0.0, 37.5, 90.0, 179.9, -90.0, -179.0]:
		var d := Vector2.from_angle(deg_to_rad(deg))
		var back := Hook.code_dir(Hook.dir_code(d))
		_check("code de direction %.1f° : aller-retour à 0,1° près" % deg, absf(rad_to_deg(back.angle_to(d))) < 0.11)
		_check("code de direction %.1f° dans 0..3599" % deg, Hook.dir_code(d) >= 0 and Hook.dir_code(d) < 3600)
	for k in Hook.KIND_CODES:
		_check("code d'espèce « %s »" % k, Hook.kind_of_code(Hook.kind_code(k)) == k)
	_check("code d'espèce inconnu : rien", Hook.kind_of_code(99) == Hook.KIND_CODES[Hook.KIND_CODES.size() - 1])


func _check(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)
