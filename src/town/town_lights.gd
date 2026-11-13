class_name TownLights
extends Node3D
## Les lumières de la ville v3 (13/11/2026, étape 4 de design/ville-v3/conception.md). Pas d'illumination globale possible avec
## notre caméra orthographique : chaque source est posée à la main, et les reflets sont dessinés.
## - lanternes : un poteau, une lanterne qui brille, une vraie lumière (OmniLight) qui éclaire le sol et les murs autour ;
##   les deux plus proches du pirate portent des ombres ;
## - fenêtres : les vitres des maisons habitées s'allument (matière émissive, halo du « glow ») et jettent une tache de lumière
##   chaude sur le sol devant la façade ;
## - reflets : sous chaque lanterne du bord de l'eau, une traînée dorée en tirets qui danse sur la mer.
## Tout suit `night` (0 le jour, 1 la nuit) : rien n'est allumé à midi.

const WARM := Color(1.0, 0.72, 0.24)   # (plus jaune que la palette : l'étalonnage bleu de la nuit le ramène vers l'orange)
const WARM_LIGHT := Color("ffe2a0")
const POST := Color("2e2a44")
const LAMP_HEIGHT := 3.1

var _lights: Array[OmniLight3D] = []
var _lantern_mat: StandardMaterial3D
var _spill_mat: StandardMaterial3D
var _streak_mat: ShaderMaterial
var _beacon: OmniLight3D
var _beam_mat: StandardMaterial3D
var _glass: Array = []          # [matière, matière fantôme, allumée ?]
var _night := -1.0
var _cull_t := 0.0


## Où poser les lanternes : le long du quai et de la Grand-Rue, plus espacées ailleurs, une au bout de chaque ponton, trois autour
## de chaque place. Renvoie des Vector2 en coordonnées du fichier.
static func lamp_points(plan: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s: Dictionary in plan.get("streets", []):
		var id := str(s["id"])
		var width := float(s["width"])
		if width < 3.0:
			continue
		var every := GameConfig.LAMP_EVERY_MAIN if id in ["quai", "grand_rue"] else GameConfig.LAMP_EVERY
		var pts := Land._poly(s["pts"])
		var run := every * 0.5
		var side := 1.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var len := a.distance_to(b)
			while run <= len:
				var n := (b - a).normalized().orthogonal()
				if id == "quai":
					side = -1.0 if n.y > 0.0 else 1.0   # toujours du côté de l'eau (le sud)
				out.append(a.lerp(b, run / len) + n * side * (width * 0.5 - 0.35))
				if id != "quai":
					side = -side
				run += every
			run -= len
	for pl: Dictionary in plan.get("plazas", []):
		for k in 3:
			var a2 := TAU * (float(k) / 3.0) + 0.6
			out.append(Vector2(float(pl["x"]) + cos(a2) * (float(pl["rx"]) - 0.6), float(pl["y"]) + sin(a2) * (float(pl["ry"]) - 0.6)))
	for pt: Dictionary in plan.get("pontoons", []):
		var a3 := Vector2(float(pt["a"][0]), float(pt["a"][1]))
		var b3 := Vector2(float(pt["b"][0]), float(pt["b"][1]))
		out.append(b3 + (a3 - b3).normalized() * 0.8 + (b3 - a3).normalized().orthogonal() * (float(pt["width"]) * 0.5 - 0.25))
	return out


## Pose les lanternes (`lamps` : [Vector2 fichier, hauteur du sol]), les taches des fenêtres (`spills` : [centre, largeur, angle,
## hauteur du sol] des façades sud des maisons allumées) et les reflets sur l'eau.
func setup(lamps: Array, spills: Array, land: Land, sea_y: float, extras: Dictionary = {}) -> void:
	# lumières sans poteau : lanternes pendues à l'entrée des tentes, braises de la forge
	for at: Vector3 in extras.get("lamps", []):
		var hang := OmniLight3D.new()
		hang.light_color = WARM
		hang.light_energy = 0.0
		hang.omni_range = GameConfig.LAMP_RANGE * 0.8
		hang.omni_attenuation = 1.3
		hang.shadow_enabled = false
		hang.position = at
		add_child(hang)
		_lights.append(hang)
	# le feu du phare : une forte lumière et deux faisceaux qui tournent
	if extras.has("beacon"):
		var top: Vector3 = extras["beacon"]
		_beacon = OmniLight3D.new()
		_beacon.light_color = Color(1.0, 0.86, 0.5)
		_beacon.light_energy = 0.0
		_beacon.omni_range = 22.0
		_beacon.shadow_enabled = false
		_beacon.position = top
		add_child(_beacon)
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_beam_mat.vertex_color_use_as_albedo = true
		_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_beam_mat.albedo_color = Color(0, 0, 0)
		_beam_mat.render_priority = 9
		var spin := TownLandmarks.Spinner.new()
		spin.speed = 0.5
		spin.position = top
		var bt := SurfaceTool.new()
		bt.begin(Mesh.PRIMITIVE_TRIANGLES)
		for dir: float in [-1.0, 1.0]:
			var pts: Array = [[Vector3(0, 0.25, 0), 0.5], [Vector3(0, -0.25, 0), 0.5], [Vector3(dir * 34.0, -3.5, 3.0), 0.0], [Vector3(dir * 34.0, 0.5, -3.0), 0.0]]
			for i: int in [0, 1, 2, 0, 2, 3]:
				var k := float(pts[i][1])
				bt.set_color(Color(k, k * 0.86, k * 0.5))
				bt.set_normal(Vector3.UP)
				bt.add_vertex(pts[i][0] as Vector3)
		var bm := MeshInstance3D.new()
		bm.mesh = bt.commit()
		bm.material_override = _beam_mat
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spin.add_child(bm)
		add_child(spin)
	_lantern_mat = StandardMaterial3D.new()
	_lantern_mat.albedo_color = WARM_LIGHT
	_lantern_mat.emission_enabled = true
	_lantern_mat.emission = WARM
	_lantern_mat.emission_energy_multiplier = 0.0
	var posts := SurfaceTool.new()
	posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lanterns := SurfaceTool.new()
	lanterns.begin(Mesh.PRIMITIVE_TRIANGLES)
	var streaks := SurfaceTool.new()
	streaks.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e: Array in lamps:
		var p: Vector2 = e[0]
		var h := float(e[1])
		TownGreybox._raw_box(posts, p, Vector2(0.14, 0.14), 0.0, h, h + LAMP_HEIGHT)
		TownGreybox._raw_box(posts, p, Vector2(0.34, 0.34), 0.0, h, h + 0.25)
		TownGreybox._raw_box(posts, p, Vector2(0.4, 0.4), 0.0, h + LAMP_HEIGHT + 0.36, h + LAMP_HEIGHT + 0.44)
		TownGreybox._raw_box(lanterns, p, Vector2(0.3, 0.3), 0.0, h + LAMP_HEIGHT, h + LAMP_HEIGHT + 0.36)
		var light := OmniLight3D.new()
		light.light_color = WARM
		light.light_energy = 0.0
		light.omni_range = GameConfig.LAMP_RANGE
		light.omni_attenuation = 1.3
		light.shadow_enabled = false
		light.position = Vector3(p.x, h + LAMP_HEIGHT - 0.1, -p.y)
		add_child(light)
		_lights.append(light)
		# reflet : la première eau au sud de la lanterne, à 7 m au plus
		for k in 15:
			var q := p + Vector2(0.0, -0.5 * (k + 1))
			if land.is_over_water(Vector2(q.x, -q.y)):
				_streak(streaks, q + Vector2(0.0, -0.3), sea_y + 0.45)
				break
	var pm := MeshInstance3D.new()
	pm.mesh = posts.commit()
	pm.material_override = TownGreybox._mat(POST)
	add_child(pm)
	var lm := MeshInstance3D.new()
	lm.mesh = lanterns.commit()
	lm.material_override = _lantern_mat
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lm)

	# taches de lumière devant les façades : vives au pied du mur, éteintes à 2,8 m
	_spill_mat = StandardMaterial3D.new()
	_spill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spill_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spill_mat.vertex_color_use_as_albedo = true
	_spill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_spill_mat.albedo_color = Color(0, 0, 0)
	_spill_mat.render_priority = 2
	var spill := SurfaceTool.new()
	spill.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: Array in spills:
		var c: Vector2 = s[0]
		var half := float(s[1]) * 0.5
		var ang := float(s[2])
		var y := float(s[3]) + 0.09
		var near := Color(0.55, 0.36, 0.16)
		var corners: Array[Vector3] = []
		for v: Vector2 in [Vector2(-half, 0.0), Vector2(half, 0.0), Vector2(half + 0.8, -2.8), Vector2(-half - 0.8, -2.8)]:
			var q2 := c + v.rotated(ang)
			corners.append(Vector3(q2.x, y, -q2.y))
		var cols: Array[Color] = [near, near, Color(0, 0, 0), Color(0, 0, 0)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			spill.set_color(cols[i])
			spill.set_normal(Vector3.UP)
			spill.add_vertex(corners[i])
	var sm := MeshInstance3D.new()
	sm.mesh = spill.commit()
	sm.material_override = _spill_mat
	sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sm)

	# reflets sur l'eau
	_streak_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
// Reflet d'une lanterne sur l'eau : une traînée dorée en tirets, qui ondule et se défait vers le large.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float night = 0.0;
varying float fade;
varying float across;
varying vec3 wp;
float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}
void vertex() {
	fade = COLOR.r;
	across = COLOR.g * 2.0 - 1.0;
	wp = VERTEX;
}
void fragment() {
	// des tirets de largeur inégale, décalés d'un rang à l'autre, qui glissent lentement et changent trois fois par seconde
	float rows = wp.z * 1.9 - TIME * 0.35;
	float row = floor(rows);
	float h = hash(row + floor(TIME * 3.0) * 0.37);
	float half_w = 0.25 + 0.75 * hash(row * 1.7);
	float shift = (hash(row * 2.3) - 0.5) * 0.7 + sin(TIME * 1.3 + row) * 0.15;
	float dash = step(fract(rows), 0.5) * step(abs(across - shift), half_w) * step(0.2, h);
	ALBEDO = vec3(1.0, 0.55, 0.16) * (0.25 + 0.75 * fade) * dash * night * 1.15;
}
"""
	_streak_mat.shader = sh
	_streak_mat.render_priority = 8   # (après la mer, qui est dessinée dans la passe transparente : sinon elle recouvre le reflet)
	var km := MeshInstance3D.new()
	km.mesh = streaks.commit()
	km.material_override = _streak_mat
	km.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(km)


static func _streak(st: SurfaceTool, at: Vector2, y: float) -> void:
	var len := GameConfig.LAMP_REFLECTION_LENGTH
	var pts: Array = [[Vector2(-0.45, 0.0), 1.0, 0.0], [Vector2(0.45, 0.0), 1.0, 1.0], [Vector2(0.9, -len), 0.0, 1.0], [Vector2(-0.9, -len), 0.0, 0.0]]
	for i: int in [0, 1, 2, 0, 2, 3]:
		var v: Vector2 = at + (pts[i][0] as Vector2)
		st.set_color(Color(float(pts[i][1]), float(pts[i][2]), 0))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(v.x, y, -v.y))


## Les vitres d'une maison : sa matière, sa matière « fantôme », et si elle est habitée ce soir.
func add_glass(mat: ShaderMaterial, ghost: ShaderMaterial, lit: bool) -> void:
	_glass.append([mat, ghost, lit])


## À chaque image : `night` de 0 (jour) à 1 (nuit), `focus` le point que regarde la caméra, `player` le pirate (monde).
func update(night: float, focus: Vector3, player: Vector3, delta: float) -> void:
	if absf(night - _night) > 0.015:
		_night = night
		var on := smoothstep(0.35, 0.8, night)   # (les lanternes s'allument au crépuscule, pas en plein après-midi)
		for l: OmniLight3D in _lights:
			l.light_energy = GameConfig.LAMP_ENERGY * on
		_lantern_mat.emission_energy_multiplier = 0.15 + 3.2 * on
		_spill_mat.albedo_color = Color(on, on, on)
		_streak_mat.set_shader_parameter("night", on)
		if _beacon != null:
			_beacon.light_energy = 5.0 * on
			_beam_mat.albedo_color = Color(on, on, on)
		for g: Array in _glass:
			var lit: bool = g[2]
			var base := Color("2e2a44").lerp(Color("ffb24a"), on) if lit else Color("2e2a44")
			for m: ShaderMaterial in [g[0], g[1]]:
				m.set_shader_parameter("base", base)
				m.set_shader_parameter("emit", (GameConfig.WINDOW_GLOW * on) if lit else 0.0)
	_cull_t -= delta
	if _cull_t > 0.0:
		return
	_cull_t = 0.4
	# seules les lanternes proches de l'écran éclairent ; les deux plus proches du pirate portent des ombres
	var near: Array = []
	for l2: OmniLight3D in _lights:
		l2.visible = _night > 0.3 and l2.position.distance_to(focus) < GameConfig.LAMP_CULL
		near.append([l2.position.distance_to(player), l2])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k in near.size():
		((near[k][1]) as OmniLight3D).shadow_enabled = k < GameConfig.LAMP_SHADOWS and float(near[k][0]) < 16.0
