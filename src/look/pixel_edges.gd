class_name PixelEdges
extends Node3D
## Les contours de silhouette et les reflets d'arête du prototype de refonte (voir ToonLook et shaders/pixel_edges.gdshader) :
## deux quadrilatères plein écran, l'un qui assombrit (mélange multiplicatif), l'autre qui éclaircit (mélange additif).
## À poser sous la caméra (ils doivent rester devant elle).

var _mats: Array[ShaderMaterial] = []


func _ready() -> void:
	var base := load("res://shaders/pixel_edges.gdshader") as Shader
	for k in 2:
		var sh := Shader.new()
		sh.code = base.code.replace("render_mode unshaded,", "render_mode unshaded, %s," % ("blend_mul" if k == 0 else "blend_add"))
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("mode", k)
		m.render_priority = 120 + k
		_mats.append(m)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2, 2)
		q.mesh = qm
		q.material_override = m
		q.extra_cull_margin = 16384.0
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)


## La hauteur de la mer dans la scène : sous elle, pas de trait.
func set_sea_y(y: float) -> void:
	for m in _mats:
		m.set_shader_parameter("sea_y", y)
