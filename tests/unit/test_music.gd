extends SceneTree
## Tests de la musique et des volumes : les trois airs se fabriquent, bouclent sans claquement, ont du volume sans saturer ;
## les réglages de volume se sauvent et se relisent (dans un fichier d'essai, jamais celui du joueur).
## Lancer : godot --headless --path . -s tests/unit/test_music.gd

var _failed := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	for id: String in MusicSynth.IDS:
		var t0 := Time.get_ticks_msec()
		var w := MusicSynth.build(id)
		var secs := float(Time.get_ticks_msec() - t0) / 1000.0
		var data := w.data   # (une seule copie : relire la propriété à chaque échantillon est très lent)
		var n := data.size() / 2
		var length := float(n) / MusicSynth.RATE
		_check(length > 17.0 and length < 40.0, "%s : durée %.1f s" % [id, length])
		_check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_end == n, "%s : boucle" % id)
		var peak := 0
		var sq := 0.0
		var clipped := 0
		for i in n:
			var s := data.decode_s16(i * 2)
			peak = maxi(peak, absi(s))
			sq += float(s) * float(s)
			if absi(s) >= 31990:
				clipped += 1
		var rms := sqrt(sq / n) / 32768.0
		_check(peak > 20000 and clipped < n / 500, "%s : niveau correct (crête %d, saturé %d)" % [id, peak, clipped])
		_check(rms > 0.04 and rms < 0.35, "%s : volume moyen %.3f" % [id, rms])
		# raccord de la boucle : pas de claquement entre la dernière et la première image
		var last := float(data.decode_s16((n - 1) * 2))
		var first := float(data.decode_s16(0))
		_check(absf(last - first) < 6000.0, "%s : raccord sans claquement (écart %d)" % [id, int(absf(last - first))])
		print("  (%s fabriqué en %.1f s)" % [id, secs])
	# volumes
	AudioSettings.path = "user://audio_test.json"
	AudioSettings.setup()
	_check(AudioServer.get_bus_index(AudioSettings.BUS_MUSIC) >= 0 and AudioServer.get_bus_index(AudioSettings.BUS_AMBIENT) >= 0 \
			and AudioServer.get_bus_index(AudioSettings.BUS_SFX) >= 0, "les trois bus existent")
	AudioSettings.set_volume("music", 0.25)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioSettings.BUS_MUSIC)), AudioSettings.to_db(0.25)), "le volume de musique règle son bus")
	AudioSettings.set_volume("sfx", 0.0)
	_check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioSettings.BUS_SFX)) <= -79.0, "0 = silence")
	AudioSettings.volumes["music"] = 0.9
	var f := FileAccess.open(AudioSettings.path, FileAccess.READ)
	var saved: Variant = JSON.parse_string(f.get_as_text())
	_check(saved is Dictionary and is_equal_approx(float((saved as Dictionary)["music"]), 0.25) and float((saved as Dictionary)["sfx"]) == 0.0, "les réglages sont sauvés")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AudioSettings.path))
	# le panneau de volume
	var panel := VolumePanel.new()
	root.add_child(panel)
	await process_frame
	_check(panel._sliders.size() == AudioSettings.KEYS.size(), "un curseur par réglage")
	(panel._sliders["ambient"] as HSlider).value = 0.4
	_check(is_equal_approx(float(AudioSettings.volumes["ambient"]), 0.4), "bouger un curseur change le volume")
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)
