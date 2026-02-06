shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// ========================================
// 🎮 SHADER DE ÁGUA ESTILO MUCK
// ========================================
// Características:
// - Low-poly (poucas subdivisões)
// - Cores saturadas e vibrantes
// - Ondas grandes e visíveis
// - Sem cel-shading (gradiente suave)
// - Espuma simples mas marcante
// - Visual "indie game" moderno
// ========================================

// ========================================
// PARÂMETROS
// ========================================

group_uniforms Ondas_Muck;
uniform float wave_speed : hint_range(0.0, 5.0, 0.1) = 1.5; // ⚡ Ondas rápidas
uniform float wave_height : hint_range(0.0, 3.0, 0.1) = 1.2; // 📏 Ondas GRANDES
uniform float wave_scale : hint_range(0.1, 10.0, 0.1) = 1.5; // 📐 Escala (ondas largas)

group_uniforms Cores_Vibrantes;
uniform vec4 water_shallow : source_color = vec4(0.2, 0.65, 0.9, 0.75); // 💙 Água rasa (azul vibrante)
uniform vec4 water_deep : source_color = vec4(0.05, 0.35, 0.7, 0.9); // 🌊 Água profunda (azul escuro)
uniform float depth_fade : hint_range(0.0, 20.0, 0.5) = 5.0; // 📊 Transição de profundidade

group_uniforms Espuma_Simples;
uniform bool enable_foam = true; // 🫧 Ativar espuma
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0); // ⚪ Cor da espuma (branco azulado)
uniform float foam_amount : hint_range(0.0, 1.0, 0.01) = 0.4; // 📊 Quantidade de espuma
uniform float foam_edge : hint_range(0.0, 5.0, 0.1) = 2.0; // 📏 Espuma nas bordas (shore)

group_uniforms Reflexao;
uniform float shininess : hint_range(0.0, 128.0, 1.0) = 32.0; // ✨ Brilho especular
uniform float specular_strength : hint_range(0.0, 2.0, 0.1) = 0.8; // 💎 Intensidade do brilho
uniform vec3 sun_direction = vec3(0.5, 0.8, 0.3); // ☀️ Direção da luz

group_uniforms Visual_LowPoly;
uniform bool vertex_snap = false; // 📐 Ativar "vertex snapping" (visual PS1/low-poly)
uniform float snap_amount : hint_range(0.0, 1.0, 0.01) = 0.1; // 📏 Quanto "pixelizar" os vértices

// ========================================
// FUNÇÕES
// ========================================

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// ========================================
// VERTEX SHADER
// ========================================

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Vertex snapping (efeito low-poly/PS1)
    if (vertex_snap) {
        float grid = 1.0 / snap_amount;
        world_pos = floor(world_pos * grid) / grid;
    }
    
    vec2 uv = world_pos.xz * wave_scale * 0.1;
    
    // ========================================
    // ONDAS ESTILO MUCK (grandes e simples)
    // ========================================
    
    // Onda 1: Principal (grande e lenta)
    float wave1 = sin(uv.x * 2.0 + TIME * wave_speed) * 
                  cos(uv.y * 1.5 + TIME * wave_speed * 0.8);
    
    // Onda 2: Secundária (perpendicular)
    float wave2 = sin(uv.y * 2.5 - TIME * wave_speed * 1.2) * 
                  cos(uv.x * 1.8 - TIME * wave_speed * 0.9);
    
    // Onda 3: Detalhes (pequena)
    float wave3 = noise(uv * 4.0 + TIME * wave_speed * 0.5) - 0.5;
    
    // Combinar (ondas GRANDES e visíveis)
    float total_wave = (wave1 * 0.5 + wave2 * 0.35 + wave3 * 0.15) * wave_height;
    
    VERTEX.y += total_wave;
    
    // ========================================
    // NORMAIS (simples para low-poly)
    // ========================================
    
    // Calcular normal baseado nas ondas
    float offset = 0.1;
    vec2 uv_x = (world_pos.xz + vec2(offset, 0.0)) * wave_scale * 0.1;
    vec2 uv_z = (world_pos.xz + vec2(0.0, offset)) * wave_scale * 0.1;
    
    float wave_x = (sin(uv_x.x * 2.0 + TIME * wave_speed) * 
                    cos(uv_x.y * 1.5 + TIME * wave_speed * 0.8) * 0.5 +
                    sin(uv_x.y * 2.5 - TIME * wave_speed * 1.2) * 
                    cos(uv_x.x * 1.8 - TIME * wave_speed * 0.9) * 0.35) * wave_height;
    
    float wave_z = (sin(uv_z.x * 2.0 + TIME * wave_speed) * 
                    cos(uv_z.y * 1.5 + TIME * wave_speed * 0.8) * 0.5 +
                    sin(uv_z.y * 2.5 - TIME * wave_speed * 1.2) * 
                    cos(uv_z.x * 1.8 - TIME * wave_speed * 0.9) * 0.35) * wave_height;
    
    vec3 tangent = normalize(vec3(offset, wave_x - total_wave, 0.0));
    vec3 bitangent = normalize(vec3(0.0, wave_z - total_wave, offset));
    
    NORMAL = normalize(cross(bitangent, tangent));
}

// ========================================
// FRAGMENT SHADER
// ========================================

void fragment() {
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // ========================================
    // 1. COR BASE (profundidade)
    // ========================================
    
    // Distância para fade de cor
    float depth = length(VERTEX);
    float depth_factor = clamp(depth / depth_fade, 0.0, 1.0);
    
    // Gradiente suave (NÃO cel-shading - isso é importante para Muck!)
    vec3 base_color = mix(water_shallow.rgb, water_deep.rgb, depth_factor);
    
    // ========================================
    // 2. ESPUMA (simples e marcante)
    // ========================================
    
    float foam = 0.0;
    
    if (enable_foam) {
        // Espuma nas cristas
        float wave_crest = NORMAL.y;
        foam = smoothstep(1.0 - foam_amount, 1.0, wave_crest);
        
        // Adicionar movimento à espuma
        vec2 foam_uv = world_pos.xz * 2.0;
        foam_uv += vec2(TIME * wave_speed * 0.3, TIME * wave_speed * 0.2);
        float foam_noise = noise(foam_uv * 3.0);
        
        foam *= foam_noise;
        
        // Espuma nas bordas/shore (baseado em profundidade)
        float shore_foam = smoothstep(foam_edge, 0.0, depth);
        foam = max(foam, shore_foam * 0.7);
        
        // Aplicar espuma
        base_color = mix(base_color, foam_color.rgb, foam);
    }
    
    // ========================================
    // 3. ILUMINAÇÃO (Lambert simples + Specular)
    // ========================================
    
    vec3 normal = normalize(NORMAL);
    vec3 light_dir = normalize(sun_direction);
    vec3 view_dir = normalize(VIEW);
    
    // Difusa (Lambert)
    float diffuse = max(dot(normal, light_dir), 0.0);
    
    // Especular (Phong simples)
    vec3 reflect_dir = reflect(-light_dir, normal);
    float specular = pow(max(dot(view_dir, reflect_dir), 0.0), shininess);
    specular *= specular_strength;
    
    // Combinar iluminação
    vec3 lit_color = base_color * (0.6 + diffuse * 0.4); // Ambient + Diffuse
    lit_color += vec3(specular); // Adicionar brilho especular
    
    // ========================================
    // 4. TRANSPARÊNCIA E OUTPUT
    // ========================================
    
    ALBEDO = lit_color;
    ALPHA = mix(water_shallow.a, water_deep.a, depth_factor);
    
    // Sem propriedades PBR complexas (Muck é simples)
    METALLIC = 0.0;
    ROUGHNESS = 0.5;
    
    // Emissão sutil nos brilhos
    EMISSION = vec3(specular * 0.3);
}
