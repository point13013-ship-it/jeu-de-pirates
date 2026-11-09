extends SceneTree
## Outil d'essai : un bateau ennemi immobile avec son équipage de squelettes, vu de dessus ; on vide tous les canons du flanc
## tribord à t=0 et on enregistre des images pendant que les canonniers rechargent (le journal dit qui fait quoi).
## godot --path . --script res://tools/crew_shot.gd -- out=chemin_sans_extension [ship=sloop] [times=1,4,8]
func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else "1"
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b6a8a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.95)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	world.add_child(sun)
	var model := ShipModel.new()
	model.load_ship(str(args.get("ship", "sloop")))
	ShipSkin.apply(model, EnemyFleet.SKIN)
	world.add_child(model)
	var cannons := ShipCannons.build(model)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var crew := EnemyCrew.new()
	crew.build(model, cannons, str(args.get("ship", "sloop")), rng)
	crew.pref_side = 1
	# le flanc bâbord (+1) vient de tirer : tout est vide ; l'autre reste chargé
	for i in model.cannons.size():
		if int((model.cannons[i] as Array)[2]) == 1:
			crew.loaded[i] = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.0
	cam.rotation_degrees = Vector3(-55, 0, 0)
	cam.position = Vector3(0.0, 30.0, 21.0 - 2.5)
	world.add_child(cam)
	cam.make_current()
	model.rotation.y = PI * 0.5   # la proue vers le haut de l'écran
	var times: Array = str(args.get("times", "1,4,8")).split(",")
	var t := 0.0
	var next := 0
	var dt := 1.0 / 60.0
	for frame in 60 * 14:
		t += dt
		crew.step(dt, true)
		if frame % 30 == 0:
			var line := "t=%4.1f chargés=%s " % [t, str(crew.mask())]
			for g: Dictionary in crew.gunners:
				line += " [%s c%d]" % [g["state"], int(g["cannon"])]
			print(line)
		await process_frame
		if next < times.size() and t >= float(times[next]):
			get_root().get_texture().get_image().save_png("%s_%s.png" % [str(args.get("out", "res://.scratch/crew")), times[next]])
			next += 1
	quit()
