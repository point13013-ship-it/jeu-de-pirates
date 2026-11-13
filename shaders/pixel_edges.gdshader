shader_type spatial;
// Contours et reflets d'arête façon « pixel art en 3D » (prototype de refonte, 12/11/2026 ; d'après David Holland et le
// shader de Leo Peltola, licence MIT). Un quadrilatère plein écran posé devant la caméra lit la profondeur et les normales :
// - là où un objet se détache d'un fond plus lointain (rupture de profondeur) : un trait sombre d'un pixel, teinté (pas du
//   noir), seulement sur la silhouette ;
// - là où deux faces d'un même objet forment une arête saillante (rupture de normale, profondeur égale) : un pixel plus clair,
//   comme un reflet sur le bord d'une planche ou d'un toit.
// Deux passes avec ce shader : `mode` 0 (assombrit, mélange multiplicatif) et 1 (éclaircit, mélange additif).
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// (le mélange est choisi par le jeu : deux matières, l'une en blend_mul, l'autre en blend_add ; voir PixelEdges)

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform int mode = 0;
uniform float depth_threshold = 0.35;        // m : écart de profondeur qui fait une silhouette
uniform float normal_threshold = 0.45;       // écart de normales qui fait une arête
uniform vec3 outline_tint : source_color = vec3(0.50, 0.44, 0.66);   // multiplicateur du trait : sombre, tiré vers le violet
uniform vec3 highlight : source_color = vec3(0.16, 0.13, 0.08);       // ajout du reflet : chaud
uniform float sea_y = -1.45;                 // sous l'eau, pas de trait (l'eau ne s'écrit pas dans la profondeur)
uniform float shallow_y = -1.05;             // la nappe d'eau claire des rivages (IslandWorld.SHALLOW_Y) : pas de trait sur son bord
uniform float fade_far = 90.0;               // m : au-delà, les traits s'estompent (pas de « bruit » au loin)

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 view_pos(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}

vec3 normal_at(vec2 uv) {
	return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec3 p = view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	float depth = -p.z;
	vec3 world = (INV_VIEW_MATRIX * vec4(p, 1.0)).xyz;
	vec3 n = normal_at(SCREEN_UV);
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	float depth_edge = 0.0;
	float normal_edge = 0.0;
	for (int k = 0; k < 4; k++) {
		vec2 uv = SCREEN_UV + offs[k];
		float dn = -view_pos(uv, INV_PROJECTION_MATRIX).z;
		float dd = dn - depth;                       // > 0 : le voisin est plus loin, je suis sur le bord de l'objet
		depth_edge = max(depth_edge, step(depth_threshold, dd));
		vec3 nn = normal_at(uv);
		// arête saillante : normales différentes, profondeurs proches, et le voisin un peu en retrait (bord convexe)
		float convex = step(-0.02, dd) * step(dd, depth_threshold);
		float diff = dot(n - nn, vec3(0.6, 0.8, 0.2));   // biais : seules les arêtes tournées vers le haut-gauche brillent
		normal_edge = max(normal_edge, convex * step(normal_threshold, diff));
	}
	float far_fade = 1.0 - smoothstep(fade_far * 0.6, fade_far, depth);
	float under = max(step(world.y, sea_y - 0.35), step(abs(world.y - shallow_y), 0.04));
	float sky = step(0.9999, texture(depth_tex, SCREEN_UV).r) + step(texture(depth_tex, SCREEN_UV).r, 0.00001);
	if (mode == 0) {
		float e = depth_edge * far_fade * (1.0 - under);
		ALBEDO = mix(vec3(1.0), outline_tint, e);
	} else {
		float e = normal_edge * (1.0 - depth_edge) * far_fade * (1.0 - under) * (1.0 - clamp(sky, 0.0, 1.0));
		ALBEDO = highlight * e;
	}
}
