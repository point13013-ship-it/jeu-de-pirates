shader_type spatial;
render_mode specular_disabled;
// Palmiers dans le vent : couleur de sommet comme la matière commune de MeshKit, mais le haut du tronc ploie
// doucement et les palmes frémissent. Mouvement continu (pas de paliers) ; la phase est propre à chaque arbre.

uniform float wind = 1.0;
uniform float tall = 4.5;   // hauteur (m) à partir de laquelle le mouvement est au maximum : 4,5 palmier, ~1 buisson
instance uniform float phase = 0.0;

void vertex() {
	float h = clamp(VERTEX.y / tall, 0.0, 1.2);
	float h2 = h * h;
	float t = TIME + phase;
	// ploiement lent de tout l'arbre, plus fort vers la cime
	VERTEX.x += (sin(t * 1.1) * 0.11 + sin(t * 0.43 + 1.7) * 0.07) * h2 * wind;
	VERTEX.z += sin(t * 0.9 + 2.1) * 0.06 * h2 * wind;
	// frémissement des palmes : plus on s'éloigne de la cime, plus la pointe bat
	float flutter = sin(t * 2.7 + VERTEX.x * 3.1 + VERTEX.z * 2.3);
	VERTEX.y += flutter * 0.06 * h2 * wind;
	VERTEX.x += sin(t * 2.1 + VERTEX.z * 2.7) * 0.05 * h2 * wind;
}

vec3 srgb_to_lin(vec3 c) {
	return pow(c, vec3(2.2));
}

void fragment() {
	// la couleur de sommet de Godot est déjà en linéaire quand la matière la lit en albedo ; on fait de même
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
