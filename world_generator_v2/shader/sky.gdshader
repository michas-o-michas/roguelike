shader_type sky;

uniform sampler2D source_panorama : filter_linear, source_color, hint_default_black;

uniform float exposure : hint_range(0, 128) = 1.0;
uniform float sky_energy : hint_range(0, 128) = 1.0;

uniform float speed = 0.002;

void sky() {
	// Converte direção do céu para coordenadas equiretangulares corretas
	vec3 dir = SKY_DIRECTION;

	float u = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
	float v = dir.y * 0.5 + 0.5;

	vec2 uv = vec2(u, v);

	// Movimento horizontal
	uv.x += TIME * speed;

	vec3 panorama = texture(source_panorama, uv).rgb;

	COLOR = panorama * exposure * sky_energy;
}
