shader_type spatial;
// Le sol de la ville v3 : un seul sol, peint d'après la carte de TownGround (rouge = pavé, vert = grande rue, bleu = sable).
// Pavés en rangées décalées, de trois tons, joints sombres ; herbe qui pousse dans les joints près du bord ; bande de terre
// battue entre la rue et l'herbe ; herbe en taches de trois verts ; sable. Les limites sont déformées par un bruit : aucun bord
// droit. Couleurs de la palette v1 (design/bible-v2.md). Pas de rendu particulier ici : ToonLook lui donne la lumière à paliers.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec2 origin = vec2(0.0);
uniform vec2 extent = vec2(100.0);

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
	vec2 p = vec2(op.x, -op.z);
	vec3 m = texture(mask, (p - origin) / extent).rgb;
	// le bord de tout ce qui est tracé ondule : un grand mouvement et un petit
	float wob = (vn(p * 0.9) - 0.5) * 0.30 + (vn(p * 2.9 + 4.0) - 0.5) * 0.14;
	float road = m.r + wob;
	float paved = step(0.5, road);
	float worn = step(0.30, road) - paved;

	// herbe : taches aux contours souples, trois verts ; quelques brins clairs
	vec2 warp = vec2(vn(p * 0.21 + 3.1), vn(p * 0.21 + 9.7)) - 0.5;
	float g = vn(p * 0.32 + warp * 1.6) * 0.62 + vn(p * 0.95 + 2.0) * 0.38;
	vec3 grass = vec3(0.290, 0.520, 0.240);
	grass = mix(grass, vec3(0.353, 0.580, 0.251), step(0.56, g));
	grass = mix(grass, vec3(0.176, 0.392, 0.267), step(g, 0.36));
	float blade = step(0.965, hash(floor(p * 5.0))) * step(0.42, g);
	grass = mix(grass, vec3(0.640, 0.776, 0.314), blade);
	vec3 col = grass;

	// sable
	vec3 sand = mix(vec3(0.851, 0.690, 0.467), vec3(0.957, 0.882, 0.678), step(0.48, vn(p * 0.8 + 11.0)));
	sand = mix(sand, vec3(0.659, 0.478, 0.322), step(0.985, hash(floor(p * 4.0))));   // quelques cailloux
	col = mix(col, sand, step(0.5, m.b + wob));

	// terre battue : la bande où l'herbe ne pousse plus, au bord des rues
	vec3 dirt = mix(vec3(0.612, 0.455, 0.310), vec3(0.706, 0.545, 0.380), step(0.5, vn(p * 1.3 + 5.0)));
	col = mix(col, dirt, worn * (1.0 - step(0.5, m.b)));

	// pavés : rangées décalées ; les grandes rues et les places ont des dalles plus larges et plus claires
	float big = step(0.5, m.g);
	vec2 sz = mix(vec2(0.44, 0.31), vec2(0.66, 0.46), big);
	float row = floor(p.y / sz.y);
	vec2 q = vec2(p.x / sz.x + mod(row, 2.0) * 0.5 + hash(vec2(row, 3.0)) * 0.22, p.y / sz.y);
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float h = hash(cell);
	vec3 stone = mix(vec3(0.725, 0.678, 0.612), vec3(0.812, 0.765, 0.682), big);
	stone *= h < 0.26 ? 0.87 : (h < 0.82 ? 1.0 : 1.09);
	stone = mix(stone, vec3(0.490, 0.455, 0.533), step(0.94, h) * 0.55);          // de temps en temps, une pierre grise
	float joint = clamp(step(f.x, 0.085) + step(f.y, 0.11), 0.0, 1.0);
	stone = mix(stone, vec3(0.400, 0.350, 0.380), joint * 0.8);
	// près du bord, l'herbe gagne les joints et quelques pavés manquent
	float rim = 1.0 - smoothstep(0.55, 0.85, road);
	stone = mix(stone, grass * 0.92, joint * rim * step(0.35, hash(cell + 7.0)));
	stone = mix(stone, dirt, rim * step(0.86, hash(cell + 13.0)));
	col = mix(col, stone, paved);

	ALBEDO = srgb(col);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
