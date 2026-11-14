extends SceneTree
## Compare deux captures côte à côte sur une même zone, agrandie sans lissage.
## Lancer : godot --headless --path . -s tools/crop_compare.gd -- a.png b.png sortie.png x y largeur hauteur [zoom]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 7:
		print("usage : a.png b.png sortie.png x y largeur hauteur [zoom]")
		quit()
		return
	var x := int(a[3])
	var y := int(a[4])
	var w := int(a[5])
	var h := int(a[6])
	var z := int(a[7]) if a.size() > 7 else 2
	var out := Image.create(w * z * 2 + 8, h * z, false, Image.FORMAT_RGBA8)
	out.fill(Color(1, 0, 1))
	for k in 2:
		var img := Image.load_from_file(a[k])
		img.convert(Image.FORMAT_RGBA8)
		var crop := img.get_region(Rect2i(x, y, w, h))
		crop.resize(w * z, h * z, Image.INTERPOLATE_NEAREST)
		out.blit_rect(crop, Rect2i(0, 0, w * z, h * z), Vector2i(k * (w * z + 8), 0))
	out.save_png(a[2])
	quit()
