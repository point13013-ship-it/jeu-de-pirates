extends SceneTree
## Tests de l'ambiance des îles : trouvailles placées sur la terre (bouteille sur la plage, journal à l'intérieur), toujours
## les mêmes d'une partie à l'autre ; textes complets ; sons fabriqués ; ciel (jour, nuit, météo).
## Lancer : godot --headless --path . -s tests/unit/test_island_life.gd

var _failed := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  ÉCHEC ", what)


func _world() -> IslandWorld:
	var w := IslandWorld.new()
	w.setup(IslandWorld.read_json(IslandWorld.ISLANDS_PATH), IslandWorld.read_json(IslandWorld.ENEMIES_PATH))
	for cx in range(-3, 4):
		for cz in range(-3, 6):
			w.ensure_chunk(Vector2i(cx, cz))
	return w


func _initialize() -> void:
	var a := _world()
	var b := _world()
	_check(a.islands.size() >= 6, "des îles (fichier + tirées au hasard) : %d" % a.islands.size())
	var counts := {"bottle": 0, "journal": 0, "castaway": 0, "ruin": 0, "shell": 0, "starfish": 0}
	for i in a.islands.size():
		var isl: Dictionary = a.islands[i]
		_check(isl.has("lore_items") and isl.has("plants"), "île %s : listes de trouvailles et de plantes" % isl["id"])
		for it: Dictionary in isl["items"]:
			if counts.has(it["kind"]):
				counts[it["kind"]] += 1
		for it: Dictionary in isl["lore_items"]:
			var s := a.sdf(i, it["pos"])
			match it["kind"]:
				"bottle":
					if s < 0.5 or s > 2.2:
						_check(false, "bouteille de %s sur la plage (sdf %.2f)" % [isl["id"], s])
				"journal":
					if s < 3.0:
						_check(false, "journal de %s à l'intérieur (sdf %.2f)" % [isl["id"], s])
				"castaway":
					if s < 4.0:
						_check(false, "camp de %s à l'intérieur (sdf %.2f)" % [isl["id"], s])
		# même île, mêmes trouvailles dans une autre partie
		var other: Dictionary = b.islands[i]
		_check((isl["lore_items"] as Array).size() == (other["lore_items"] as Array).size(), "île %s : trouvailles déterministes" % isl["id"])
	print("  décor posé : ", counts)
	_check(int(counts["shell"]) > 10 and int(counts["bottle"]) > 0 and int(counts["journal"]) > 0, "coquillages, bouteilles et journaux présents")
	# les textes
	for k in 20:
		var bt := IslandLore.bottle(k * 11, "Île de Test")
		if k < 4:
			_check((bt["lines"] as Array).size() > 0 and not ("%s" in str(bt["lines"])), "bouteille %d : texte complet" % k)
		var jr := IslandLore.journal(k * 13)
		if (jr["lines"] as Array).is_empty():
			_check(false, "journal %d vide" % k)
		var cw := IslandLore.castaway(k * 7)
		if (cw["lines"] as Array).is_empty():
			_check(false, "naufragé %d muet" % k)
	var plain := IslandLore.bottle(7, "")
	_check(not bool(plain["map"]), "sans île à révéler, pas de message « carte »")
	# traces de pas : à pied sur la plage, elles apparaissent, puis s'effacent ; aucune sur un bateau
	var life := IslandLife.new()
	root.add_child(life)
	life.setup(a)
	var isl0: Dictionary = a.islands[0]
	var beach := Vector2.ZERO
	var c0: Vector2 = isl0["center"]
	for ang in 36:
		var dir := Vector2.from_angle(ang * TAU / 36.0)
		for rr in range(int(isl0["radius"]) + 6, 0, -1):
			var q := c0 + dir * float(rr)
			var sq := a.sdf(0, q)
			if sq > 0.8 and sq < 2.0:
				beach = q
				break
		if beach != Vector2.ZERO:
			break
	_check(a.sdf(0, beach) > 0.5 and a.sdf(0, beach) < 3.0, "point de plage pour le test (sdf %.2f)" % a.sdf(0, beach))
	for k in 12:
		beach.y += 0.7
		life.update(0.05, {"pos": beach, "where": "land", "moved": 0.7, "face": Vector2(0, 1), "night": false})
	var shown := 0
	for rec: Dictionary in life._prints:
		if (rec["node"] as Node3D).visible:
			shown += 1
	_check(shown >= 5, "des traces de pas sur la plage (%d)" % shown)
	for k in 400:
		life.update(0.05, {"pos": beach, "where": "land", "moved": 0.0, "face": Vector2(0, 1), "night": false})
	shown = 0
	for rec: Dictionary in life._prints:
		if (rec["node"] as Node3D).visible:
			shown += 1
	_check(shown == 0, "les traces s'effacent avec le temps (%d restantes)" % shown)
	_check(life._gulls.size() == IslandLife.GULLS, "des mouettes prêtes")
	# les sons : tous fabriqués, boucles bouclées
	# (13/11 : la pluie est un vrai enregistrement, en boucle ; la pluie fabriquée reste là en secours)
	_check(Synth.rain() != null, "la pluie a un son")
	for stream: AudioStreamWAV in [Synth.waves(), Synth.wind(), Synth.fire(), Synth._rain_synth(), Synth.insects()]:
		_check(stream.data.size() > 10000 and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "boucle d'ambiance (%d octets)" % stream.data.size())
	for stream: AudioStreamWAV in [Synth.gull(), Synth.bird(0), Synth.bird(2), Synth.splash(), Synth.rustle(), Synth.chime(), Synth.creak(), Synth.thunder()]:
		_check(stream.data.size() > 1000 and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "son bref (%d octets)" % stream.data.size())
	# les pas : de vrais enregistrements (plusieurs prises tirées au hasard), sinon le son fabriqué
	for kind in 4:
		var st := Synth.step(kind, 0)
		_check(st != null and (st is AudioStreamRandomizer or st is AudioStreamWAV), "pas %d : %s" % [kind, st.get_class() if st != null else "rien"])
		if st is AudioStreamRandomizer:
			_check((st as AudioStreamRandomizer).streams_count >= 3, "pas %d : au moins 3 prises (%d)" % [kind, (st as AudioStreamRandomizer).streams_count])
	# le ciel (les nœuds doivent être dans l arbre : on attend une image)
	await process_frame
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	var holder := Node3D.new()
	root.add_child(holder)
	holder.add_child(sun)
	var noon := SkyCycle.new()
	noon.setup(env, sun, holder, {"tod": "0.5", "weather": "clear"})
	noon.update(0.1, Vector3.ZERO)
	_check(noon.daylight > 0.95 and not noon.night and noon.rain == 0.0, "midi : plein jour, beau temps")
	var e1 := sun.light_energy
	var midnight := SkyCycle.new()
	midnight.setup(env, sun, holder, {"tod": "0.0", "weather": "clear"})
	midnight.update(0.1, Vector3.ZERO)
	_check(midnight.daylight < 0.05 and midnight.night, "minuit : nuit")
	_check(sun.light_energy < e1, "la nuit est moins éclairée que le jour")
	var storm := SkyCycle.new()
	storm.setup(env, sun, holder, {"tod": "0.5", "weather": "storm"})
	for k in 600:
		storm.update(0.1, Vector3.ZERO)
	_check(storm.rain > 0.95 and storm.storm > 0.95 and storm.mist > 0.3, "orage : pluie, orage et brume")
	_check(sun.light_energy < e1, "l'orage assombrit le soleil")
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)
