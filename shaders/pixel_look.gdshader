shader_type canvas_item;
// Filtre « pixel art » appliqué à l'image 3D basse résolution :
// chaque pixel est ramené à la palette fixe (port + tons de la mer), puis un contour sombre d'un
// pixel est tracé au bord des objets. Pas de contour entre deux tons de mer : sinon chaque vaguelette
// serait cernée de noir.
#include "res://shaders/palette.gdshaderinc"

uniform float outline_threshold = 0.22;
uniform float outline_strength = 0.30;
uniform bool use_palette = true;   // faux : couleurs brutes (diagnostic, mesure des tons)
// Couleurs des pirates (apparence personnalisable) : elles sont hors de la palette du décor et passent
// telles quelles ; seule une correspondance quasi exacte compte, pour ne jamais « voler » un pixel du décor.
uniform sampler2D char_palette : filter_nearest, hint_default_black;
uniform int char_count = 0;

// Étalonnage du ciel (heure, météo) : piloté par SkyCycle. Valeurs neutres = image brute.
uniform vec3 grade_tint = vec3(1.0);        // multiplie tout (lumière de l'heure)
uniform vec3 grade_shadow = vec3(0.0);      // teinte ajoutée aux ombres
uniform vec3 grade_high = vec3(0.0);        // teinte ajoutée aux hautes lumières
uniform float grade_sat = 1.0;
uniform float grade_contrast = 1.0;
uniform float vignette = 0.0;
uniform vec3 haze_color = vec3(0.8);        // brume : couleur, quantité, dérive
uniform float haze_amount = 0.0;
uniform float flash = 0.0;                  // éclair

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s;
}

vec3 grade(vec3 c, vec2 uv) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c *= grade_tint;
	c += grade_shadow * (1.0 - smoothstep(0.0, 0.55, l));
	c += grade_high * smoothstep(0.45, 1.0, l);
	c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, grade_sat);
	c = (c - 0.5) * grade_contrast + 0.5;
	if (haze_amount > 0.001) {
		vec2 q = uv * vec2(3.2, 1.8) + vec2(TIME * 0.018, TIME * 0.007);
		float n = fbm(q + fbm(q * 0.7 + TIME * 0.01) * 0.8);
		float h = haze_amount * (0.45 + 0.9 * n) * mix(1.1, 0.75, uv.y);
		c = mix(c, haze_color, clamp(h, 0.0, 0.9));
	}
	vec2 d = (uv - 0.5) * vec2(1.0, 1.1);
	c *= 1.0 - vignette * smoothstep(0.3, 0.95, length(d));
	c += flash * vec3(0.45, 0.5, 0.65);
	return clamp(c, 0.0, 1.0);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 quantize(vec3 c) {
	if (!use_palette) {
		return c;
	}
	for (int i = 0; i < char_count; i++) {
		vec3 d = texelFetch(char_palette, ivec2(i, 0), 0).rgb - c;
		if (dot(d, d) < 2.5e-4) {
			return c;
		}
	}
	float best = 1e9;
	vec3 chosen = PALETTE[0];
	for (int i = 0; i < PALETTE_SIZE; i++) {
		vec3 d = PALETTE[i] - c;
		float dist = dot(d, d);
		if (dist < best) {
			best = dist;
			chosen = PALETTE[i];
		}
	}
	return chosen;
}

bool is_sea(vec3 q) {
	for (int i = 0; i < SEA_SIZE; i++) {
		vec3 d = SEA[i] - q;
		if (dot(d, d) < 1e-6) {
			return true;
		}
	}
	return false;
}

void fragment() {
	if (!use_palette) {
		// rendu fin : couleurs vraies (pas de palette), seulement l'étalonnage du ciel
		COLOR = vec4(grade(texture(TEXTURE, UV).rgb, UV), 1.0);
	} else {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 q = quantize(texture(TEXTURE, UV).rgb);
	bool sea = is_sea(q);
	float l = lum(q);
	float edge = 0.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int k = 0; k < 4; k++) {
		vec3 nq = quantize(texture(TEXTURE, UV + offs[k]).rgb);
		if (sea && is_sea(nq)) {
			continue;
		}
		edge = max(edge, lum(nq) - l);
	}
	vec3 c = q;
	if (edge > outline_threshold) {
		c = quantize(q * outline_strength);
	}
	COLOR = vec4(grade(c, UV), 1.0);
	}
}
