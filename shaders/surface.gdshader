shader_type spatial;
// Matières peintes de la ville, en motifs de pixel art calés sur le port (coordonnées du port) :
// kind 0 = enduit (taches, briques à nu, salissures au pied), 1 = tuiles en rangées, 2 = planches,
// 3 = pierre de taille. `base` est la couleur du matériau d'origine (Blender).

uniform int kind = 0;
uniform vec3 base : source_color = vec3(0.8, 0.7, 0.5);
uniform float shop = 0.0;   // kind 5 : 1 = vitrine de boutique (étagères), 0 = fenêtre de maison (rideaux)
uniform float emit = 0.0;   // kind 4 : couleur unie, éventuellement lumineuse (vitrines, lanternes)

varying vec3 op;
varying vec3 on;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	op = VERTEX;
	on = NORMAL;
}

// coordonnées 2D sur la face : murs vus de face (x, hauteur), murs de côté (z, hauteur), sols (x, z)
vec2 face_uv() {
	vec3 a = abs(on);
	if (a.y > 0.7) {
		return op.xz;
	}
	return a.z >= a.x ? vec2(op.x, op.y) : vec2(op.z, op.y);
}

void fragment() {
	vec2 p = face_uv();
	vec3 c = base;
	if (kind == 0) {
		// enduit : grandes taches douces en deux tons, briques à nu par endroits, pied du mur sali
		float n = noise(p * 0.9) * 0.6 + noise(p * 2.7) * 0.4;
		c *= mix(0.9, 1.08, step(0.5, n));
		vec2 b = vec2(p.x / 0.5 + floor(p.y / 0.22) * 0.5, p.y / 0.22);
		vec2 bf = fract(b);
		float patch = step(0.78, noise(p * 0.45 + 13.0));
		vec3 brick = vec3(0.55, 0.25, 0.16) * mix(0.85, 1.1, hash(floor(b)));
		brick = mix(brick * 0.55, brick, step(0.1, bf.y) * step(0.06, bf.x));
		c = mix(c, brick, patch);
		c *= mix(0.72, 1.0, smoothstep(0.0, 0.9, op.y));
	} else if (kind == 1) {
		// tuiles : rangées qui montent avec la pente, tuiles décalées d'un rang à l'autre, joint sombre
		float row = floor(op.y / 0.26);
		float f = fract(op.y / 0.26);
		float tx = op.x / 0.34 + row * 0.5;
		float t = fract(tx);
		float h = hash(vec2(floor(tx), row));
		c *= h < 0.3 ? 0.86 : (h < 0.8 ? 1.0 : 1.14);
		float rounded = 1.0 - 0.35 * pow(abs(t - 0.5) * 2.0, 2.0);
		c *= mix(0.8, 1.0, rounded);
		c = mix(c * 0.5, c, step(0.16, f));
	} else if (kind == 2) {
		// planches : lames de 22 cm, jours sombres, veinage
		float lane = floor(p.x / 0.22);
		float f = fract(p.x / 0.22);
		c *= mix(0.86, 1.1, hash(vec2(lane, 2.0)));
		c = mix(c * 0.45, c, step(0.1, f));
		c *= 1.0 - 0.1 * step(0.8, hash(floor(vec2(p.x * 12.0, p.y * 3.0))));
	} else if (kind == 3) {
		// pierre de taille : blocs de 60 x 30 cm décalés, joints clairs, blocs plus ou moins usés
		vec2 b = vec2(p.x / 0.6 + floor(p.y / 0.3) * 0.5, p.y / 0.3);
		vec2 bf = fract(b);
		c *= mix(0.84, 1.12, hash(floor(b)));
		c = mix(c * 1.25, c, step(0.07, bf.y) * step(0.04, bf.x));
	} else if (kind == 5) {
		// 13/11 (2.2) : une vitre derrière laquelle on devine un intérieur. Rien n'est transparent (la caméra regarde d'en haut :
		// on ne verrait rien) : l'intérieur est PEINT dans le verre. Fond de lumière chaude (`base`), plus sombre vers le haut ;
		// `shop` = 1 : des étagères et leurs marchandises (bouteilles, pots, paquets) ; sinon une maison : rideaux sur les bords.
		// Parfois une silhouette. `emit` : 0 éteint (verre sombre, formes à peine visibles) … 1 pleine lumière.
		vec3 dark = vec3(0.16, 0.10, 0.12);
		vec3 glass_off = vec3(0.14, 0.17, 0.26);
		float storey = mod(p.y, 3.0);
		c = base * mix(1.0, 0.72, smoothstep(0.6, 2.6, storey));
		float ink = 0.0;
		if (shop > 0.5) {
			float shelf_y = mod(p.y, 0.5);
			ink = max(ink, step(shelf_y, 0.05));
			float cell = floor(p.x / 0.2);
			float row = floor(p.y / 0.5);
			float h = hash(vec2(cell, row));
			float fx = fract(p.x / 0.2);
			float tall = 0.10 + 0.26 * h;
			float wide = mix(0.22, 0.42, hash(vec2(row, cell)));
			float body = step(abs(fx - 0.5), wide) * step(0.05, shelf_y) * step(shelf_y, 0.05 + tall);
			float neck = step(abs(fx - 0.5), 0.09) * step(shelf_y, 0.05 + tall + 0.08) * step(0.05 + tall, shelf_y) * step(0.5, h);
			float item = max(body, neck) * step(0.22, h);
			vec3 tint = mix(dark, vec3(0.45, 0.20, 0.16) + 0.25 * vec3(hash(vec2(cell, 3.0)), hash(vec2(cell, 5.0)), hash(vec2(cell, 7.0))), 0.55);
			c = mix(c, tint, item * 0.85);
		} else {
			float edge = abs(fract(p.x / 1.1) - 0.5);
			float fold = 0.5 + 0.5 * sin(p.x * 38.0);
			c = mix(c, base * 0.55 + vec3(0.10, 0.03, 0.02), smoothstep(0.30, 0.42, edge) * (0.55 + 0.25 * fold));
		}
		float who = floor(p.x / 2.3);
		if (hash(vec2(who, 11.0)) > 0.62) {
			vec2 q = vec2(p.x - (who + 0.5) * 2.3 + sin(TIME * 0.3 + who) * 0.25, storey);
			float head = step(length((q - vec2(0.0, 1.62)) * vec2(1.0, 0.9)), 0.15);
			float torso = step(abs(q.x), 0.26 - 0.10 * smoothstep(1.1, 1.45, q.y)) * step(q.y, 1.45) * step(0.5, q.y);
			ink = max(ink, max(head, torso) * 0.8);
		}
		c = mix(c, dark, ink);
		c = mix(glass_off + c * 0.12, c, emit);
	} else {
		c = base;
	}
	ALBEDO = c;
	EMISSION = (kind == 5 ? c * 0.9 : base) * emit;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
