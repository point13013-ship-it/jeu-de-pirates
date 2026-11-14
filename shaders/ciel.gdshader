shader_type sky;
// Ciel en pixel art pour la vue à horizon : des bandes de couleur plates (pas de dégradé lisse), qui partent EXACTEMENT de la couleur
// de la brume à l'horizon (la mer lointaine s'y fond sans couture) vers le zénith ; des nuages plats à deux tons, qui dérivent.
// Couleurs, couverture et heure sont pilotés par SkyCycle (src/sea/sky_cycle.gd).

uniform vec3 horizon : source_color = vec3(0.70, 0.77, 0.82);
uniform vec3 zenith : source_color = vec3(0.36, 0.60, 0.84);
uniform vec3 cloud_lit : source_color = vec3(0.96, 0.97, 0.98);
uniform vec3 cloud_shade : source_color = vec3(0.78, 0.84, 0.90);
uniform float cover = 0.4;     // 0 : peu de nuages ; 1 : couvert
uniform float drift = 0.0;     // dérive des nuages
uniform float flash = 0.0;     // éclair

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	float h = clamp(EYEDIR.y, 0.0, 1.0);
	float band = floor(pow(h, 0.55) * 9.0) / 9.0;
	vec3 col = mix(horizon, zenith, band);
	if (EYEDIR.y > 0.0) {
		vec2 p = EYEDIR.xz / (EYEDIR.y + 0.08) * 0.55 + vec2(drift, 0.0);
		float n = vnoise(p * 2.2) * 0.65 + vnoise(p * 4.6 + 7.0) * 0.35;
		float th = 0.68 - cover * 0.22;
		float c = step(th, n);
		float c2 = step(th + 0.07, n);
		vec3 cc = mix(cloud_shade, cloud_lit, c2);
		col = mix(col, cc, c * smoothstep(0.0, 0.05, EYEDIR.y));
	}
	COLOR = col * (1.0 + flash * 1.5);
}
