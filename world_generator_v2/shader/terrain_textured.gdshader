shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// ========================================
// Terreno com texturas e transições suaves por altura
// ========================================
// - Smootherstep (quintic) para transições mais suaves que smoothstep
// - Zona de transição mais larga e ruído espacial para bordas orgânicas
// ========================================

group_uniforms Texturas;
uniform sampler2D texture_sand : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_snow : source_color, filter_linear_mipmap, repeat_enable;

group_uniforms Alturas_e_Transicoes;
uniform float water_level = -8.0;
uniform float beach_level = -4.0;
uniform float grass_level = 2.0;
uniform float rock_start = 18.0;
uniform float rock_end = 30.0;
uniform float snow_start = 30.0;
uniform float transition_width = 4.0;
uniform float transition_softness : hint_range(0.5, 3.0) = 2.0; // 1=smoothstep, 2=mais suave, 3=zona bem larga
uniform float transition_noise : hint_range(0.0, 5.0) = 2.0; // ruído espacial (0=linha reta, 2=natural)
uniform float texture_scale_uv = 0.05;

group_uniforms Tint;
uniform bool use_vertex_color_tint = true;

varying vec3 world_pos_terrain;

void vertex() {
	world_pos_terrain = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Ruído 2D simples para variar a transição no espaço (bordas orgânicas)
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Smootherstep quintic: derivada zero nas bordas = transição mais suave que smoothstep
float smootherstep(float edge0, float edge1, float x) {
	float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Peso da camada com curva suave e zona mais larga
float layer_weight(float height, float center, float half_width) {
	float h0 = center - half_width;
	float h1 = center + half_width;
	return smootherstep(h0, h1, height);
}

void fragment() {
	vec2 uv = world_pos_terrain.xz * texture_scale_uv;
	// Ruído espacial: a "altitude" usada no blend varia em XZ → bordas orgânicas, não uma linha reta
	float n = noise2d(world_pos_terrain.xz * 0.02) - 0.5;
	float h = world_pos_terrain.y + n * transition_noise;

	// Zona de transição mais larga (transition_softness > 1 alarga a faixa de blend)
	float tw = transition_width * 0.5 * transition_softness;

	// Pesos por camada com smootherstep e zona ampla
	float w_sand = 1.0 - layer_weight(h, beach_level + 2.0, tw);
	float w_grass = layer_weight(h, grass_level, tw) * (1.0 - layer_weight(h, rock_start - 1.0, tw));
	float w_rock = layer_weight(h, rock_start, tw) * (1.0 - layer_weight(h, snow_start - 1.0, tw));
	float w_snow = layer_weight(h, snow_start, tw);

	// Normalizar para soma = 1 (evita escurecer onde há sobreposição)
	float total = w_sand + w_grass + w_rock + w_snow;
	if (total > 0.001) {
		w_sand /= total;
		w_grass /= total;
		w_rock /= total;
		w_snow /= total;
	} else {
		w_grass = 1.0; // fallback
	}

	vec4 tex_sand = texture(texture_sand, uv);
	vec4 tex_grass = texture(texture_grass, uv);
	vec4 tex_rock = texture(texture_rock, uv);
	vec4 tex_snow = texture(texture_snow, uv);

	vec3 albedo = w_sand * tex_sand.rgb + w_grass * tex_grass.rgb + w_rock * tex_rock.rgb + w_snow * tex_snow.rgb;

	if (use_vertex_color_tint && COLOR.a > 0.01) {
		albedo *= COLOR.rgb;
	}

	ALBEDO = albedo;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
