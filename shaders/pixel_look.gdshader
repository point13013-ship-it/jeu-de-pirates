shader_type canvas_item;
// Filtre « pixel art » appliqué à l'image 3D basse résolution :
// chaque pixel est ramené à la palette fixe (port + tons de la mer), puis un contour sombre d'un
// pixel est tracé au bord des objets. Pas de contour entre deux tons de mer : sinon chaque vaguelette
// serait cernée de noir.
#include "res://shaders/palette.gdshaderinc"

uniform float outline_threshold = 0.22;
uniform float outline_strength = 0.30;
uniform bool use_palette = true;   // faux : couleurs brutes (diagnostic, mesure des tons)

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 quantize(vec3 c) {
	if (!use_palette) {
		return c;
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
	COLOR = vec4(c, 1.0);
}
