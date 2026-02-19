shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_disabled;

// Aparência (folhas com transparência)
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : hint_default_white;

// Vento
uniform float wind_strength : hint_range(0.0, 0.3) = 0.06;
uniform float wind_speed : hint_range(0.5, 4.0) = 1.5;
uniform float wind_height_scale : hint_range(0.1, 2.0) = 0.4;

void vertex() {
	float height_factor = clamp(VERTEX.y * wind_height_scale + 0.2, 0.0, 1.0);
	float t = TIME * wind_speed + VERTEX.x * 0.7 + VERTEX.z * 0.5;
	float sway_x = sin(t) * wind_strength * height_factor;
	float sway_z = cos(t * 0.8) * wind_strength * 0.7 * height_factor;
	VERTEX.x += sway_x;
	VERTEX.z += sway_z;
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	ALBEDO = tex_color.rgb * albedo_color.rgb;
	ALPHA = tex_color.a * albedo_color.a;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
