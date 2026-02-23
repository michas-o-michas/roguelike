shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Cor do mesh — mantida do material original
uniform vec4 albedo_color : source_color = vec4(0.5, 0.45, 0.4, 1.0);
uniform sampler2D albedo_texture : hint_default_white;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
// Pedaços grandes: 0.08–0.12 = bom para personagens
uniform float fragment_scale : hint_range(0.04, 0.5) = 0.11;
uniform float edge_width : hint_range(0.02, 0.2) = 0.09;
uniform vec4 edge_color : source_color = vec4(0.5, 0.82, 1.0, 1.0);
// Brilho sutil na borda (opcional)
uniform float edge_emissive : hint_range(0.0, 0.6) = 0.25;

varying vec3 world_pos;

// Hash com boa distribuição para os pedaços sumirem aos poucos (evita metade sumir de uma vez)
float hash(vec3 p) {
	vec3 q = fract(p * vec3(0.3183099, 0.3183099, 0.3183099) + vec3(0.1, 0.1, 0.1));
	return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cell = floor(world_pos * fragment_scale) / fragment_scale;
	float n = hash(cell);
	// Pequena ordem por altura: dissolve tende a ir de baixo pra cima, sempre aos poucos
	float order = (world_pos.y * 0.12 + 0.5);
	n = fract(n * 0.85 + order * 0.15);
	if (n < dissolve) {
		discard;
	}
	vec3 albedo = texture(albedo_texture, UV).rgb * albedo_color.rgb;
	float edge = smoothstep(dissolve, dissolve + edge_width, n);
	albedo = mix(edge_color.rgb, albedo, edge);
	float emissive_strength = (1.0 - edge) * edge_emissive;
	ALBEDO = albedo;
	EMISSION = edge_color.rgb * emissive_strength;
	ROUGHNESS = 0.65;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
