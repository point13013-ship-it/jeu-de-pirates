extends SceneTree
## Mesure de netteté d'une capture d'écran (rendu pixel art agrandi par un facteur entier).
## Lancer : godot --headless --path . -s tools/net_check.gd -- <capture.png> [<capture2.png> ...] [--factor=2]
## Affiche deux chiffres par image :
## - grille : meilleure part (sur toutes les phases) des blocs factor x factor d'une seule couleur. ~100 % = pixels du jeu tous de la même taille ;
##   nettement moins = grille brouillée (décalage de l'image au sous-pixel, lissage). (Un rendu 2x pur donne ~100 %.)
## - flou : part des transitions de couleur (à l'échelle des pixels du jeu) qui sont un mélange des deux voisins (bord adouci)
##   plutôt qu'un bord franc. 0 % = bords tous francs.

func _initialize() -> void:
	var factor := 2
	var files: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--factor="):
			factor = int(a.get_slice("=", 1))
		else:
			files.append(a)
	for f in files:
		_measure(f, factor)
	quit()


func _same(d: PackedByteArray, w: int, x: int, y: int, f: int) -> bool:
	var i0 := (y * w + x) * 4
	for dy in f:
		for dx in f:
			var i := ((y + dy) * w + (x + dx)) * 4
			if d[i] != d[i0] or d[i + 1] != d[i0 + 1] or d[i + 2] != d[i0 + 2]:
				return false
	return true


func _measure(path: String, f: int) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		print("%s : illisible" % path)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	# grille : part des blocs f x f d'une seule couleur, pour chacune des f x f phases possibles de la grille ; on garde la meilleure
	# (si le décalage de l'image au sous-pixel brouille la grille, TOUTES les phases sont mauvaises)
	var grid := 0.0
	var best_phase := Vector2i.ZERO
	for py in f:
		for px in f:
			var u := 0
			var n := 0
			for y in range(py, h - 2 * f, f):
				for x in range(px, w - 2 * f, f):
					n += 1
					if _same(d, w, x, y, f):
						u += 1
			var frac := float(u) / maxf(n, 1)
			if frac > grid:
				grid = frac
				best_phase = Vector2i(px, py)
	# flou : à l'échelle des pixels du jeu (un échantillon sur f)
	var blends := 0
	var trans := 0
	for y in range(0, h, f * 2):
		for x in range(f, w - f, f):
			var ia := (y * w + x - f) * 4
			var ib := (y * w + x) * 4
			var ic := (y * w + x + f) * 4
			var dac := 0
			for k in 3:
				dac = maxi(dac, absi(int(d[ia + k]) - int(d[ic + k])))
			if dac < 40:
				continue
			trans += 1
			var soft := true
			for k in 3:
				var mid := (int(d[ia + k]) + int(d[ic + k])) / 2
				if absi(int(d[ib + k]) - mid) > 14:
					soft = false
			var same_a := true
			var same_c := true
			for k in 3:
				if absi(int(d[ib + k]) - int(d[ia + k])) > 6:
					same_a = false
				if absi(int(d[ib + k]) - int(d[ic + k])) > 6:
					same_c = false
			if soft and not same_a and not same_c:
				blends += 1
	print("%s : grille %.1f %% (phase %d,%d) | flou %.1f %% (%d transitions)" % [path.get_file(), 100.0 * grid, best_phase.x, best_phase.y, 100.0 * blends / maxf(trans, 1), trans])
