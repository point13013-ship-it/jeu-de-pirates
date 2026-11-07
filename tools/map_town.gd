extends SceneTree
## Dessine une carte du dessus de la ville (zones marchables, obstacles, niveaux) : qa/ville/carte.png
## Lancer : godot --headless --path . -s tools/map_town.gd
const S := 12   # pixels par mètre

func _initialize() -> void:
	var land := Land.new()
	land.load_meta(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/port/port_meta.json")))
	land.load_town(JSON.parse_string(FileAccess.get_file_as_string("res://data/town.json")))
	var x0 := -62; var x1 := 62; var y0 := -32; var y1 := 56
	var img := Image.create((x1 - x0) * S, (y1 - y0) * S, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.3, 0.45))
	for py in img.get_height():
		for px in img.get_width():
			var x := x0 + float(px) / S
			var y := y1 - float(py) / S
			var h := land.walk_height(Vector2(x, -y), 0.0, 0.0)
			if h != Land.NO_SURFACE:
				img.set_pixel(px, py, Color(0.75, 0.7, 0.6))
			elif land._on_ground(Vector2(x, y)):
				img.set_pixel(px, py, Color(0.5, 0.25, 0.2))
	for gx in range(x0, x1, 10):
		for py in img.get_height():
			img.set_pixel((gx - x0) * S, py, Color(0, 0, 0, 1))
	for gy in range(y0, y1, 10):
		for px in img.get_width():
			img.set_pixel(px, mini((y1 - gy) * S, img.get_height() - 1), Color(0, 0, 0, 1))
	img.save_png("res://qa/ville/carte.png")
	quit()
