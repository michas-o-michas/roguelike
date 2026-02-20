shader_type spatial;
// Sem blend_mix e sem escrever ALPHA = material opaco (não entra no pipeline de transparência)
render_mode depth_draw_opaque, cull_back;

// Aparência (sempre opaco)
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : hint_default_white;

// Vento: raiz parada; quanto mais alto, mais balanço
uniform float wind_strength : hint_range(0.0, 0.4) = 0.12;
uniform float wind_speed : hint_range(0.5, 4.0) = 1.5;
// Base (Y): abaixo disso quase não balança. 0 = pé em Y=0; -0.5 = mais margem para o vento aparecer.
uniform float wind_base_height : hint_range(-5.0, 5.0) = -0.5;
// Escala: a partir de que altura o vento sobe (acima da base).
uniform float wind_height_scale : hint_range(0.05, 2.0) = 0.4;
// Quanto maior, mais vento só no topo (base quase parada).
uniform float wind_height_power : hint_range(1.0, 6.0) = 3.5;

void vertex() {
	float raw = (VERTEX.y - wind_base_height) * wind_height_scale;
	// +0.02: mínimo para o topo sempre ter vento; base continua com factor bem baixo
	float normalized_height = clamp(raw + 0.02, 0.0, 1.0);
	float height_factor = pow(normalized_height, wind_height_power);
	float t = TIME * wind_speed + VERTEX.x * 0.7 + VERTEX.z * 0.5;
	float sway_x = sin(t) * wind_strength * height_factor;
	float sway_z = cos(t * 0.8) * wind_strength * 0.7 * height_factor;
	VERTEX.x += sway_x;
	VERTEX.z += sway_z;
}

void fragment() {
	vec3 albedo = texture(albedo_texture, UV).rgb * albedo_color.rgb;
	ALBEDO = albedo;
	// Não escrever em ALPHA: no Godot, escrever em ALPHA coloca o material no pipeline TRANSPARENTE.
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
