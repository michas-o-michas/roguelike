shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// ========================================
// 🌊 SHADER DE ÁGUA ANIMADA PROFISSIONAL
// ========================================
// Autor: Sistema de Geração de Mundo
// Uso: Água com ondas realistas, espuma e reflexões
// ========================================

// ========================================
// PARÂMETROS - AJUSTE NO INSPECTOR!
// ========================================

group_uniforms Ondas;
uniform float wave_speed : hint_range(0.0, 5.0, 0.1) = 1; // ⚡ Velocidade das ondas
uniform float wave_height : hint_range(0.0, 2.0, 0.05) = 2; // 📏 Altura das ondas (0.1-0.3 = realista)
uniform float wave_frequency : hint_range(0.0, 10.0, 0.1) = 6.0; // 🌊 Frequência (quantas ondas)

group_uniforms Cor;
uniform vec4 water_color : source_color = vec4(0.1, 0.4, 0.7, 0.85); // 🔵 Cor da água rasa
uniform vec4 deep_water_color : source_color = vec4(0.05, 0.2, 0.4, 0.9); // 🌊 Cor da água profunda
uniform float color_depth : hint_range(0.0, 10.0, 0.1) = 3.0; // 📊 Profundidade para cor escura

group_uniforms Reflexao;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.3; // ✨ Brilho metálico
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.1; // 🪞 Rugosidade (0.05 = espelho)
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.5; // 💎 Intensidade do brilho

group_uniforms Espuma;
uniform bool enable_foam = true; // 🫧 Ativar espuma nas cristas das ondas
uniform vec4 foam_color : source_color = vec4(0.9, 0.9, 0.95, 1.0); // ⚪ Cor da espuma
uniform float foam_threshold : hint_range(0.0, 1.0, 0.01) = 0.7; // 🎚️ Onde aparece espuma (0.2-0.4)
uniform float foam_intensity : hint_range(0.0, 2.0, 0.1) = .50; // 💪 Intensidade da espuma

// ========================================
// FUNÇÕES DE RUÍDO
// ========================================

// Ruído hash simples
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Ruído interpolado suave
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Hermite interpolation
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM (Fractional Brownian Motion) para ondas naturais
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    
    for(int i = 0; i < 3; i++) {
        value += amplitude * noise(p);
        p = p * 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

// ========================================
// VERTEX SHADER (ONDAS)
// ========================================

void vertex() {
    // Posição no mundo
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec2 uv = world_pos.xz * 0.1 * wave_frequency;
    
    // ONDA 1: Grande e lenta (oceano)
    float wave1 = sin(uv.x + TIME * wave_speed) * 
                  cos(uv.y * 0.5 + TIME * wave_speed * 0.7);
    
    // ONDA 2: Média (vento)
    float wave2 = sin(uv.x * 2.0 - TIME * wave_speed * 1.3) * 
                  cos(uv.y * 1.5 - TIME * wave_speed * 0.9);
    
    // ONDA 3: Pequena e rápida (detalhes)
    float wave3 = fbm(uv * 3.0 + TIME * wave_speed * 0.5) - 0.5;
    
    // Combinar ondas com pesos
    float final_wave = (wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2) * wave_height;
    
    // Aplicar deslocamento vertical
    VERTEX.y += final_wave;
    
    // ========================================
    // RECALCULAR NORMAIS (para iluminação correta)
    // ========================================
    
    // Calcular derivadas para normal
    float dx = 0.1;
    float dz = 0.1;
    
    // Posição X + deslocamento
    vec2 uv_x = (world_pos.xz + vec2(dx, 0.0)) * 0.1 * wave_frequency;
    float wave_x = (sin(uv_x.x + TIME * wave_speed) * 
                    cos(uv_x.y * 0.5 + TIME * wave_speed * 0.7) * 0.5 +
                    sin(uv_x.x * 2.0 - TIME * wave_speed * 1.3) * 
                    cos(uv_x.y * 1.5 - TIME * wave_speed * 0.9) * 0.3) * wave_height;
    
    // Posição Z + deslocamento
    vec2 uv_z = (world_pos.xz + vec2(0.0, dz)) * 0.1 * wave_frequency;
    float wave_z = (sin(uv_z.x + TIME * wave_speed) * 
                    cos(uv_z.y * 0.5 + TIME * wave_speed * 0.7) * 0.5 +
                    sin(uv_z.x * 2.0 - TIME * wave_speed * 1.3) * 
                    cos(uv_z.y * 1.5 - TIME * wave_speed * 0.9) * 0.3) * wave_height;
    
    // Vetores tangentes
    vec3 tangent = normalize(vec3(dx, wave_x - final_wave, 0.0));
    vec3 bitangent = normalize(vec3(0.0, wave_z - final_wave, dz));
    
    // Normal = cross product
    NORMAL = normalize(cross(bitangent, tangent));
}

// ========================================
// FRAGMENT SHADER (COR, REFLEXÃO, ESPUMA)
// ========================================

void fragment() {
    // ========================================
    // 1. COR BASE (profundidade)
    // ========================================
    
    float depth = length(VERTEX);
    float depth_fade = clamp(depth / color_depth, 0.0, 1.0);
    
    // Mistura de cor rasa → profunda
    vec3 base_color = mix(water_color.rgb, deep_water_color.rgb, depth_fade);
    
    // ========================================
    // 2. ESPUMA (nas cristas das ondas)
    // ========================================
    
    float foam = 0.0;
    
    if (enable_foam) {
        // Detectar cristas: normal aponta para cima
        float wave_crest = NORMAL.y;
        foam = smoothstep(foam_threshold, 1.0, wave_crest);
        
        // Adicionar ruído para espuma orgânica
        vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
        vec2 foam_uv = world_pos.xz * 2.0 + TIME * wave_speed * 0.5;
        float foam_noise = fbm(foam_uv * 5.0);
        
        // Combinar
        foam *= foam_noise * foam_intensity;
        foam = clamp(foam, 0.0, 1.0);
        
        // Misturar espuma com cor base
        base_color = mix(base_color, foam_color.rgb, foam);
    }
    
    // ========================================
    // 3. REFLEXÃO E TRANSPARÊNCIA
    // ========================================
    
    ALBEDO = base_color;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = specular;
    ALPHA = mix(water_color.a, deep_water_color.a, depth_fade);
    
    // ========================================
    // 4. RIM LIGHTING (brilho nas bordas)
    // ========================================
    
    float rim = 1.0 - max(dot(NORMAL, VIEW), 0.0);
    rim = pow(rim, 3.0);
    EMISSION = vec3(rim * 0.15); // Brilho sutil nas bordas
    
    // ========================================
    // 5. FRESNEL (reflexão nas bordas)
    // ========================================
    
    float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 5.0);
    ALBEDO = mix(ALBEDO, vec3(1.0), fresnel * 0.1);
}
