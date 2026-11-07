class_name ProcKit
extends RefCounted
## Petits outils pour bâtir du décor en 3D à partir de formes simples (boîtes, cylindres, sphères) : matières
## unies ou « bois à planches ». Les positions sont en mètres de jeu, dans le repère du parent.


static func flat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


## Bois à planches : des rangées plus ou moins claires séparées d'un joint sombre. `tile` : répétitions.
static func wood(color: Color, tile: Vector2) -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		var row := floori(y / 4.0)
		var tint := 1.0 + (float((row * 7) % 5) - 2.0) * 0.045
		for x in 16:
			var c := color * tint
			c.a = 1.0
			if y % 4 == 0:
				c = color * 0.62
				c.a = 1.0
			elif (x + row * 5) % 16 == 0:
				c = color * 0.8
				c.a = 1.0
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(tile.x, tile.y, 1.0)
	m.roughness = 0.9
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if mat != null:
		mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, radius: float, height: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	if mat != null:
		mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func ball(parent: Node, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	if mat != null:
		mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Point monde (x, hauteur, z) d'un point (x, y) du fichier du port.
static func w(x: float, y: float, h: float = 0.0) -> Vector3:
	return Vector3(x, h, -y)
