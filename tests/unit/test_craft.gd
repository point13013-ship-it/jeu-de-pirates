extends SceneTree
## Tests de la fabrication et du radeau : le radeau coûte des planches, rien n'est retiré s'il en manque ; le radeau flotte et avance au
## vent ; il se barre ; il ne passe pas à travers un quai. Lancer : godot --headless --path . -s tests/unit/test_craft.gd

var _failed := 0


func _initialize() -> void:
	_test_recipe()
	_test_pay()
	_test_raft_geometry()
	_test_raft_sailing()
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _profile(planks: int) -> Profile:
	var p := Profile.new()
	p.persistent = false   # (jamais écraser la vraie sauvegarde)
	p.planks = planks
	return p


func _test_recipe() -> void:
	_check("la recette du radeau existe", not Crafting.get_def("raft").is_empty())
	_check("les recettes listées : radeau puis cabane", Crafting.order() == ["raft", "cabin"])
	_check("le radeau est fait de planches", Crafting.cost_of("raft").has("plank") and Crafting.cost_of("raft").size() == 1)
	_check("le radeau coûte plus de planches qu'on n'en a au départ", int(Crafting.cost_of("raft")["plank"]) > Profile.START_PLANKS)
	_check("le coût s'écrit en toutes lettres", Crafting.cost_text("raft") == "%d planches" % int(Crafting.cost_of("raft")["plank"]))
	_check("recette inconnue : vide", Crafting.get_def("fusée").is_empty() and not Crafting.can_afford(_profile(99), "fusée"))


func _test_pay() -> void:
	var cost := int(Crafting.cost_of("raft")["plank"])
	var poor := _profile(cost - 1)
	_check("une planche de moins : impossible", not Crafting.can_afford(poor, "raft"))
	_check("… il en manque exactement une", int(Crafting.missing(poor, "raft")["plank"]) == 1)
	_check("… et rien n'est retiré", not Crafting.pay(poor, "raft") and poor.planks == cost - 1)
	var rich := _profile(cost + 3)
	_check("assez de planches : possible", Crafting.can_afford(rich, "raft") and Crafting.missing(rich, "raft").is_empty())
	_check("on paie le coût exact", Crafting.pay(rich, "raft") and rich.planks == 3)
	var exact := _profile(cost)
	_check("tout juste assez : le sac est vidé de planches", Crafting.pay(exact, "raft") and exact.planks == 0)


func _test_raft_geometry() -> void:
	var yaw := 0.7
	var pos := Vector2(100.0, -40.0)
	_check("le pont couvre son centre", Raft.covers(pos, yaw, pos))
	_check("le pont ne couvre pas un point à 5 m", not Raft.covers(pos, yaw, pos + Vector2(5.0, 0.0)))
	var fwd := Vector2(cos(yaw), -sin(yaw))
	_check("le pont couvre le bout de l'étrave", Raft.covers(pos, yaw, pos + fwd * (Raft.HALF.x - 0.05)))
	_check("… mais pas au-delà", not Raft.covers(pos, yaw, pos + fwd * (Raft.HALF.x + 0.3)))
	_check("la marge élargit le pont", Raft.covers(pos, yaw, pos + fwd * (Raft.HALF.x + 0.3), 0.5))
	_check("le pirate se tient sur le pont", Raft.covers(pos, yaw, Raft.stand_world(pos, yaw)))
	_check("… derrière le mât (vers l'arrière)", Raft.stand_world(pos, yaw).distance_to(pos - fwd * 0.5) < 0.01)
	var pts := Raft.hull_points(pos, yaw)
	_check("15 points de contour", pts.size() == 15)
	var inside := true
	for p: Vector2 in pts:
		inside = inside and Raft.covers(pos, yaw, p, 0.01)
	_check("tous les points de contour sont sur le pont", inside)


func _test_raft_sailing() -> void:
	var raft := Raft.new()
	_check("un radeau neuf est ancré (personne à bord)", raft.sim.anchored)
	raft.sim.anchored = false
	raft.sim.yaw = 0.0
	raft.sim.wind_angle = 0.0   # le vent souffle vers +x : vent arrière
	raft.sim.wind_dir = Vector2.RIGHT
	raft.sim.sail_level = ShipSim.SAIL_LEVELS
	raft.sim.sail_trim_target = raft.sim.optimal_trim()
	raft.sim.sail_trim = raft.sim.sail_trim_target
	for i in 600:
		raft.sim.step(0.05)
	_check("vent arrière, voile hissée : il avance", raft.sim.speed > 3.0 and raft.sim.position.x > 50.0)
	_check("… sans dépasser sa vitesse maximale", raft.sim.speed <= float(Raft.STATS["max_speed"]) + 0.01)
	var before := raft.sim.yaw
	raft.sim.rudder_target = 1.0
	for i in 100:
		raft.sim.step(0.05)
	_check("la barre le fait tourner", absf(raft.sim.yaw - before) > 0.3)
	raft.sim.sail_level = 0
	raft.sim.rudder_target = 0.0
	raft.sim.anchored = true
	for i in 200:
		raft.sim.step(0.05)
	_check("voile affalée et ancré : il s'arrête", raft.sim.speed < 0.05)
	raft.apply_pose(1.0, 0.5, 0.2)
	_check("la pose reçue du réseau s'applique", is_equal_approx(raft.sim.yaw, 1.0) and is_equal_approx(raft.sim.sail_open, 0.5))
	raft.free()
	# les 6 rondins et le mât sont bien construits
	var r2 := Raft.new()
	_check("le modèle est construit (rondins, mât, voile)", r2.get_child_count() > 20)
	r2.free()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("ok  %s" % name)
	else:
		_failed += 1
		print("ÉCHEC %s" % name)
