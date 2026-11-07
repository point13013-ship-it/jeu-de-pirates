shader_type canvas_item;
// Fond du menu : une mer sombre en dégradé, avec des rides lentes, en paliers de couleur (aspect pixel art).

uniform vec3 top_color : source_color = vec3(0.08, 0.26, 0.36);
uniform vec3 bottom_color : source_color = vec3(0.02, 0.07, 0.13);

void fragment() {
	vec2 uv = UV;
	vec3 c = mix(top_color, bottom_color, pow(uv.y, 0.8));
	float t = TIME * 0.12;
	float warp = sin(uv.x * 14.0 + t * 5.0 + sin(uv.y * 8.0 + t * 3.0) * 2.0);
	float ripples = smoothstep(0.90, 1.0, sin(uv.y * 70.0 + warp * 0.9 + t * 2.0));
	c += ripples * 0.10 * vec3(0.45, 0.85, 0.95) * (1.0 - uv.y * 0.6);
	COLOR = vec4(floor(c * 28.0) / 28.0, 1.0);
}
