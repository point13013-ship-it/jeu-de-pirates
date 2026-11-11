extends SceneTree
## Outil d'essai : planche des pirates avec une arme (et son skin) en main : une ligne par animation demandée, 8 directions en colonnes
## (première image de chaque animation, ou toutes avec frames=1).
## godot --path . --script res://tools/weapon_shot.gd -- weapon=pistolet skin=flibustier anims=idle,shoot_pistolet out=chemin.png [scale=4]
## Plusieurs skins d'un coup : skins=classique,flibustier,corail (une planche par skin, mêmes animations).
func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else "1"
	var weapon := str(args.get("weapon", "pistolet"))
	var skins := str(args.get("skins", args.get("skin", "classique"))).split(",")
	var anims := str(args.get("anims", "idle")).split(",")
	var scale := int(args.get("scale", "4"))
	var look := PirateLook.default_look()
	var fw := int(PirateLook.catalog()["frame"][0])
	var fh := int(PirateLook.catalog()["frame"][1])
	var dirs: Array = []
	for d in str(args.get("dirs", "0,1,2,3,4,5,6,7")).split(","):
		dirs.append(int(d))
	var rows := anims.size() * skins.size()
	var all_frames := args.has("frames")
	var out := Image.create(fw * scale * dirs.size() * (3 if all_frames else 1), fh * scale * rows, false, Image.FORMAT_RGBA8)
	out.fill(Color("2b6a8a"))
	var row := 0
	for skin in skins:
		for anim in anims:
			var tex: Texture2D = await PirateSprite.texture_for(look, anim, weapon, skin)
			var img := tex.get_image()
			var n := int(PirateLook.catalog()["anims"][anim])
			var shown := mini(n, 3) if all_frames else 1
			for fr in shown:
				for di in dirs.size():
					var d: int = dirs[di]
					var cell := img.get_region(Rect2i(fr * fw, d * fh, fw, fh))
					cell.resize(fw * scale, fh * scale, Image.INTERPOLATE_NEAREST)
					out.blend_rect(cell, Rect2i(0, 0, fw * scale, fh * scale), Vector2i((fr * dirs.size() + di) * fw * scale, row * fh * scale))
			row += 1
	out.save_png(str(args.get("out", "res://qa/armes/planche.png")))
	quit()
