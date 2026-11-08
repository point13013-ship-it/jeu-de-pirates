extends SceneTree
## Outil d'essai : compose le pirate (look sauvegardé ou argument) et enregistre les 8 directions agrandies.
## godot --path . --script res://tools/char_shot.gd -- out=chemin.png [zoom=1]
func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else "1"
	var look := PirateLook.load_saved()
	if args.has("seed"):
		look = PirateLook.random_look(int(args["seed"]))
	var tex: Texture2D = await PirateSprite.texture_for(look, "idle")
	var img := tex.get_image()
	var fw: int = int(PirateLook.catalog()["frame"][0])
	var fh: int = int(PirateLook.catalog()["frame"][1])
	var scale := int(args.get("scale", "6"))
	var out := Image.create(fw * scale * 8, fh * scale, false, Image.FORMAT_RGBA8)
	out.fill(Color("2b6a8a"))
	for d in 8:
		var cell := img.get_region(Rect2i(0, d * fh, fw, fh))
		cell.resize(fw * scale, fh * scale, Image.INTERPOLATE_NEAREST)
		out.blend_rect(cell, Rect2i(0, 0, fw * scale, fh * scale), Vector2i(d * fw * scale, 0))
	out.save_png(str(args.get("out", "res://.scratch/shot.png")))
	quit()
