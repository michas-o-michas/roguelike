shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Cor sólida (fallback quando não há textura)
uniform vec3 base_color : source_color = vec3(0.25, 0.55, 0.25);
// Textura do mesh da grama (usa cor da textura quando definida)
uniform sampler2D albedo_texture : hint_default_white;
uniform vec3 albedo_tint : source_color = vec3(1.0, 1.0, 1.0);

uniform float wind_strength : hint_range(0.0, 0.5) = 0.08;
uniform float wind_speed : hint_range(0.5, 5.0) = 2.0;

void vertex() {
	// Fator de altura: mesh pode ter Y local 0..1 (tufo) ou -1..1; garante vento visível
	float height_factor = clamp(VERTEX.y * 0.5 + 0.5, 0.2, 1.0);
	float t = TIME * wind_speed + VERTEX.x * 1.5 + VERTEX.z * 1.2;
	float sway_x = sin(t) * wind_strength * height_factor;
	float sway_z = cos(t * 0.7) * wind_strength * 0.6 * height_factor;
	VERTEX.x += sway_x;
	VERTEX.z += sway_z;
}

void fragment() {
	// Cor da textura do mesh × tint (tint = cor do material ou tema)
	vec4 tex_color = texture(albedo_texture, UV);
	ALBEDO = tex_color.rgb * albedo_tint;
	ALPHA = 1.0;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
