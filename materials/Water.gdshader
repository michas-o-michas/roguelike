shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

// Plano azul fosco com pouco reflexo. Nada mais — zero tremor.

uniform vec3 albedo : source_color;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
