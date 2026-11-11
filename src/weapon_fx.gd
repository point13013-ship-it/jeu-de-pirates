class_name WeaponFx
extends RefCounted
## Les effets d'un tir ou d'un coup de sabre dans le monde : traînée (droite, zigzag de foudre, ondulation d'aurore, pointillés d'étoiles
## ou de pièces...), éclair de bouche et jets de particules. Chaque skin d'arme choisit un style (data/weapon_skins.json, « fx ») et deux
## couleurs ; sans skin, c'est l'ancien tir : traînée de la couleur de l'arme, éclair et fumée.

## Un jet de particules par style : count, speed, spread (degrés), grav (m/s², positif = tombe), size (m), life (s), mesh, trail (points
## semés le long de la traînée), tracer (forme de la traînée), fade (les particules s'effacent), extra (teinte de plus : "white", "gold").
const STYLES := {
	"sparks": {"count": 10, "speed": 5.0, "spread": 55.0, "grav": 6.0, "size": 0.08, "life": 0.35, "mesh": "box", "trail": 0, "tracer": "line"},
	"coins": {"count": 7, "speed": 4.8, "spread": 60.0, "grav": 9.0, "size": 0.17, "life": 0.75, "mesh": "coin", "trail": 5, "tracer": "dots"},
	"bubbles": {"count": 9, "speed": 2.4, "spread": 80.0, "grav": -2.0, "size": 0.13, "life": 1.0, "mesh": "sphere", "trail": 5, "tracer": "line", "fade": true},
	"lightning": {"count": 9, "speed": 6.0, "spread": 70.0, "grav": 2.0, "size": 0.07, "life": 0.3, "mesh": "box", "trail": 0, "tracer": "zigzag"},
	"notes": {"count": 5, "speed": 2.2, "spread": 60.0, "grav": -1.0, "size": 0.12, "life": 0.9, "mesh": "sphere", "trail": 4, "tracer": "wave", "fade": true},
	"flame": {"count": 46, "speed": 7.0, "spread": 20.0, "grav": -1.0, "size": 0.24, "life": 0.45, "mesh": "sphere", "trail": 0, "tracer": "none", "fade": true},
	"petals": {"count": 14, "speed": 3.6, "spread": 70.0, "grav": 1.3, "size": 0.15, "life": 1.2, "mesh": "quad", "trail": 6, "tracer": "dots"},
	"ink": {"count": 10, "speed": 4.0, "spread": 40.0, "grav": 3.0, "size": 0.22, "life": 0.7, "mesh": "sphere", "trail": 5, "tracer": "line", "fade": true},
	"confetti": {"count": 32, "speed": 6.5, "spread": 38.0, "grav": 6.0, "size": 0.1, "life": 1.0, "mesh": "quad", "trail": 0, "tracer": "none", "extra": "party"},
	"beam": {"count": 8, "speed": 4.0, "spread": 60.0, "grav": 2.0, "size": 0.07, "life": 0.4, "mesh": "box", "trail": 0, "tracer": "beam"},
	"aurora": {"count": 10, "speed": 2.0, "spread": 90.0, "grav": -0.5, "size": 0.1, "life": 0.9, "mesh": "sphere", "trail": 8, "tracer": "wave", "fade": true},
	"stars": {"count": 12, "speed": 3.0, "spread": 80.0, "grav": 0.5, "size": 0.12, "life": 0.9, "mesh": "star", "trail": 9, "tracer": "dots"},
	"thorns": {"count": 10, "speed": 3.6, "spread": 55.0, "grav": 2.0, "size": 0.1, "life": 0.8, "mesh": "box", "trail": 5, "tracer": "zigzag", "extra": "petal"},
	"embers": {"count": 14, "speed": 3.0, "spread": 90.0, "grav": -2.0, "size": 0.09, "life": 0.9, "mesh": "box", "trail": 0, "tracer": "none", "fade": true},
	"ghost": {"count": 9, "speed": 1.6, "spread": 90.0, "grav": -1.2, "size": 0.28, "life": 1.3, "mesh": "sphere", "trail": 0, "tracer": "none", "fade": true, "ghost": true},
	"slash": {"count": 0, "speed": 0.0, "spread": 0.0, "grav": 0.0, "size": 0.1, "life": 0.3, "mesh": "box", "trail": 0, "tracer": "none"},
}
const PARTY := [Color(1.0, 0.35, 0.4), Color(0.3, 0.8, 1.0), Color(1.0, 0.85, 0.3), Color(0.5, 1.0, 0.5), Color(1.0, 0.5, 1.0)]


static func style_of(skin_def: Dictionary) -> Dictionary:
	var fx: Dictionary = skin_def.get("fx", {})
	var st: Dictionary = (STYLES.get(str(fx.get("style", "sparks")), STYLES["sparks"]) as Dictionary).duplicate()
	st["a"] = Color.html(str(fx.get("a", "#ffe9a8")))
	st["b"] = Color.html(str(fx.get("b", "#ffb347")))
	return st


## Un tir : `origin`/`dir` dans le plan du sol (x, z), `y` la hauteur de l'arme, `pellets` projectiles de portée `reach`.
## `skin_def` : WeaponSkins.def_of ; `base_color` : la couleur de l'arme (traînée des armes sans skin).
static func shot(parent: Node3D, origin: Vector2, dir: Vector2, pellets: int, reach: float, spread: float, base_color: Color, skin_def: Dictionary, y: float) -> void:
	var st := style_of(skin_def)
	var skinned: bool = skin_def.get("fx", {}).get("style", "sparks") != "sparks" or skin_def.get("name", "Classique") != "Classique"
	var a: Color = st["a"] if skinned else base_color
	var b: Color = st["b"] if skinned else base_color
	for k in pellets:
		var d := dir.rotated(randf_range(-spread, spread)) if spread > 0.0 else dir
		var from := origin + d * 0.7
		var to := origin + d * reach
		_tracer(parent, from, to, str(st["tracer"]) if skinned else "line", a, b, pellets > 1, y)
		var n := int(st["trail"]) if skinned else 0
		if n > 0 and k < 3:
			for i in n:
				var p := from.lerp(to, (float(i) + 0.5) / float(n))
				_emit(parent, Vector3(p.x, y, p.y), Vector3(d.x, 0.2, d.y), st, a, b, maxi(int(st["count"]) / n, 1), 0.35)
	var muzzle := Vector3(origin.x + dir.x * 0.85, y, origin.y + dir.y * 0.85)
	_flash(parent, muzzle, a if skinned else Color(1.0, 0.85, 0.45), 0.3)
	if skinned and int(st["count"]) > 0:
		_emit(parent, muzzle, Vector3(dir.x, 0.15, dir.y), st, a, b, int(st["count"]), 1.0)
	if skinned and skin_def.get("fx", {}).get("style", "") == "notes":
		for i in 3:
			_note(parent, muzzle + Vector3(dir.x, 0.0, dir.y) * (0.6 + 0.9 * i), a if i % 2 == 0 else b)
	_smoke(parent, muzzle + Vector3(dir.x, 0.0, dir.y) * 0.1, dir, Color(0.82, 0.82, 0.85) if not skinned else a.lerp(Color(0.85, 0.85, 0.9), 0.55))


## Une note de musique qui monte et s'efface (skin « Chant de sirène »).
static func _note(parent: Node3D, at: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = "♪"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 64
	l.pixel_size = 0.012
	l.modulate = col
	l.outline_size = 8
	l.outline_modulate = Color(0.1, 0.05, 0.2)
	l.no_depth_test = true
	l.shaded = false
	parent.add_child(l)
	l.position = at
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", at + Vector3(randf_range(-0.4, 0.4), 1.3, 0.0), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## Un coup de sabre : jets de particules le long de l'arc.
static func slash(parent: Node3D, origin: Vector2, dir: Vector2, skin_def: Dictionary, y: float) -> void:
	var st := style_of(skin_def)
	if str(skin_def.get("fx", {}).get("style", "slash")) == "slash":
		return
	for off in [-0.6, 0.0, 0.6]:
		var d := dir.rotated(off)
		var p := origin + d * 1.5
		var tr := str(st["tracer"])
		if tr == "zigzag":
			_tracer(parent, origin + d * 0.6, origin + d * 2.4, "zigzag", st["a"], st["b"], false, y)
		_emit(parent, Vector3(p.x, y, p.y), Vector3(d.x, 0.25, d.y), st, st["a"], st["b"], maxi(int(st["count"]) / 3, 3), 0.8)


static func _mat(c: Color, alpha: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	return m


## La traînée d'un projectile : une suite de petites boîtes de `a` vers `b`, droite, en zigzag (foudre), ondulée (aurore, notes),
## en pointillés ou double (rayon).
static func _tracer(parent: Node3D, from: Vector2, to: Vector2, kind: String, a: Color, b: Color, many: bool, y: float) -> void:
	if kind == "none":
		return
	var seg := to - from
	var len := seg.length()
	if len < 0.1:
		return
	var fwd := seg / len
	var side := Vector2(-fwd.y, fwd.x)
	var n := 1
	var width := 0.06 if many else 0.09
	match kind:
		"zigzag":
			n = maxi(int(len / 0.9), 4)
		"wave":
			n = maxi(int(len / 0.5), 6)
			width = 0.1
		"dots":
			n = maxi(int(len / 0.9), 5)
			width = 0.1
		"beam":
			n = 1
			width = 0.05
		_:
			n = 5
	var pts: Array[Vector2] = []
	for i in n + 1:
		var t := float(i) / float(n)
		var p := from.lerp(to, t)
		match kind:
			"zigzag":
				if i > 0 and i < n:
					p += side * randf_range(-0.32, 0.32)
			"wave":
				p += side * sin(t * TAU * 3.0) * 0.3
		pts.append(p)
	for i in n:
		if kind == "dots" and i % 2 == 1:
			continue
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var s := p1 - p0
		var col := a.lerp(b, float(i) / float(maxi(n - 1, 1)))
		_box(parent, (p0 + p1) * 0.5, y, s, width if kind != "dots" else width * 1.6, col, 0.16 if kind != "beam" else 0.22)
		if kind == "beam":   # un cœur blanc dans un halo
			_box(parent, (p0 + p1) * 0.5, y, s, width * 3.5, b, 0.3, 0.35)


static func _box(parent: Node3D, mid: Vector2, y: float, seg: Vector2, width: float, col: Color, life: float, alpha: float = 0.92) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width * 0.8, maxf(seg.length(), 0.05))
	mi.mesh = bm
	var m := _mat(Color(col.r, col.g, col.b, alpha))
	m.vertex_color_use_as_albedo = false
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = Vector3(mid.x, y, mid.y)
	mi.rotation.y = atan2(seg.x, seg.y)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.tween_callback(mi.queue_free)


static func _flash(parent: Node3D, at: Vector3, col: Color, size: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	mi.mesh = sm
	var m := _mat(Color(col.r, col.g, col.b, 1.0), false)
	m.vertex_color_use_as_albedo = false
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = at
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ZERO, 0.12)
	tw.tween_callback(mi.queue_free)


static func _smoke(parent: Node3D, at: Vector3, dir: Vector2, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	mi.mesh = sm
	var m := _mat(Color(col.r, col.g, col.b, 0.7))
	m.vertex_color_use_as_albedo = false
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = at
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "position", at + Vector3(dir.x, 0.5, dir.y) * 1.2, 0.8)
	tw.tween_property(mi, "scale", Vector3.ONE * 2.2, 0.8)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.8)
	tw.chain().tween_callback(mi.queue_free)


## Un jet de particules à `at` dirigé vers `dir`.
static func _emit(parent: Node3D, at: Vector3, dir: Vector3, st: Dictionary, a: Color, b: Color, count: int, power: float) -> void:
	if count <= 0:
		return
	var p := CPUParticles3D.new()
	p.amount = count
	p.lifetime = float(st["life"])
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = float(st["spread"])
	p.initial_velocity_min = float(st["speed"]) * 0.5 * power
	p.initial_velocity_max = float(st["speed"]) * power
	p.gravity = Vector3(0.0, -float(st["grav"]), 0.0)
	var size := float(st["size"])
	match str(st["mesh"]):
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 6
			sm.rings = 3
			p.mesh = sm
		"quad", "coin", "star":
			var qm := QuadMesh.new()
			qm.size = Vector2(1.0, 1.0)
			p.mesh = qm
		_:
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE
			p.mesh = bm
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	p.angle_max = 360.0
	var grad := Gradient.new()
	var fade := bool(st.get("fade", false))
	var party: bool = str(st.get("extra", "")) == "party"
	if party:
		grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		grad.colors = PackedColorArray([PARTY[0], PARTY[1], PARTY[2], PARTY[3], Color(PARTY[4], 0.0)])
	else:
		var mid := a.lerp(b, 0.5)
		grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		grad.colors = PackedColorArray([a, mid, Color(b.r, b.g, b.b, 0.0)])
	p.color_ramp = grad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if str(st["mesh"]) in ["quad", "coin", "star"]:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
	if st.get("ghost", false):
		m.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = at
	p.emitting = true
	var tree := parent.get_tree()
	if tree != null:
		var tm := tree.create_timer(float(st["life"]) + 0.3)
		tm.timeout.connect(p.queue_free)
