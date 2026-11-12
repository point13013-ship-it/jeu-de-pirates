extends SceneTree
## Cabine vue de l'intérieur (12/11/2026) : les murs côté caméra ne disparaissent plus, ils sont rabattus en muret (on voit la
## porte) ; le toit est masqué ; dehors, tout est remis en place. Et la barre est à hauteur de poitrine.
## Lancer : godot --headless --path . -s tests/unit/test_cabin_view.gd

var _failed := 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "ÉCHEC ") + what)
	if not ok:
		_failed += 1


func _initialize() -> void:
	var m := ShipModel.new()
	root.add_child(m)
	await process_frame
	m.load_ship("sloop")
	m.update_cutaway(true)
	var stubs := 0
	var walls_shown := 0
	var roof_hidden := true
	for entry: Dictionary in m._cuts:
		var node := entry["node"] as Node3D
		var nm := String(node.name)
		if nm.begins_with("cut_roof") and node.visible:
			roof_hidden = false
		if nm.begins_with("cut_wall_") and node.visible:
			walls_shown += 1
			if node.transform.basis.get_scale().y < (entry["base"] as Transform3D).basis.get_scale().y * 0.5:
				stubs += 1
	_check(roof_hidden, "dedans : toit masqué")
	_check(stubs >= 1, "dedans : murs côté caméra rabattus en muret (%d)" % stubs)
	_check(walls_shown >= 4, "dedans : le contour de la pièce reste visible (%d murs)" % walls_shown)
	m.update_cutaway(false)
	var restored := true
	for entry: Dictionary in m._cuts:
		if not (entry["node"] as Node3D).visible or (entry["node"] as Node3D).transform != entry["base"]:
			restored = false
	_check(restored, "dehors : tout est remis en place")
	# barre : centre de la roue à hauteur de poitrine (1,1 à 1,4 m au-dessus du pont)
	var helm_z := 0.0
	for c in m._model.find_children("helm", "", true, false):
		helm_z = (c as Node3D).global_position.y - m.deck_height(float((m.meta["helm"] as Array)[0]))
	_check(helm_z > 1.0 and helm_z < 1.45, "barre à hauteur de poitrine (%.2f m)" % helm_z)
	print("RÉSULTAT : %s" % ("tout passe" if _failed == 0 else "%d échec(s)" % _failed))
	quit(1 if _failed > 0 else 0)
