shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_back;

uniform vec4 shallow_color : source_color = vec4(0.15, 0.55, 0.8, 0.6);
uniform vec4 deep_color    : source_color = vec4(0.02, 0.25, 0.45, 0.8);

uniform float wave_speed  = 1.0;
uniform float wave_height = 0.08;
uniform float wave_scale  = 2.0;

uniform float fresnel_power = 3.0;

varying float wave;

void vertex() {

    wave = 0.0;

    wave += sin(VERTEX.x * wave_scale + TIME * wave_speed) * 0.6;
    wave += cos(VERTEX.z * wave_scale * 1.2 + TIME * wave_speed * 1.1) * 0.4;

    VERTEX.y += wave * wave_height;
}

void fragment() {

    // Cor varia conforme altura da onda
    vec3 base = mix(deep_color.rgb, shallow_color.rgb, wave * 0.5 + 0.5);

    // Fresnel simples
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);

    ALBEDO = mix(base, vec3(1.0), fresnel * 0.4);

    METALLIC = 0.2;
    ROUGHNESS = 0.05;

    ALPHA = 0.7 + fresnel * 0.3;
}
