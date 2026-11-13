shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;
// Eaux peu profondes autour d'une île : aplats turquoise clair puis moyen, et une frange d'écume qui avance et recule
// avec la houle. Posé à plat au-dessus de la mer ; au-delà de la dernière bande le fragment est écarté.
// COLOR.r = distance signée au bord de la terre, codée (d + 12) / 24.

uniform vec3 foam = vec3(0.93, 0.96, 0.94);
uniform vec3 shore = vec3(0.58, 0.83, 0.80);
uniform vec3 mid = vec3(0.24, 0.57, 0.62);
uniform float seed = 0.0;

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

vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	op = VERTEX;
}

void fragment() {
	float s = -(COLOR.r * 24.0 - 12.0);   // distance en mer, positive (codée de -12 à +12 m dans la couleur)
	vec2 p = op.xz;
	float n = vn(p * 0.45 + seed) * 1.6 + vn(p * 1.1 - seed) * 0.5;
	float swell = sin(TIME * 0.8 + n * 3.0) * 0.35;
	float d = s + (n - 1.0) * 0.8;
	vec3 col;
	if (d < 1.55 + swell) {
		col = foam;
	} else if (d < 2.0 + swell * 0.6) {
		col = shore;
		// reflux : une ligne d'écume qui se détache
		if (d < 1.75 + swell) {
			col = foam;
		}
	} else if (d < 4.2 + n * 0.6) {
		col = shore;
		float ripple = sin((p.x + p.y) * 1.3 + TIME * 0.6 + n * 5.0);
		if (ripple > 0.93) {
			col = foam;
		}
		// scintillement du soleil : de petits éclats qui s'allument et s'éteignent
		vec2 gc = floor(p * 2.2);
		if (hash(gc + floor(TIME * 1.5 + hash(gc) * 6.0)) > 0.975 && fract(p.x * 2.2) < 0.5 && fract(p.y * 2.2) < 0.5) {
			col = foam;
		}
	// 13/11 : le bord extérieur n'est plus un arc parfait : de grandes langues d'eau claire, qui respirent lentement
	} else if (d < 4.9 + vn(p * 0.16 + seed * 0.7) * 3.0 + n * 0.5 + sin(TIME * 0.35 + n * 2.0) * 0.25) {
		col = mid;
		float ripple = sin((p.x - p.y) * 1.1 - TIME * 0.5 + n * 6.0);
		if (ripple > 0.96) {
			col = shore;
		}
	} else {
		discard;
	}
	ALBEDO = srgb(col);
}
