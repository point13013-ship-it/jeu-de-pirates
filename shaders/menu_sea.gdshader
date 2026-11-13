shader_type canvas_item;
// Fond du menu (13/11, refonte graphique) : un coucher de soleil sur la mer, peint en aplats de la palette v1
// (design/bible-v2.md) et dessiné sur une grille de gros pixels. Ciel en bandes, soleil rayé qui touche l'horizon, nuages
// allongés, îles en ombre chinoise, reflet du soleil en tirets qui dansent.

uniform vec2 grid = vec2(480.0, 270.0);   // la grille de « pixels » du tableau
uniform float horizon = 0.58;             // hauteur de l'horizon (0 = haut de l'écran)
uniform vec2 sun_at = vec2(0.69, 0.535);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 hex(float r, float g, float b) {
	return vec3(r, g, b) / 255.0;
}

// hauteur des îles au-dessus de l'horizon, en part de la hauteur d'écran
float isles(float x) {
	float a = 0.050 * smoothstep(0.14, 0.0, abs(x - 0.20)) + 0.022 * smoothstep(0.10, 0.0, abs(x - 0.31));
	float b = 0.034 * smoothstep(0.09, 0.0, abs(x - 0.93)) + 0.018 * smoothstep(0.05, 0.0, abs(x - 0.84));
	return (a + b) * (0.75 + 0.5 * vn(vec2(x * 46.0, 3.0)));
}

void fragment() {
	vec2 uv = (floor(UV * grid) + 0.5) / grid;
	float aspect = grid.x / grid.y;
	float t = TIME;
	vec3 c;
	vec2 ds = vec2((uv.x - sun_at.x) * aspect, uv.y - sun_at.y);
	float sun_d = length(ds);
	if (uv.y < horizon) {
		// ciel : sept bandes, de la nuit violette au feu de l'horizon ; les limites ondulent un peu
		float k = uv.y / horizon + (vn(vec2(uv.x * 5.0, uv.y * 9.0)) - 0.5) * 0.07;
		c = hex(28.0, 23.0, 38.0);
		c = mix(c, hex(46.0, 42.0, 68.0), step(0.16, k));
		c = mix(c, hex(74.0, 66.0, 88.0), step(0.36, k));
		c = mix(c, hex(125.0, 86.0, 110.0), step(0.54, k));
		c = mix(c, hex(190.0, 104.0, 96.0), step(0.70, k));
		c = mix(c, hex(232.0, 140.0, 88.0), step(0.83, k));
		c = mix(c, hex(255.0, 179.0, 92.0), step(0.93, k));
		// étoiles, tout en haut : quelques pixels qui clignotent
		vec2 cell = floor(uv * grid);
		float star = step(0.9965, hash(cell)) * step(k, 0.33);
		c = mix(c, hex(255.0, 226.0, 160.0), star * step(0.35, fract(hash(cell + 7.0) * 9.0 + t * 0.25)));
		// halo puis disque du soleil, rayé vers le bas
		c = mix(c, hex(255.0, 196.0, 110.0), step(sun_d, 0.150) * step(0.70, k));
		float stripes = step(0.012, ds.y) * step(0.5, fract(ds.y * grid.y / 5.0 + 0.1));
		c = mix(c, hex(255.0, 226.0, 160.0), step(sun_d, 0.092) * (1.0 - stripes));
		// nuages : longues bandes, ventre éclairé par le soleil
		float cl = vn(vec2(uv.x * 3.2 + t * 0.012, uv.y * 30.0)) * 0.7 + vn(vec2(uv.x * 9.0 - t * 0.02, uv.y * 62.0)) * 0.3;
		float band = smoothstep(0.10, 0.30, k) * smoothstep(0.86, 0.62, k);
		float body = step(0.66, cl * band + 0.12 * band);
		float belly = step(0.60, cl * band + 0.12 * band) - body;
		c = mix(c, hex(46.0, 42.0, 68.0), body * step(k, 0.5));
		c = mix(c, hex(125.0, 86.0, 110.0), body * step(0.5, k));
		c = mix(c, hex(232.0, 140.0, 88.0), belly * step(0.42, k));
		// îles en ombre chinoise
		c = mix(c, hex(46.0, 42.0, 68.0), step(horizon - uv.y, isles(uv.x)));
	} else {
		// mer : de l'eau dorée sous l'horizon au bleu nuit du premier plan
		float k = (uv.y - horizon) / (1.0 - horizon);
		c = hex(125.0, 86.0, 110.0);
		c = mix(c, hex(74.0, 66.0, 100.0), step(0.035, k));
		c = mix(c, hex(45.0, 74.0, 100.0), step(0.11 + 0.02 * sin(uv.x * 30.0 + t * 0.4), k));
		c = mix(c, hex(32.0, 56.0, 84.0), step(0.30 + 0.03 * sin(uv.x * 17.0 - t * 0.3), k));
		c = mix(c, hex(28.0, 38.0, 64.0), step(0.58 + 0.04 * sin(uv.x * 11.0 + t * 0.25), k));
		c = mix(c, hex(28.0, 23.0, 38.0), step(0.86, k));
		// vaguelettes : des tirets clairs, plus longs et plus espacés vers le premier plan (perspective)
		float rows = pow(k, 0.55) * 34.0;
		float row = floor(rows);
		float len = mix(60.0, 9.0, k);
		float dash = step(0.80, vn(vec2(uv.x * len + row * 17.3 + t * (0.25 + 0.2 * hash(vec2(row, 1.0))), row)));
		float thin = step(fract(rows), 0.34);
		c = mix(c, c + vec3(0.07, 0.10, 0.12), dash * thin);
		// reflet du soleil : une colonne de tirets dorés qui s'élargit et se défait en descendant
		float w = 0.035 + 0.16 * k;
		float inside = step(abs(uv.x - sun_at.x) * aspect, w * (0.55 + 0.9 * vn(vec2(row * 3.7, floor(t * 3.0) * 0.37 + row))));
		float glint = inside * thin * step(k, 0.80) * step(0.25, hash(vec2(row, floor(uv.x * len * 1.5 + t * 1.2))));
		c = mix(c, hex(255.0, 179.0, 92.0), glint);
		c = mix(c, hex(255.0, 226.0, 160.0), glint * step(k, 0.30) * step(abs(uv.x - sun_at.x) * aspect, w * 0.45));
		// reflet sombre des îles
		c = mix(c, hex(46.0, 42.0, 68.0), step(uv.y - horizon, isles(uv.x) * 0.6) * step(0.5, fract(uv.y * grid.y * 0.5)));
	}
	COLOR = vec4(c, 1.0);
}
