shader_type spatial;
// Sols peints du port, en motifs de pixel art calés sur le monde (ils ne glissent pas) :
// kind 0 = pavés, 1 = planches de ponton, 2 = sable, 3 = herbe.
// Éclairé normalement : il reçoit les ombres des maisons, des bateaux et des personnages.

uniform int kind = 0;

varying vec3 op;   // position dans le repère du port (mètres, x est, z sud)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	op = VERTEX;
}

void fragment() {
	vec2 p = op.xz;
	vec3 col;
	if (kind == 0) {
		// pavés : petits, tons proches, joints à peine plus foncés ; quelques pavés plus clairs ou usés
		float row = floor(p.y / 0.32);
		vec2 q = vec2(p.x / 0.38 + hash(vec2(row, 3.0)) * 0.9 + row * 0.5, p.y / 0.32);
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float h = hash(cell);
		col = h < 0.4 ? vec3(0.66, 0.60, 0.52) : (h < 0.85 ? vec3(0.62, 0.56, 0.49) : vec3(0.72, 0.66, 0.57));
		float edge = min(min(f.x, 1.0 - f.x) * 0.38 / 0.32, min(f.y, 1.0 - f.y));
		col = mix(col * 0.82, col, step(0.1, edge));
		// grandes zones usées plus claires (passages) et plus sombres (bords des maisons)
		float wear = sin(p.x * 0.21) * sin(p.y * 0.17 + 1.0);
		col *= mix(0.94, 1.05, step(0.3, wear));
	} else if (kind == 1) {
		// planches posées en travers du ponton, bois de trois tons, jours sombres et clous
		float board = floor(p.y / 0.32);
		float f = fract(p.y / 0.32);
		float h = hash(vec2(board, floor(p.x / 2.2 + hash(vec2(board, 1.0)))));
		col = h < 0.33 ? vec3(0.50, 0.33, 0.19) : (h < 0.66 ? vec3(0.42, 0.27, 0.16) : vec3(0.58, 0.39, 0.22));
		col = mix(vec3(0.16, 0.10, 0.07), col, step(0.12, f) * step(f, 0.94));
		float nail = step(abs(fract(p.x / 2.2 + hash(vec2(board, 1.0))) - 0.04), 0.012) * step(abs(f - 0.5), 0.14);
		col = mix(col, vec3(0.20, 0.18, 0.18), nail);
		float grain = step(0.86, hash(floor(p * vec2(6.0, 18.0))));
		col *= 1.0 - grain * 0.12;
	} else if (kind == 2) {
		// sable clair moucheté
		col = vec3(0.86, 0.74, 0.52);
		float s = hash(floor(p * 9.0));
		col = mix(col, vec3(0.74, 0.62, 0.42), step(0.9, s));
		col = mix(col, vec3(0.94, 0.86, 0.66), step(s, 0.05));
	} else {
		// herbe : touffes plus sombres et brins clairs
		col = vec3(0.30, 0.50, 0.22);
		float s = hash(floor(p * 5.0));
		col = mix(col, vec3(0.20, 0.38, 0.16), step(0.7, s));
		col = mix(col, vec3(0.44, 0.62, 0.28), step(s, 0.08));
	}
	ALBEDO = srgb(col);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
