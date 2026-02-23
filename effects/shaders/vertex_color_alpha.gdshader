shader_type spatial;

render_mode unshaded, cull_disabled, blend_mix;

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
