class_name WindStreaks
extends Node3D
## Le vent rendu visible (12/11/2026, à la manière de Sea of Thieves) : de fines traînées blanches, très légères, qui filent
## dans le sens du vent autour du bateau et traversent les voiles. Elles vont plus vite et sont plus nombreuses quand les voiles
## prennent bien le vent : d'un coup d'œil on voit d'où il vient et si l'on est bien réglé.
## Purement local (chaque joueur voit le même vent, qui fait partie de l'état du bateau envoyé par l'hôte).

var _particles: GPUParticles3D
var _mat: ParticleProcessMaterial
var _draw_mat: StandardMaterial3D


func _ready() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = GameConfig.WIND_STREAKS
	_particles.lifetime = GameConfig.WIND_STREAK_LIFE
	_particles.preprocess = GameConfig.WIND_STREAK_LIFE
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 30, 120))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_mat = ParticleProcessMaterial.new()
	_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_mat.emission_box_extents = GameConfig.WIND_STREAK_BOX
	_mat.direction = Vector3(1, 0, 0)
	_mat.spread = 4.0
	_mat.gravity = Vector3.ZERO
	_mat.initial_velocity_min = 8.0
	_mat.initial_velocity_max = 11.0
	# apparition et disparition en douceur (l'alpha de la couleur suit la vie de la traînée)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	_mat.color_ramp = gt
	_particles.process_material = _mat
	var quad := QuadMesh.new()
	quad.size = Vector2(GameConfig.WIND_STREAK_WIDTH, GameConfig.WIND_STREAK_LENGTH)   # long dans le sens de la vitesse (Y)
	_draw_mat = StandardMaterial3D.new()
	_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_draw_mat.vertex_color_use_as_albedo = true
	_draw_mat.albedo_color = Color(1, 1, 1, GameConfig.WIND_STREAK_ALPHA)
	_draw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_draw_mat.render_priority = 9   # après la mer (transparente), avant la pluie
	quad.material = _draw_mat
	_particles.draw_pass_1 = quad
	add_child(_particles)


## Chaque image : `center` (scène) le bateau, `wind` la direction du vent (monde x/z), `fill` 0…1 : les voiles prennent-elles
## le vent ? (plus de traînées, plus vives), `show` : en mer seulement.
func update(center: Vector3, wind: Vector2, fill: float, show: bool) -> void:
	_particles.emitting = show
	visible = show
	if not show:
		return
	global_position = center + Vector3(-wind.x, 0.0, -wind.y) * GameConfig.WIND_STREAK_BOX.x * 0.6 + Vector3(0, GameConfig.WIND_STREAK_HEIGHT, 0)
	_mat.direction = Vector3(wind.x, 0.0, wind.y)
	var pace := lerpf(0.75, 1.25, fill)
	_mat.initial_velocity_min = GameConfig.WIND_STREAK_SPEED * 0.85 * pace
	_mat.initial_velocity_max = GameConfig.WIND_STREAK_SPEED * 1.15 * pace
	_particles.amount_ratio = lerpf(0.45, 1.0, fill)
	_draw_mat.albedo_color.a = GameConfig.WIND_STREAK_ALPHA * lerpf(0.7, 1.0, fill)
