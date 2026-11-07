shader_type spatial;
// Mer « mélange Sea of Thieves / Eastward » :
// - vraie houle : le maillage est soulevé par les mêmes vagues que la flottaison du bateau
//   (data/sea.json, envoyées par le jeu), plus des vaguelettes qui ne servent qu'à l'éclairage ;
// - rendu en aplats : l'orientation de chaque vaguelette vers le soleil choisit un ton parmi 4
//   (creux, flanc, face éclairée, crête), comme une mer peinte en pixel art ;
// - reflets : éclats du soleil, reflet du ciel sur les pentes tournées vers la caméra, moutons
//   d'écume sur les plus hautes crêtes ;
// - le bateau baigne dedans : écume au contact exact de la coque, sillage de Kelvin, ombre du pont ;
// - tout ce qui bouge avance par paliers (pas de glissement au sous-pixel = pas de scintillement).
render_mode cull_back, ambient_light_disabled, specular_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

// Tons de la mer (sRGB). Ils sont aussi dans la palette du filtre pixel art (tools/art/sea_palette.json).
uniform vec3 c_trough : source_color = vec3(0.071, 0.239, 0.361);
uniform vec3 c_side : source_color = vec3(0.110, 0.361, 0.459);
uniform vec3 c_lit : source_color = vec3(0.239, 0.569, 0.620);
uniform vec3 c_crest : source_color = vec3(0.580, 0.831, 0.800);
uniform vec3 c_sky : source_color = vec3(0.400, 0.549, 0.749);
uniform vec3 c_glint : source_color = vec3(1.000, 0.851, 0.600);
uniform vec3 foam_color : source_color = vec3(0.933, 0.965, 0.941);
uniform float contact_foam = 0.32;   // m : en dessous de cette épaisseur d'eau, elle écume contre la coque
uniform float band_width = 0.05;     // écart d'éclairement entre deux tons

uniform vec4 waves[4];               // houle : (amplitude m, kx, kz, pulsation) — voir data/sea.json
uniform float sea_time = 0.0;        // temps de la houle, par paliers (même valeur que la flottaison)
uniform vec3 sun_dir = vec3(0.4, 0.75, 0.5);     // vers le soleil, unitaire (envoyé par le jeu)
uniform vec3 view_dir = vec3(0.0, 0.788, 0.616); // vers la caméra, unitaire (envoyé par le jeu)
uniform vec2 ship_center = vec2(0.0);
uniform vec2 ship_fwd = vec2(1.0, 0.0);
uniform float ship_speed = 0.0;      // 0..1 de la vitesse maximale
uniform float hull_len = 20.0;
uniform float hull_beam = 6.0;
uniform int debug_view = 0;          // 1 : épaisseur d'eau en gris (diagnostic)
uniform vec2 world_offset = vec2(0.0);       // origine flottante : position monde du bateau
uniform vec2 shadow_offset = vec2(1.0, 1.0); // décalage (m) de l'ombre du pont sur l'eau

// Vaguelettes d'éclairage seulement (amplitude m, kx, kz, pulsation) : elles dessinent la surface
// sans déplacer le maillage ni le bateau.
// Vagues de vent : surtout orientées selon z, donc des crêtes allongées de gauche à droite.
const vec4 RIPPLES[5] = vec4[](
	vec4(0.055, 0.35, 1.45, 2.0),
	vec4(0.045, -0.55, 1.95, 2.5),
	vec4(0.035, 0.85, 2.55, 3.1),
	vec4(0.028, -1.25, 3.05, 3.7),
	vec4(0.018, 1.70, 3.90, 4.4));

varying vec3 wp;
varying float wave_h;
varying float wake_foam;

// Distance (m) au bord de la coque à la ligne de flottaison ; négative sous le bateau.
// Même profil que la coque modélisée (tools/art/blender/make_ship.py, station()).
// .x : distance ; .y : position le long de la coque (0 = poupe, 1 = étrave)
vec2 hull_dist(vec2 p) {
	vec2 rel = p - ship_center;
	float along = dot(rel, ship_fwd);
	float side = abs(dot(rel, vec2(-ship_fwd.y, ship_fwd.x)));
	float u = along / hull_len + 0.5;
	float uc = clamp(u, 0.0, 1.0);
	float half_w = hull_beam * 0.5 * (0.90 + 0.10 * min(1.0, uc * 3.0)) * (1.0 - 0.96 * pow(uc, 2.4)) * 0.985;
	float dy = side - half_w;
	float dx = max(-along - hull_len * 0.5, along - hull_len * 0.5);
	return vec2(length(max(vec2(dx, dy), vec2(0.0))) + min(max(dx, dy), 0.0), uc);
}

float waves_at(vec2 p) {
	float h = 0.0;
	for (int i = 0; i < 4; i++) {
		h += waves[i].x * sin(p.x * waves[i].y + p.y * waves[i].z + sea_time * waves[i].w);
	}
	return h;
}

// pente de la surface (houle + vaguelettes) et hauteur des vaguelettes
vec3 slope_at(vec2 p, float t_ripple) {
	vec2 g = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		g += waves[i].x * cos(p.x * waves[i].y + p.y * waves[i].z + sea_time * waves[i].w) * waves[i].yz;
	}
	float hr = 0.0;
	// déformation lente du motif : les crêtes ondulent au lieu de former une grille régulière
	vec2 q = p + vec2(sin(p.y * 0.23 + p.x * 0.11) * 1.6, sin(p.x * 0.19 - p.y * 0.07) * 1.1);
	// les vaguelettes sont plus fortes par endroits (risées) et presque absentes ailleurs
	float gust = 0.55 + 0.45 * sin(p.x * 0.09 + p.y * 0.13) * sin(p.x * 0.05 - p.y * 0.11 + 1.3);
	for (int i = 0; i < 5; i++) {
		float ph = q.x * RIPPLES[i].y + q.y * RIPPLES[i].z + t_ripple * RIPPLES[i].w;
		float a = RIPPLES[i].x * gust;
		g += a * cos(ph) * RIPPLES[i].yz;
		hr += a * sin(ph);
	}
	return vec3(g, hr);
}

// x : soulèvement de l'eau par le sillage (m) ; y : écume du sillage (0..1)
vec2 wake_at(vec2 p) {
	if (ship_speed < 0.02) {
		return vec2(0.0);
	}
	vec2 rel = p - ship_center;
	float along = dot(rel, ship_fwd);
	float side = abs(dot(rel, vec2(-ship_fwd.y, ship_fwd.x)));
	float behind = hull_len * 0.5 - along;        // distance derrière l'étrave
	if (behind < 0.0) {
		return vec2(0.0);
	}
	float arm = behind * 0.354 + hull_beam * 0.3;  // tan(19,5°)
	float width = 0.28 + behind * 0.02;
	float d = side - arm;
	float fade = exp(-behind / (12.0 + 30.0 * ship_speed)) * ship_speed;
	float arms = exp(-(d * d) / (width * width)) * fade;
	float lift = arms * 0.3 * (0.6 + 0.4 * sin(behind * 1.5 - sea_time * 3.0));
	float past_stern = behind - hull_len;
	float churn = 0.0;
	if (past_stern > -1.0) {
		churn = smoothstep(hull_beam * 0.55 + max(past_stern, 0.0) * 0.05, 0.0, side)
				* exp(-max(past_stern, 0.0) / (5.0 + 16.0 * ship_speed)) * ship_speed;
	}
	return vec2(lift, max(arms, churn * 0.75));
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g = w.xz + world_offset;   // coordonnées monde réelles
	float h = waves_at(g);
	vec2 wk = wake_at(g);
	VERTEX.y += h + wk.x;
	wp = vec3(g.x, w.y, g.y);
	wave_h = h + wk.x;
	wake_foam = wk.y;
}

void fragment() {
	// épaisseur d'eau entre la surface et ce qu'il y a dessous, le long du regard (pour l'écume
	// tout contre la coque)
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float thickness = VERTEX.z - behind.z;

	// les vaguelettes changent de dessin 6 fois par seconde : animation de pixel art, sans glissement
	// animation continue : à la bonne cadence (144 images/s), des paliers font « sauter » toute la mer
	float t_rip = TIME * 0.8;
	float st = TIME * 0.6;
	vec3 s = slope_at(wp.xz, t_rip);
	vec3 n = normalize(vec3(-s.x, 1.0, -s.y));

	// 4 tons selon l'orientation de la surface vers le soleil (écart à une mer parfaitement plate)
	// le ton moyen domine ; creux, faces éclairées et crêtes sont des accents
	float lit = dot(n, sun_dir) - sun_dir.y;
	vec3 col = c_trough;
	col = mix(col, c_side, step(-band_width * 2.2, lit));
	col = mix(col, c_lit, step(band_width * 0.9, lit));
	col = mix(col, c_crest, step(band_width * 2.6, lit));
	// reflet du ciel sur les pentes nettement tournées vers la caméra
	float facing = dot(n, view_dir) - view_dir.y;
	col = mix(col, c_sky, step(band_width * 2.4, facing) * step(lit, band_width * 0.9));
	// éclats du soleil : là où la vaguelette renvoie le soleil vers la caméra
	vec3 half_v = normalize(sun_dir + view_dir);
	float spec = dot(n, half_v) - half_v.y;
	col = mix(col, c_glint, step(band_width * 3.2, spec));
	// moutons d'écume sur les plus hautes crêtes (houle + vaguelettes)
	float cap = wave_h * 0.6 + s.z;
	col = mix(col, foam_color, step(0.24, cap) * step(0.15, lit + 0.12));

	// ombre du pont sur l'eau (l'eau transparente ne reçoit pas les ombres du moteur)
	float shade = smoothstep(0.35, -0.35, hull_dist(wp.xz - shadow_offset).x);
	col *= mix(1.0, 0.62, shade);

	// écume au contact de la coque : elle part exactement du flanc, monte quand une vague le
	// frappe, s'épaissit à l'étrave quand le bateau avance, et se déchire avec le motif de l'eau
	float nz = sin(wp.x * 3.1 + st * 2.0) * sin(wp.z * 2.7 - st * 1.6);
	vec2 hd = hull_dist(wp.xz);
	float n2 = sin(wp.x * 2.3 - st * 2.6 + wp.z * 1.1) * sin(wp.z * 3.4 + st * 1.9 - wp.x * 0.7);
	float band = 0.22 + 0.25 * ship_speed + max(wave_h, 0.0) * 1.6;
	band *= 1.0 + smoothstep(0.7, 1.0, hd.y) * (0.3 + 1.0 * ship_speed);
	float ring = step(0.0, hd.x) * step(hd.x, band * (0.7 + 0.35 * n2));
	float ring_far = step(band * 1.2, hd.x) * step(hd.x, band * 1.55) * step(0.7, n2);
	float contact = max(1.0 - step(contact_foam * (0.75 + 0.35 * nz), thickness), max(ring, ring_far));
	float wake = step(0.72, wake_foam + 0.3 * nz);
	col = mix(col, foam_color, max(contact, wake));

	ALBEDO = debug_view == 1 ? vec3(clamp(thickness / 4.0, 0.0, 1.0)) : col;
	ALPHA = 1.0;
}

void light() {
	// la mer garde ses tons choisis ; seule la lanterne de la cabine ajoute une lueur
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += vec3(1.0);
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * 0.25;
	}
}
