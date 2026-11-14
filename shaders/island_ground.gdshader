shader_type spatial;
// Sol des îles, peint en pixel art : herbe en grandes taches de quatre tons, touffes, fleurs, sentiers de terre,
// sable ondulé avec coquillages, sable mouillé, falaises de roche stratifiée. Tout est calé sur l'île (rien ne glisse)
// et en aplats nets, sans tramage (le tramage vibre quand l'image défile).
// Couleur de sommet : r = herbe (0 sable, 1 herbe), g = sable mouillé, b = sentier, a = roche (falaise).
// Éclairé normalement : il reçoit les ombres des palmiers, des ennemis et des personnages.

// (13/11 : palette v1, design/bible-v2.md : végétation #2D6444, #5A9440, #A3C650)
uniform vec3 grass_dark = vec3(0.176, 0.392, 0.267);
uniform vec3 grass_base = vec3(0.290, 0.520, 0.240);
uniform vec3 grass_light = vec3(0.353, 0.580, 0.251);
uniform vec3 grass_high = vec3(0.560, 0.700, 0.300);
uniform vec3 flower_a = vec3(0.98, 0.82, 0.33);
uniform vec3 flower_b = vec3(0.84, 0.33, 0.36);
uniform float flowers = 1.0;
// 13/11 (îles à relief) : hauteur du plus haut sommet de l'île (0 : île plate). L'herbe s'éclaircit et jaunit par paliers
// avec l'altitude, et les hauts sont plus secs : on lit le relief d'en haut.
uniform float relief_top = 0.0;

varying vec3 op;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// (13/11 : chaque octave est tournée : le bruit n'est plus aligné sur une grille, les taches d'herbe ne sont plus carrées)
float fbm(vec2 p) {
	vec2 p2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.1 + 7.3;
	vec2 p3 = mat2(vec2(0.28, 0.96), vec2(-0.96, 0.28)) * p * 4.3 + 1.7;
	return vn(p) * 0.55 + vn(p2) * 0.30 + vn(p3) * 0.15;
}

vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	op = VERTEX;
}

vec3 grass(vec2 p, float detail) {
	// (13/11 : le dessin des taches est déformé par un second bruit : des contours souples au lieu de pavés)
	vec2 warp = vec2(vn(p * 0.21 + 3.1), vn(p * 0.21 + 9.7)) - 0.5;
	float n = fbm(p * 0.32 + warp * 1.6);
	vec3 col = grass_base;
	if (n < 0.34) {
		col = grass_dark;
	} else if (n > 0.72) {
		col = grass_high;
	} else if (n > 0.58) {
		col = grass_light;
	}
	// petites taches claires et sombres, par pavés de 0,22 m (environ 5 pixels)
	vec2 cell = floor(p * 6.0);
	vec2 f = fract(p * 6.0);
	float h = hash(cell);
	vec2 s = floor(f * 6.0);
	// touffe : trois brins, un pixel de large
	bool blade = (s.x == 2.0 && s.y >= 1.0 && s.y <= 3.0) || (s.x == 1.0 && s.y == 3.0) || (s.x == 3.0 && s.y == 2.0);
	if (detail > 0.5 && h > 0.80 && blade) {
		col = h > 0.93 ? grass_high : grass_dark;
	}
	// fleurs : rares, groupées par grandes zones
	vec2 fc = floor(p * 3.6);
	vec2 ff = floor(fract(p * 3.6) * 10.0);
	float fh = hash(fc + 31.0);
	float zone = vn(p * 0.2 + 11.0);
	if (detail > 0.5 && zone > 0.62 && fh > 1.0 - 0.09 * flowers && ff.x >= 4.0 && ff.x <= 5.0 && ff.y >= 4.0 && ff.y <= 5.0) {
		col = fh > 1.0 - 0.04 * flowers ? flower_b : flower_a;
		if (ff.x == 4.0 && ff.y == 4.0) {
			col = vec3(0.98, 0.95, 0.88);
		}
	}
	return col;
}

vec3 sand(vec2 p, float detail) {
	vec3 col = vec3(0.86, 0.74, 0.52);
	// longues ondulations de sable : bandes claires et foncées qui serpentent
	float w = p.y * 0.55 + sin(p.x * 0.3) * 0.8 + vn(p * 0.3) * 2.2;
	float band = fract(w);
	if (band < 0.07) {
		col = vec3(0.74, 0.62, 0.42);
	} else if (band > 0.9) {
		col = vec3(0.94, 0.86, 0.66);
	}
	float s = hash(floor(p * 12.0));
	col = mix(col, vec3(0.74, 0.62, 0.42), step(0.93, s) * detail);
	col = mix(col, vec3(0.94, 0.86, 0.66), step(s, 0.04) * detail);
	// coquillages et petits cailloux
	vec2 cell = floor(p * 2.25);
	vec2 f = floor(fract(p * 2.25) * 16.0);
	float h = hash(cell + 5.0);
	if (detail > 0.5 && h > 0.93 && f.x >= 7.0 && f.x <= 8.0 && f.y >= 7.0 && f.y <= 8.0) {
		col = h > 0.97 ? vec3(0.84, 0.33, 0.36) : vec3(0.93, 0.95, 0.9);
	}
	return col;
}

vec3 rock(vec3 o) {
	// strates horizontales (vues de côté) mêlées à des fissures verticales
	float layer = floor(o.y * 5.5 + vn(o.xz * 0.6) * 1.2);
	float h = hash(vec2(layer, 3.0));
	vec3 col = h < 0.34 ? vec3(0.52, 0.49, 0.50) : (h < 0.7 ? vec3(0.41, 0.38, 0.42) : vec3(0.60, 0.56, 0.52));
	float crack = step(0.9, hash(vec2(floor((o.x + o.z) * 5.0), layer)));
	col *= 1.0 - 0.28 * crack;
	return col;
}

void fragment() {
	vec2 p = op.xz;
	// vue 4 (perspective) : les détails d'un pixel (brins, fleurs, cailloux, coquillages) tombent sous le pixel et crépitent : ils disparaissent.
	// 1 en orthographique (rien ne change), 0 en perspective.
	float detail = PROJECTION_MATRIX[3][3];
	float grass_amt = COLOR.r;
	float wet = COLOR.g;
	float path = COLOR.b;
	float cliff = COLOR.a;
	vec3 col;
	if (cliff > 0.5) {
		col = rock(op);
	} else if (grass_amt > 0.5) {
		col = grass(p, detail);
		if (relief_top > 0.5) {
			float alt = clamp(op.y / relief_top, 0.0, 1.0);
			float band = floor(alt * 5.0 + vn(p * 0.35) * 0.6) / 5.0;
			col = mix(col * vec3(0.90, 0.95, 0.92), col * vec3(1.16, 1.12, 0.86) + vec3(0.03, 0.03, 0.0), band);
			if (band > 0.75 && vn(p * 0.9) > 0.55) {
				col = mix(col, vec3(0.63, 0.60, 0.47), 0.75);   // l'herbe rase et les cailloux des hauts
			}
		}
		// sentier : terre nue, bord rongé par de petites touffes
		float edge = path + (vn(p * 3.0) - 0.5) * 0.5;
		if (edge > 0.55) {
			col = vec3(0.74, 0.62, 0.42);
			float pebble = hash(floor(p * 10.5));
			col = mix(col, vec3(0.62, 0.52, 0.36), step(0.9, pebble) * detail);
			col = mix(col, vec3(0.86, 0.74, 0.52), step(pebble, 0.05) * detail);
		}
	} else {
		col = sand(p, detail);
		float edge = path + (vn(p * 3.0) - 0.5) * 0.4;
		if (edge > 0.7) {
			col = mix(col, vec3(0.74, 0.62, 0.42), 1.0);
		}
		if (wet > 0.5) {
			col = vec3(0.62, 0.52, 0.36);
			if (detail > 0.5 && hash(floor(p * 9.0)) > 0.9) {
				col = vec3(0.74, 0.62, 0.42);
			}
		}
	}
	// ombres de nuages : grandes plaques fraîches qui dérivent lentement sur l'île, en aplats nets (deux tons)
	if (cliff <= 0.5) {
		float cl = fbm(p * 0.045 + vec2(TIME * 0.28, TIME * 0.11));
		if (cl > 0.60) {
			col *= vec3(0.76, 0.81, 0.94);
		} else if (cl > 0.54) {
			col *= vec3(0.88, 0.91, 0.97);
		}
	}
	ALBEDO = srgb(col);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
