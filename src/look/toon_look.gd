class_name ToonLook
extends RefCounted
## Prototype de refonte graphique (12/11/2026, design/bible-direction-artistique.md, section 3) : « pixel art en 3D ».
## - Lumière en paliers : les matières passent en éclairage « toon » (frontière nette entre face éclairée et face à l'ombre)
##   au lieu d'un dégradé ; l'ambiance froide (bleu-violet) colore les ombres, le soleil chaud colore les lumières.
## - Contours seulement sur les silhouettes et reflets clairs sur les arêtes (voir PixelEdges, shaders/pixel_edges.gdshader).
## - Couleurs vraies, sans la palette fixe du filtre (elle aplatissait les ombres colorées) ; l'étalonnage de l'heure reste.
## Activé par GameConfig.LOOK_V2 ; --look=1 au lancement remet l'ancien rendu (pour comparer).

static var enabled := GameConfig.LOOK_V2
static var _variants: Dictionary = {}   ## Shader d'origine -> sa version « toon »


## Passe en lumière toon toutes les matières d'un décor (le port, un bateau) : StandardMaterial3D et nos shaders de surface.
static func apply_tree(root: Node) -> void:
	if not enabled or root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		if mi.material_override != null:
			mi.material_override = toonify(mi.material_override)
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			if m != null:
				mi.set_surface_override_material(s, toonify(m))
			else:
				var base := mi.mesh.surface_get_material(s)
				if base != null:
					var c := toonify(base)
					if c != base:
						mi.set_surface_override_material(s, c)


## La version toon d'une matière (la même si elle n'est pas concernée : sans lumière, transparente, etc.).
static func toonify(m: Material) -> Material:
	if m is StandardMaterial3D or m is ORMMaterial3D:
		var b := m as BaseMaterial3D
		if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			return m
		if b.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON:
			return m
		# (modifiée sur place : les skins de bateau et les autres navires qui partagent la matière suivent)
		b.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		b.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		b.metallic = 0.0
		b.roughness = GameConfig.TOON_ROUGHNESS
		return m
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		sm.shader = variant(sm.shader)
		return m
	return m


## La version toon d'un de nos shaders spatiaux : on lui ajoute `diffuse_toon` et une rugosité plus faible (frontière nette).
## Les shaders qui ont leur propre éclairage, sont sans lumière ou transparents restent tels quels.
static func variant(sh: Shader) -> Shader:
	if sh == null:
		return sh
	if _variants.has(sh):
		return _variants[sh]
	var code := sh.code
	var out := sh
	if code.begins_with("shader_type spatial") and not code.contains("render_mode") and not code.contains("void light()") \
			and not code.contains("ALPHA"):
		var lines := code.split("\n")
		lines.insert(1, "render_mode diffuse_toon, specular_disabled;")
		var v := Shader.new()
		v.code = "\n".join(lines).replace("ROUGHNESS = 1.0;", "ROUGHNESS = %.2f;" % GameConfig.TOON_ROUGHNESS)
		out = v
	_variants[sh] = out
	return out
