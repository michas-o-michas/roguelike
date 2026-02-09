extends Node3D
class_name InfiniteWorldGenerator

## Sistema de mundo infinito - gera chunks ao redor do jogador dinamicamente

@export var auto_start: bool = false ## 🚀 Iniciar geração automaticamente no _ready. false = aguarda comando manual

@export var player_path: NodePath ## 🎮 Caminho para o jogador (ex: ../Player). OU adicione o player ao grupo "player"
@export var chunk_size: int = 100 ## 📐 Tamanho de cada chunk em metros (50-200). Menor = mais chunks, maior = chunks maiores
@export var view_distance: int = 3 ## 👁️ Quantos chunks carregar ao redor do jogador. 3 = 7x7 chunks = 700x700m visíveis (com chunk_size=100)
@export var world_seed: int = 12345 ## 🌱 Seed para geração procedural. Mesmo seed = mesmo mundo

@export_group("🎨 Tema do Mundo")
@export var world_theme: WorldTheme ## 🌍 Tema visual do mundo (Normal, Deserto, Lava, Neve, Alien). Muda cores, líquido, atmosfera!
@export var show_layer_debug: bool = false ## 🔍 DEBUG: Mostrar camadas do terreno em cores vivas (Azul=água, Verde=grama, Cinza=rocha, Branco=neve)

@export_group("Otimização")
@export var chunks_per_frame: int = 1 ## ⚡ Quantos chunks gerar por frame. 1 = suave (60 FPS), 2-3 = rápido (pode dar lag), 5+ = muito lag
@export var unload_distance: int = 5 ## 🗑️ Distância para descarregar chunks (em chunks). Deve ser > view_distance. Recomendado: view_distance + 2
@export var skip_terrain_collision: bool = false ## ⚠️ Pular geração de colisão (10x mais rápido, MAS personagem cai pelo chão). Só para testes visuais!
@export var enable_collision_lod: bool = true ## 🎯 Ativar LOD de colisão (colisões simplificadas em chunks distantes = muito mais rápido!)
@export var collision_lod_near: int = 2 ## 📍 Chunks próximos (0-N): colisão detalhada. 2 = chunks até 2 de distância têm colisão completa
@export var collision_lod_far: int = 4 ## 📍 Chunks distantes (N+): colisão simplificada. 4 = chunks além de 4 têm colisão simples
@export var enable_visual_lod: bool = false ## 🎨 DESABILITADO para evitar gaps! Ativar LOD visual (meshes simplificados em chunks distantes = muito mais FPS!)
@export var visual_lod_near: int = 2 ## 📍 Chunks próximos: mesh completo. 2 = chunks até 2 de distância têm mesh completo
@export var visual_lod_far: int = 4 ## 📍 Chunks distantes: mesh simplificado. 4 = chunks além de 4 têm mesh reduzido
@export var use_shared_material: bool = true ## 🎨 Usar material compartilhado (muito mais rápido que criar um por chunk)
@export var async_generation: bool = true ## ⚡ Gerar chunks de forma assíncrona (não trava o frame, melhor FPS)

@export_group("Terreno")
@export var noise_frequency: float = 0.002 ## 🌊 Frequência do ruído (0.001-0.005). Menor = terreno mais suave, maior = mais variado
@export var noise_amplitude: float = 25.0 ## 📏 Altura MÁXIMA do terreno. 25 = colinas, 50 = montanhas, 80+ = montanhas épicas. Combine com height_redistribution!
@export var octaves: int = 5 ## 🎨 Camadas de detalhe do terreno (3-8). Mais = mais detalhado mas mais lento
@export var persistence: float = 0.45 ## 📉 Quanto cada octave afeta a altura (0.3-0.7). Menor = mais suave
@export var lacunarity: float = 2.0 ## 🔁 Frequência entre octaves (1.5-3.0). Maior = mais detalhes pequenos
@export var height_redistribution: float = 1.8 ## 🏔️ Distribuição de altura. 1.0 = natural, 1.5+ = mais planícies, <1.0 = mais montanhas
@export var terrain_subdivisions: int = 20 ## 🔲 Subdivisões do mesh por chunk (10-30). Mais = terreno mais suave mas mais pesado. 20 = balanceado
@export var reduce_near_subdivisions: bool = false ## 🔻 DESABILITADO para evitar gaps!
@export var near_subdivisions_factor: float = 0.6 ## 📐 Fator de redução para chunks próximos (0.3-1.0). 0.6 = 60% das subdivisões = muito menos triângulos. Menor = menos triângulos mas terreno menos suave

@export_group("🌊 Níveis de Camadas")
@export var water_level: float = -8.0 ## 🌊 Altura do nível da água. Tudo abaixo = submerso. -8 = pouca água, -2 = muita água
@export var water_depth_limit: float = 10.0 ## 🏊 Profundidade máxima da água (metros). Evita vales muito fundos. 10 = normal, 20 = oceano profundo, 5 = raso
@export var beach_level: float = -6.0 ## 🏖️ Altura onde termina a praia e começa a grama. Deve ser > water_level
@export var grass_level: float = 2.0 ## 🌱 Altura onde grama baixa vira grama média/floresta
@export var mountain_level: float = 18.0 ## ⛰️ Altura onde começa rocha/montanha (DEPRECATED - use rock_start_height)

@export_group("🪨 Camadas de Altitude")
@export var enable_rock_layer: bool = true ## 🪨 Ativar camada de rocha nas montanhas
@export var rock_start_height: float = 18.0 ## 🏔️ Altura onde começa a rocha (normalmente = mountain_level)
@export var rock_thickness: float = 12.0 ## 📏 Espessura da camada de rocha (metros). 8 = fina, 15 = média, 25+ = montanhas rochosas épicas

@export var enable_snow_layer: bool = true ## ❄️ Ativar camada de neve nos picos
@export var snow_start_height: float = -1.0 ## 🏔️ Altura onde começa a neve. Se -1, calcula automaticamente (rock_start + rock_thickness)
@export var snow_transition: float = 5.0 ## 🌨️ Tamanho da transição rocha→neve (metros). 3 = abrupto, 8 = suave

@export_group("Vegetação")
@export var spawn_spacing: float = 5.0 ## 📏 Distância entre tentativas de spawn (metros). 5 = denso, 7 = normal, 10+ = esparso
@export var biomes: Array[BiomeData] = [] ## 🌳 Biomas com difficulty_tier! Tier 1 = perto do spawn (floresta simples), Tier 2+ = longe (floresta perigosa, vulcão)
@export var enable_vegetation: bool = true ## 🌿 Ativar/desativar spawn de vegetação. false = só terreno (útil para testar performance)
@export var biome_transition_distance: float = 200.0 ## 🔄 Distância de transição suave entre tiers de biomas (metros)

@export_group("Água")
@export var enable_water: bool = true ## 🌊 Ativar/desativar plano de água. false = sem água no mundo
@export var water_size: float = 2000.0 ## 📐 Tamanho do plano de água (metros). Deve ser maior que a área explorável. 2000 = 2km x 2km
@export var use_animated_water: bool = true ## 🌊 Usar shader animado de água (ondas). false = água estática
@export var water_shader_path: String = "res://shaders/agua_animada.gdshader" ## 📁 Caminho para o shader de água (deixe vazio para usar shader embutido)

@export_group("Pontos de Interesse (POIs)")
@export var enable_pois: bool = true ## 🏛️ Ativar/desativar sistema de POIs
@export var poi_check_interval: float = 300.0 ## 🔍 A cada X metros andados, verifica se spawna POI
@export var poi_min_spacing: float = 200.0 ## 📏 Distância mínima entre POIs (evita spawnar muito perto)
@export var poi_per_area_chance: float = 0.3 ## 🎲 Chance de spawnar POI ao entrar em nova área (0.0-1.0)
@export var pois: Array[POIData] = [] ## 📍 POIs com difficulty_tier! Tier 1 = perto do spawn (0-500m), Tier 2 = médio (500-1500m), Tier 3+ = longe

@export_group("Spawners de Animais")
@export var enable_spawners: bool = true ## 🐾 Ativar/desativar sistema de spawners
@export var spawner_check_interval: float = 150.0 ## 🔍 A cada X metros, verifica se spawna animal spawner
@export var spawner_min_spacing: float = 80.0 ## 📏 Distância mínima entre spawners
@export var spawner_per_area_chance: float = 0.5 ## 🎲 Chance de spawnar ao entrar em nova área (0.0-1.0)
@export var animal_spawners: Array[AnimalSpawnerData] = [] ## 🐺 Spawners com difficulty_tier! Tier 1 = animais fracos, Tier 3+ = bosses

# Dicionários de chunks
var loaded_chunks = {} ## {Vector2i: ChunkData}
var chunks_to_generate = [] ## Fila de chunks para gerar
var chunks_generating = {} ## Chunks sendo gerados agora

# Noises
var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var temperature_noise: FastNoiseLite

# Player tracking
var player: Node3D
var last_player_chunk: Vector2i = Vector2i(999999, 999999)

# Water
var water_mesh: MeshInstance3D

# POIs e Spawners dinâmicos (spawnam conforme jogador explora)
var spawned_pois: Dictionary = {} ## {Vector2i: POI_node}
var spawned_spawners: Dictionary = {} ## {Vector2i: Spawner_node}
var last_poi_check_pos: Vector3 = Vector3(999999, 0, 999999)
var last_spawner_check_pos: Vector3 = Vector3(999999, 0, 999999)

# Otimizações: Material compartilhado e cache
var shared_terrain_material: StandardMaterial3D
var height_cache: Dictionary = {}  # Cache de alturas (opcional, pode ajudar)

# ========================================
# CLASSE INTERNA - DEVE VIR ANTES DAS FUNÇÕES!
# ========================================
class ChunkData:
	var chunk_pos: Vector2i
	var terrain_mesh: MeshInstance3D
	var terrain_collision: StaticBody3D
	var objects: Array[Node3D] = []
	var is_loaded: bool = false
	var collision_lod_level: int = 0  # 0 = detalhada, 1 = simplificada, 2 = muito simplificada

func _ready():
	setup_noise()
	
	# Criar material compartilhado para otimização
	if use_shared_material:
		shared_terrain_material = StandardMaterial3D.new()
		shared_terrain_material.vertex_color_use_as_albedo = true
		shared_terrain_material.roughness = 0.9
	
	if enable_water:
		create_water()
	
	if player_path != NodePath(""):
		player = get_node_or_null(player_path)
	
	if not player:
		push_warning("⚠️ Player não encontrado! Procurando automaticamente...")
		player = get_tree().get_first_node_in_group("player")

# Iniciar geração do mundo manualmente
func start_world_generation():
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		print("🌍 Iniciando geração do mundo! Player: ", player.name)
		set_process(true)
		set_physics_process(true)
		update_chunks()
		return true
	else:
		push_error("❌ Player não encontrado!")
		return false

# Obter número de chunks carregados
func get_loaded_chunks_count() -> int:
	return loaded_chunks.size()

# Obter número total de chunks necessários (baseado em view_distance)
func get_total_chunks_needed() -> int:
	if not player:
		return 0
	var player_chunk = world_to_chunk(player.global_position)
	var total = 0
	for x in range(-view_distance, view_distance + 1):
		for z in range(-view_distance, view_distance + 1):
			total += 1
	return total

# Verificar se o carregamento inicial está completo
func is_initial_load_complete() -> bool:
	if not player:
		return false
	
	var player_chunk = world_to_chunk(player.global_position)
	var chunks_needed = get_total_chunks_needed()
	var chunks_loaded = 0
	
	# Contar quantos chunks necessários já estão carregados
	for x in range(-view_distance, view_distance + 1):
		for z in range(-view_distance, view_distance + 1):
			var chunk_pos = player_chunk + Vector2i(x, z)
			if loaded_chunks.has(chunk_pos):
				chunks_loaded += 1
	
	# Considerar completo quando pelo menos 80% dos chunks estão carregados
	return chunks_loaded >= (chunks_needed * 0.8)

func _process(_delta):
	if not player:
		return
	
	# Fazer água seguir o jogador (água infinita)
	if water_mesh and enable_water:
		water_mesh.global_position.x = player.global_position.x
		water_mesh.global_position.z = player.global_position.z
	
	var current_chunk = world_to_chunk(player.global_position)
	
	# Player mudou de chunk?
	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		update_chunks()
	
	# Gerar chunks da fila (com otimização assíncrona)
	if chunks_to_generate.size() > 0:
		if async_generation:
			# Em modo assíncrono, gerar apenas 1 chunk por frame para manter FPS
			generate_queued_chunks()
		else:
			# Modo síncrono: gerar múltiplos chunks conforme configurado
			generate_queued_chunks()
	
	# Verificar se precisa spawnar POIs (otimizado: menos frequente)
	if enable_pois and player.global_position.distance_to(last_poi_check_pos) > poi_check_interval:
		check_and_spawn_pois()
		last_poi_check_pos = player.global_position
	
	# Verificar se precisa spawnar Animal Spawners (otimizado: menos frequente)
	if enable_spawners and player.global_position.distance_to(last_spawner_check_pos) > spawner_check_interval:
		check_and_spawn_spawners()
		last_spawner_check_pos = player.global_position

func setup_noise():
	seed(world_seed)
	
	# Ruído principal
	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = persistence
	
	# Biomas
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = world_seed + 1000
	biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_noise.frequency = 0.008
	
	# Umidade
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = world_seed + 2000
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = 0.015
	
	# Temperatura
	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = world_seed + 3000
	temperature_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	temperature_noise.frequency = 0.012

func create_water():
	if not world_theme:
		print("⚠️ WorldTheme não configurado, usando água padrão")
	
	# Verificar se o tema tem líquido
	if world_theme and world_theme.liquid_type == WorldTheme.LiquidType.NONE:
		print("🏜️ Mundo sem líquido (deserto/seco)")
		return
	
	water_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(water_size, water_size)
	plane.subdivide_width = 50  # Subdivisões para ondas suaves
	plane.subdivide_depth = 50
	water_mesh.mesh = plane
	
	# Usar nível customizado se definido
	var liquid_level = water_level
	if world_theme and world_theme.use_custom_levels:
		liquid_level = world_theme.custom_water_level
	
	water_mesh.position.y = liquid_level
	
	# ========================================
	# ESCOLHER MATERIAL: Shader Animado ou Simples
	# ========================================
	if use_animated_water:
		var shader_material = create_animated_water_shader()
		if shader_material:
			water_mesh.material_override = shader_material
			print("🌊 Água animada ativada!")
		else:
			# Fallback para material simples
			print("⚠️ Shader não encontrado, usando água simples")
			water_mesh.material_override = create_simple_water_material()
	else:
		water_mesh.material_override = create_simple_water_material()
	
	add_child(water_mesh)
	
	# Colisão do líquido
	var water_body = StaticBody3D.new()
	var water_collision = CollisionShape3D.new()
	var water_shape = BoxShape3D.new()
	water_shape.size = Vector3(water_size, 0.5, water_size)
	water_collision.shape = water_shape
	water_collision.position.y = liquid_level - 0.25
	water_body.add_child(water_collision)
	add_child(water_body)
	
	# Log do tipo de líquido
	if world_theme:
		var liquid_name = get_liquid_name(world_theme.liquid_type)
		print("🌊 Líquido: ", liquid_name, " em Y=", liquid_level)

func create_animated_water_shader() -> ShaderMaterial:
	# Tentar carregar shader do caminho especificado
	var shader: Shader = null
	
	if water_shader_path != "" and ResourceLoader.exists(water_shader_path):
		shader = load(water_shader_path)
	
	# Se não encontrou, usar shader embutido (código inline)
	if not shader:
		shader = Shader.new()
		shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 water_color : source_color = vec4(0.15, 0.5, 0.8, 0.7);
uniform float wave_speed : hint_range(0.0, 3.0) = 1.0;
uniform float wave_height : hint_range(0.0, 1.0) = 0.2;
uniform float metallic : hint_range(0.0, 1.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;

float noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float smooth_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = noise(i);
    float b = noise(i + vec2(1.0, 0.0));
    float c = noise(i + vec2(0.0, 1.0));
    float d = noise(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec2 uv = world_pos.xz * 0.1;
    
    float wave1 = sin(uv.x * 2.0 + TIME * wave_speed + uv.y * 0.5) * 0.5;
    float wave2 = smooth_noise(uv * 2.0 + TIME * wave_speed * 0.3) * 0.3;
    float wave3 = smooth_noise(uv * 4.0 - TIME * wave_speed * 0.5) * 0.2;
    
    VERTEX.y += (wave1 + wave2 + wave3) * wave_height;
}

void fragment() {
    ALBEDO = water_color.rgb;
    ALPHA = water_color.a;
    METALLIC = metallic;
    ROUGHNESS = roughness;
}
"""
	
	var material = ShaderMaterial.new()
	material.shader = shader
	
	# Aplicar cores do WorldTheme se existir
	if world_theme:
		material.set_shader_parameter("water_color", world_theme.liquid_color)
		material.set_shader_parameter("metallic", world_theme.liquid_metallic)
		material.set_shader_parameter("roughness", world_theme.liquid_roughness)
	
	return material

func create_simple_water_material() -> StandardMaterial3D:
	var water_material = StandardMaterial3D.new()
	
	# Aplicar cor e propriedades do tema
	if world_theme:
		water_material.albedo_color = world_theme.liquid_color
		water_material.metallic = world_theme.liquid_metallic
		water_material.roughness = world_theme.liquid_roughness
	else:
		# Padrão
		water_material.albedo_color = Color(0.15, 0.5, 0.8, 0.6)
		water_material.metallic = 0.8
		water_material.roughness = 0.05
	
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.rim_enabled = true
	water_material.rim = 0.6
	water_material.rim_tint = 0.5
	water_material.clearcoat_enabled = true
	water_material.clearcoat = 0.5
	water_material.clearcoat_roughness = 0.1
	
	return water_material

func get_liquid_name(type: WorldTheme.LiquidType) -> String:
	match type:
		WorldTheme.LiquidType.WATER: return "Água"
		WorldTheme.LiquidType.LAVA: return "Lava"
		WorldTheme.LiquidType.ACID: return "Ácido"
		WorldTheme.LiquidType.OIL: return "Óleo"
		WorldTheme.LiquidType.BLOOD: return "Sangue"
		WorldTheme.LiquidType.CRYSTAL: return "Cristal Líquido"
		_: return "Desconhecido"

func world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)

func chunk_to_world(chunk_pos: Vector2i) -> Vector3:
	return Vector3(
		chunk_pos.x * chunk_size,
		0,
		chunk_pos.y * chunk_size
	)

func update_chunks():
	if not player:
		return
	
	var player_chunk = world_to_chunk(player.global_position)
	
	# Chunks que devem estar carregados
	var chunks_needed = []
	for x in range(-view_distance, view_distance + 1):
		for z in range(-view_distance, view_distance + 1):
			var chunk_pos = player_chunk + Vector2i(x, z)
			chunks_needed.append(chunk_pos)
			
			# Adicionar à fila se não existe
			if not loaded_chunks.has(chunk_pos) and not chunks_generating.has(chunk_pos):
				if not chunks_to_generate.has(chunk_pos):
					chunks_to_generate.append(chunk_pos)
	
	# Descarregar chunks distantes
	var chunks_to_unload = []
	for chunk_pos in loaded_chunks.keys():
		var dist = max(abs(chunk_pos.x - player_chunk.x), abs(chunk_pos.y - player_chunk.y))
		if dist > unload_distance:
			chunks_to_unload.append(chunk_pos)
	
	for chunk_pos in chunks_to_unload:
		unload_chunk(chunk_pos)
	
	# Atualizar LOD de colisões se habilitado
	if enable_collision_lod:
		update_collision_lod(player_chunk)

func generate_queued_chunks():
	var generated = 0
	var max_chunks = chunks_per_frame
	
	# Em modo assíncrono, limitar a 1 chunk por frame para manter FPS suave
	if async_generation:
		max_chunks = 1
	
	while generated < max_chunks and chunks_to_generate.size() > 0:
		var chunk_pos = chunks_to_generate.pop_front()
		
		if not loaded_chunks.has(chunk_pos):
			chunks_generating[chunk_pos] = true
			generate_chunk(chunk_pos)
			chunks_generating.erase(chunk_pos)
			generated += 1
			
			# Yield após cada chunk se async estiver ativado
			if async_generation:
				await get_tree().process_frame

func generate_chunk(chunk_pos: Vector2i):
	var chunk_data = ChunkData.new()
	chunk_data.chunk_pos = chunk_pos
	
	var world_pos = chunk_to_world(chunk_pos)
	
	# Gerar terreno
	create_chunk_terrain(chunk_data, world_pos)
	
	# Gerar vegetação
	if enable_vegetation:
		create_chunk_vegetation(chunk_data, world_pos)
	
	chunk_data.is_loaded = true
	loaded_chunks[chunk_pos] = chunk_data

# ========================================
# FUNÇÃO CORRIGIDA - SEM GAPS!
# ========================================
func create_chunk_terrain(chunk_data, start_pos: Vector3):
	# ===== FIX PARA GAPS: TODOS OS CHUNKS USAM MESMAS SUBDIVISÕES =====
	var visual_subdivisions = terrain_subdivisions
	
	# LOD VISUAL DESABILITADO - causa gaps entre chunks!
	# Para reativar: implementar geomorph ou skirts
	
	var mesh_instance = MeshInstance3D.new()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var step = float(chunk_size) / visual_subdivisions
	var vertices = []
	var colors = []
	
	# ===== GERAR VÉRTICES COM ALINHAMENTO PERFEITO =====
	for z in range(visual_subdivisions + 1):
		for x in range(visual_subdivisions + 1):
			# CRÍTICO: Arredondar para evitar erros de floating point
			var pos_x = snappedf(start_pos.x + (x * step), 0.001)
			var pos_z = snappedf(start_pos.z + (z * step), 0.001)
			
			var height = get_terrain_height(pos_x, pos_z)
			
			vertices.append(Vector3(pos_x, height, pos_z))
			colors.append(get_terrain_color(pos_x, pos_z, height))
	
	# Criar triângulos usando índices (mais eficiente)
	for z in range(visual_subdivisions):
		for x in range(visual_subdivisions):
			var i = z * (visual_subdivisions + 1) + x
			
			# Triângulo 1
			surface_tool.set_color(colors[i])
			surface_tool.add_vertex(vertices[i])
			surface_tool.set_color(colors[i + 1])
			surface_tool.add_vertex(vertices[i + 1])
			surface_tool.set_color(colors[i + visual_subdivisions + 1])
			surface_tool.add_vertex(vertices[i + visual_subdivisions + 1])
			
			# Triângulo 2
			surface_tool.set_color(colors[i + 1])
			surface_tool.add_vertex(vertices[i + 1])
			surface_tool.set_color(colors[i + visual_subdivisions + 2])
			surface_tool.add_vertex(vertices[i + visual_subdivisions + 2])
			surface_tool.set_color(colors[i + visual_subdivisions + 1])
			surface_tool.add_vertex(vertices[i + visual_subdivisions + 1])
	
	# Gerar normais suavizadas (SurfaceTool já faz isso automaticamente)
	surface_tool.generate_normals()
	mesh_instance.mesh = surface_tool.commit()
	
	# Usar material compartilhado ou criar novo
	if use_shared_material and shared_terrain_material:
		mesh_instance.material_override = shared_terrain_material
	else:
		var material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.9
		mesh_instance.material_override = material
	
	add_child(mesh_instance)
	chunk_data.terrain_mesh = mesh_instance
	
	# Colisão com LOD baseado em distância
	if not skip_terrain_collision:
		create_chunk_collision(chunk_data, start_pos, vertices)

# Função auxiliar: calcula distância do chunk ao jogador (em chunks)
func get_chunk_distance_to_player(chunk_pos: Vector2i) -> int:
	if not player:
		return 0
	
	var player_chunk = world_to_chunk(player.global_position)
	var dist_x = abs(chunk_pos.x - player_chunk.x)
	var dist_z = abs(chunk_pos.y - player_chunk.y)
	return max(dist_x, dist_z)  # Distância Chebyshev (distância em chunks)

# Cria colisão com LOD baseado na distância do jogador
func create_chunk_collision(chunk_data, start_pos: Vector3, vertices: Array):
	var static_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	
	# Calcular distância do chunk ao jogador e nível de LOD
	var chunk_distance = 0
	var lod_level = 0
	
	if enable_collision_lod and player:
		chunk_distance = get_chunk_distance_to_player(chunk_data.chunk_pos)
		
		if chunk_distance <= collision_lod_near:
			lod_level = 0  # Detalhada
		elif chunk_distance <= collision_lod_far:
			lod_level = 1  # Simplificada
		else:
			lod_level = 2  # Muito simplificada
	else:
		lod_level = 0  # Sem LOD = sempre detalhada
	
	chunk_data.collision_lod_level = lod_level
	
	var collision_shape: Shape3D
	
	if lod_level == 0:
		# COLISÃO DETALHADA: Chunks próximos (distância <= collision_lod_near)
		# Usa o mesh completo para colisão precisa
		collision_shape = chunk_data.terrain_mesh.mesh.create_trimesh_shape()
	
	elif lod_level == 1:
		# COLISÃO SIMPLIFICADA: Chunks médios (distância entre near e far)
		# Reduz subdivisões pela metade = 4x menos triângulos
		var simplified_subdivisions = max(terrain_subdivisions / 2, 4)  # Mínimo 4 subdivisões
		collision_shape = create_simplified_collision(start_pos, simplified_subdivisions)
	
	else:
		# COLISÃO MUITO SIMPLIFICADA: Chunks distantes (distância > collision_lod_far)
		# Reduz subdivisões para 1/4 = 16x menos triângulos
		var very_simplified_subdivisions = max(terrain_subdivisions / 4, 3)  # Mínimo 3 subdivisões
		collision_shape = create_simplified_collision(start_pos, very_simplified_subdivisions)
	
	collision.shape = collision_shape
	static_body.add_child(collision)
	add_child(static_body)
	chunk_data.terrain_collision = static_body

# Atualiza LOD de colisões quando jogador se move (otimização dinâmica)
func update_collision_lod(player_chunk: Vector2i):
	if not enable_collision_lod:
		return
	
	# Atualizar apenas alguns chunks por frame para não causar lag
	var updated_this_frame = 0
	var max_updates_per_frame = 2
	
	for chunk_pos in loaded_chunks.keys():
		if updated_this_frame >= max_updates_per_frame:
			break
		
		var chunk_data = loaded_chunks[chunk_pos]
		if not chunk_data or not chunk_data.terrain_collision:
			continue
		
		var chunk_distance = get_chunk_distance_to_player(chunk_pos)
		var new_lod_level = 0
		
		if chunk_distance <= collision_lod_near:
			new_lod_level = 0
		elif chunk_distance <= collision_lod_far:
			new_lod_level = 1
		else:
			new_lod_level = 2
		
		# Se o LOD mudou, atualizar colisão
		if chunk_data.collision_lod_level != new_lod_level:
			var world_pos = chunk_to_world(chunk_pos)
			
			# Remover colisão antiga
			if chunk_data.terrain_collision:
				chunk_data.terrain_collision.queue_free()
			
			# Criar nova colisão com LOD correto
			chunk_data.collision_lod_level = new_lod_level
			var static_body = StaticBody3D.new()
			var collision = CollisionShape3D.new()
			
			var collision_shape: Shape3D
			if new_lod_level == 0:
				collision_shape = chunk_data.terrain_mesh.mesh.create_trimesh_shape()
			elif new_lod_level == 1:
				var simplified_subdivisions = max(terrain_subdivisions / 2, 4)
				collision_shape = create_simplified_collision(world_pos, simplified_subdivisions)
			else:
				var very_simplified_subdivisions = max(terrain_subdivisions / 4, 3)
				collision_shape = create_simplified_collision(world_pos, very_simplified_subdivisions)
			
			collision.shape = collision_shape
			static_body.add_child(collision)
			add_child(static_body)
			chunk_data.terrain_collision = static_body
			
			updated_this_frame += 1

# Cria colisão simplificada com menos subdivisões
func create_simplified_collision(start_pos: Vector3, subdivisions: int) -> Shape3D:
	var step = float(chunk_size) / subdivisions
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var vertices = []
	
	# Gerar vértices simplificados
	for z in range(subdivisions + 1):
		for x in range(subdivisions + 1):
			var pos_x = start_pos.x + (x * step)
			var pos_z = start_pos.z + (z * step)
			var height = get_terrain_height(pos_x, pos_z)
			vertices.append(Vector3(pos_x, height, pos_z))
	
	# Criar triângulos simplificados
	for z in range(subdivisions):
		for x in range(subdivisions):
			var i = z * (subdivisions + 1) + x
			
			surface_tool.set_uv(Vector2(0, 0))
			surface_tool.add_vertex(vertices[i])
			surface_tool.set_uv(Vector2(1, 0))
			surface_tool.add_vertex(vertices[i + 1])
			surface_tool.set_uv(Vector2(0, 1))
			surface_tool.add_vertex(vertices[i + subdivisions + 1])
			
			surface_tool.set_uv(Vector2(1, 0))
			surface_tool.add_vertex(vertices[i + 1])
			surface_tool.set_uv(Vector2(1, 1))
			surface_tool.add_vertex(vertices[i + subdivisions + 2])
			surface_tool.set_uv(Vector2(0, 1))
			surface_tool.add_vertex(vertices[i + subdivisions + 1])
	
	surface_tool.generate_normals()
	var simplified_mesh = surface_tool.commit()
	return simplified_mesh.create_trimesh_shape()

func create_chunk_vegetation(chunk_data, start_pos: Vector3):
	# Otimização: reduzir vegetação em chunks distantes
	var chunk_distance = 0
	var vegetation_density = 1.0
	
	if player:
		chunk_distance = get_chunk_distance_to_player(chunk_data.chunk_pos)
		# Reduzir densidade de vegetação em chunks distantes
		if chunk_distance > visual_lod_far:
			vegetation_density = 0.3  # 70% menos vegetação
		elif chunk_distance > visual_lod_near:
			vegetation_density = 0.6  # 40% menos vegetação
	
	var biome_cache = {}
	var height_cache_local = {}  # Cache de alturas para evitar recálculos
	
	var x = start_pos.x
	while x < start_pos.x + chunk_size:
		var z = start_pos.z
		while z < start_pos.z + chunk_size:
			# Pular alguns spawns em chunks distantes (otimização)
			if vegetation_density < 1.0 and randf() > vegetation_density:
				z += spawn_spacing
				continue
			
			var pos_x = x + randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			var pos_z = z + randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			
			# Cache de altura (evitar recálculos)
			var height_key = Vector2i(int(pos_x), int(pos_z))
			var height: float
			if height_cache_local.has(height_key):
				height = height_cache_local[height_key]
			else:
				height = get_terrain_height(pos_x, pos_z)
				height_cache_local[height_key] = height
			
			if height < beach_level + 1.0:
				z += spawn_spacing
				continue
			
			var position = Vector3(pos_x, height, pos_z)
			
			# Bioma com cache melhorado
			var cache_key = Vector2i(int(pos_x / 20.0), int(pos_z / 20.0))
			var current_biome: BiomeData
			
			if biome_cache.has(cache_key):
				current_biome = biome_cache[cache_key]
			else:
				current_biome = get_biome_at_position(pos_x, pos_z, height)
				biome_cache[cache_key] = current_biome
			
			if current_biome:
				spawn_biome_item(current_biome, position, chunk_data)
			
			z += spawn_spacing
		x += spawn_spacing

func spawn_biome_item(biome: BiomeData, position: Vector3, chunk_data):
	for item in biome.biome_items:
		if not item or item.variants.is_empty():
			continue
		
		if randf() < item.spawn_chance:
			var variant = get_random_variant(item.variants)
			if variant and variant.scene:
				var obj = variant.scene.instantiate()
				obj.position = position
				obj.rotation.y = randf_range(0, TAU)
				var scale = randf_range(item.min_scale, item.max_scale)
				obj.scale = Vector3(scale, scale, scale)
				add_child(obj)
				chunk_data.objects.append(obj)
				
				# Sub-itens
				for sub_item in item.sub_items:
					if not sub_item or randf() > sub_item.spawn_chance:
						continue
					
					var offset = Vector3(
						randf_range(-sub_item.spawn_radius, sub_item.spawn_radius),
						0.0,
						randf_range(-sub_item.spawn_radius, sub_item.spawn_radius)
					)
					var sub_pos = position + offset
					sub_pos.y = get_terrain_height(sub_pos.x, sub_pos.z) + sub_item.height_offset
					
					var sub_variant = get_random_variant(sub_item.variants)
					if sub_variant and sub_variant.scene:
						var sub_obj = sub_variant.scene.instantiate()
						sub_obj.position = sub_pos
						sub_obj.rotation.y = randf_range(0, TAU)
						var sub_scale = randf_range(sub_item.min_scale, sub_item.max_scale)
						sub_obj.scale = Vector3(sub_scale, sub_scale, sub_scale)
						add_child(sub_obj)
						chunk_data.objects.append(sub_obj)

func get_random_variant(variants: Array[ItemVariant]) -> ItemVariant:
	if variants.is_empty():
		return null
	
	var total_weight = 0.0
	for variant in variants:
		if variant:
			total_weight += get_rarity_weight(variant.rarity)
	
	var roll = randf() * total_weight
	var current_weight = 0.0
	
	for variant in variants:
		if not variant:
			continue
		current_weight += get_rarity_weight(variant.rarity)
		if roll <= current_weight:
			return variant
	
	return variants[0]

func get_rarity_weight(rarity: ItemVariant.Rarity) -> float:
	match rarity:
		ItemVariant.Rarity.COMMON:
			return 10.0
		ItemVariant.Rarity.UNCOMMON:
			return 5.0
		ItemVariant.Rarity.RARE:
			return 2.0
		ItemVariant.Rarity.EPIC:
			return 0.5
		ItemVariant.Rarity.LEGENDARY:
			return 0.1
	return 1.0

func unload_chunk(chunk_pos: Vector2i):
	if not loaded_chunks.has(chunk_pos):
		return
	
	var chunk_data = loaded_chunks[chunk_pos]
	
	# Remover terreno
	if chunk_data.terrain_mesh:
		chunk_data.terrain_mesh.queue_free()
	if chunk_data.terrain_collision:
		chunk_data.terrain_collision.queue_free()
	
	# Remover objetos
	for obj in chunk_data.objects:
		if is_instance_valid(obj):
			obj.queue_free()
	
	loaded_chunks.erase(chunk_pos)

# Função auxiliar: estima rapidamente se estamos em zona de praia
func estimate_beach_zone(x: float, z: float) -> float:
	# Usar apenas o primeiro octave para estimativa rápida
	var quick_noise = noise.get_noise_2d(x, z)
	var quick_height = quick_noise * noise_amplitude * 0.6  # Estimativa mais precisa
	quick_height += 3.0
	return quick_height

func get_terrain_height(x: float, z: float) -> float:
	# ========================================
	# ETAPA 1: Gerar altura base com ruído (SEM modificações)
	# ========================================
	var noise_value = noise.get_noise_2d(x, z)
	var amplitude = noise_amplitude
	var frequency = 1.0
	var height = noise_value * amplitude
	
	for i in range(1, octaves):
		frequency *= lacunarity
		amplitude *= persistence
		height += noise.get_noise_2d(x * frequency, z * frequency) * amplitude
	
	# ========================================
	# ETAPA 2: Redistribuição de altura
	# ========================================
	if height > 0:
		var normalized = height / noise_amplitude
		normalized = pow(normalized, height_redistribution)
		height = normalized * noise_amplitude
	else:
		var normalized = abs(height) / noise_amplitude
		normalized = pow(normalized, 1.5)
		height = -normalized * noise_amplitude
	
	height += 3.0
	
	# ========================================
	# ETAPA 3: SUAVIZAÇÃO DE ÁGUA E PRAIA
	# Trata tanto áreas profundas quanto próximas à superfície
	# ========================================
	var distance_from_water = height - water_level
	
	# Zona expandida: de muito abaixo da água até praia acima
	# Isso garante que buracos profundos também sejam suavizados
	var deep_water_zone = -water_depth_limit  # Até o limite de profundidade
	var beach_zone_top = 15.0  # Expandido para 15m acima da água (praia mais larga e plana)
	
	if distance_from_water >= deep_water_zone and distance_from_water <= beach_zone_top:
		# Calcular fator de suavização baseado na distância da água
		var smooth_distance = abs(distance_from_water)
		
		# Área muito profunda (buracos): suavizar fortemente
		if distance_from_water < -5.0:
			# Quanto mais profundo, mais suavizar para eliminar buracos brutos
			var depth_factor = clamp((abs(distance_from_water) - 5.0) / (water_depth_limit - 5.0), 0.0, 1.0)
			depth_factor = depth_factor * depth_factor  # Quadrática
			
			# Criar fundo suave usando ruído de baixa frequência
			var deep_noise = noise.get_noise_2d(x * 0.0004, z * 0.0004)
			# Elevar o fundo gradualmente: quanto mais profundo, mais próximo da superfície
			var target_depth = water_level - 4.0 + (deep_noise * 2.0)  # Fundo suave a -4m
			
			# Suavizar buracos profundos elevando-os gradualmente
			height = lerp(height, target_depth, depth_factor * 0.8)  # 80% de suavização em buracos profundos
		
		# Área próxima à superfície da água (-5m até +15m): suavização de praia
		elif distance_from_water >= -5.0 and distance_from_water <= beach_zone_top:
			var max_smooth_distance = 12.0  # Expandido para criar praia mais larga
			var smooth_strength = 1.0 - clamp(smooth_distance / max_smooth_distance, 0.0, 1.0)
			smooth_strength = smooth_strength * smooth_strength  # Quadrática
			
			# Criar altura alvo usando ruído de baixa frequência
			var beach_noise = noise.get_noise_2d(x * 0.0006, z * 0.0006)
			
			# Altura alvo: rampa MUITO suave da água para terra (praia plana)
			var target_height: float
			if distance_from_water > 0:
				# Acima da água: criar rampa MUITO suave (20% da altura original = praia quase plana)
				var ramp_factor = 0.2  # Reduzido de 0.5 para 0.2 = rampa muito mais horizontal
				target_height = water_level + (distance_from_water * ramp_factor) + (beach_noise * 1.2)
			else:
				# Abaixo da água: transição suave de fundo para superfície
				# Quanto mais próximo da superfície, mais próximo do nível da água
				var depth_t = abs(distance_from_water) / 5.0  # Normalizar de 0 a 1
				depth_t = depth_t * depth_t  # Curva quadrática
				target_height = lerp(water_level - 1.0, water_level - 3.0, depth_t) + (beach_noise * 1.2)
			
			# Aplicar suavização: quanto mais próximo da água, mais forte
			height = lerp(height, target_height, smooth_strength * 0.7)  # 70% máximo
	
	# ========================================
	# ETAPA 4: Limitar profundidade da água
	# ========================================
	var min_height = water_level - water_depth_limit
	if height < min_height:
		height = min_height
	
	# ========================================
	# ETAPA 5: Suavização final para transição água-terra
	# ========================================
	distance_from_water = height - water_level
	# Zona de transição expandida: de -3m até +10m (praia mais larga e plana)
	if distance_from_water >= -3.0 and distance_from_water <= 10.0:
		var smooth_noise = noise.get_noise_2d(x * 0.0005, z * 0.0005)
		var water_proximity = 1.0 - clamp(abs(distance_from_water) / 10.0, 0.0, 1.0)  # Expandido para 10m
		water_proximity = water_proximity * water_proximity  # Quadrática
		
		# Altura suavizada para transição final (praia muito plana)
		var smooth_height: float
		if distance_from_water > 0:
			# Acima: rampa MUITO suave (25% da altura = praia quase horizontal)
			smooth_height = water_level + (distance_from_water * 0.25) + (smooth_noise * 0.8)
		else:
			# Abaixo: manter próximo à superfície
			smooth_height = water_level - 1.5 + (smooth_noise * 0.8)
		
		height = lerp(height, smooth_height, water_proximity * 0.6)  # 60% para praia mais plana
	
	# ========================================
	# ETAPA 6: Garantir fundo suave (eliminar buracos muito brutos)
	# ========================================
	if height < water_level - 3.0:
		# Se ainda estiver muito abaixo, suavizar mais
		var depth_noise = noise.get_noise_2d(x * 0.0008, z * 0.0008)
		var depth_factor = clamp((water_level - 3.0 - height) / 5.0, 0.0, 1.0)
		var smooth_bottom = water_level - 3.0 + (depth_noise * 1.5)
		height = lerp(height, smooth_bottom, depth_factor * 0.6)
	
	return height

func get_terrain_color(x: float, z: float, height: float) -> Color:
	var moisture = (moisture_noise.get_noise_2d(x, z) + 1.0) / 2.0
	
	# Calcular níveis das camadas
	var w_level = water_level
	var b_level = beach_level
	var g_level = grass_level
	var m_level = mountain_level
	
	# Calcular níveis de rocha e neve
	var rock_start = rock_start_height if enable_rock_layer else 99999.0
	var rock_end = rock_start + rock_thickness if enable_rock_layer else 99999.0
	
	var snow_start = snow_start_height
	if enable_snow_layer and snow_start_height < 0:
		# Auto-calcular: neve começa onde rocha termina
		snow_start = rock_end if enable_rock_layer else rock_start
	elif not enable_snow_layer:
		snow_start = 99999.0  # Desabilitar neve
	
	# Aplicar níveis customizados do tema
	if world_theme and world_theme.use_custom_levels:
		w_level = world_theme.custom_water_level
		b_level = world_theme.custom_beach_level
		g_level = world_theme.custom_grass_level
		m_level = world_theme.custom_mountain_level
	
	# ========================================
	# MODO DEBUG: Mostrar camadas em cores vivas
	# ========================================
	if show_layer_debug:
		if height < w_level - 2.0:
			return Color(0.0, 0.0, 0.5)  # Azul escuro = água profunda
		elif height < w_level:
			return Color(0.0, 0.5, 1.0)  # Azul claro = água rasa
		elif height < b_level:
			return Color(1.0, 1.0, 0.0)  # Amarelo = praia
		elif height < g_level + 3.0:
			return Color(0.5, 1.0, 0.0)  # Verde claro = transição
		elif height < m_level * 0.4:
			return Color(0.0, 1.0, 0.0)  # Verde = grama baixa
		elif height < m_level * 0.7:
			return Color(0.0, 0.7, 0.0)  # Verde escuro = grama alta
		elif height < rock_start:
			return Color(0.7, 0.7, 0.0)  # Amarelo esverdeado = transição rocha
		elif height < rock_end:
			return Color(0.5, 0.5, 0.5)  # Cinza = ROCHA
		elif height < snow_start + snow_transition:
			return Color(0.8, 0.8, 0.8)  # Cinza claro = transição neve
		else:
			return Color(1.0, 1.0, 1.0)  # Branco = NEVE
	
	# ========================================
	# CORES CUSTOMIZADAS (com WorldTheme)
	# ========================================
	if world_theme and world_theme.use_custom_colors:
		# 1. ÁGUA PROFUNDA
		if height < w_level - 2.0:
			return world_theme.deep_water_color
		
		# 2. ÁGUA RASA (transição suave)
		elif height < w_level:
			var t = (height - (w_level - 2.0)) / 2.0
			t = clamp(t, 0.0, 1.0)
			# Curva suave para transição gradual
			t = t * t * (3.0 - 2.0 * t)  # Smoothstep
			return world_theme.deep_water_color.lerp(world_theme.shallow_water_color, t)
		
		# 3. PRAIA/AREIA (zona expandida para praia mais suave)
		# Definir expanded_beach_level antes de usar
		var expanded_beach_level = b_level + 3.0  # Praia vai até 3m acima do beach_level original
		if height < expanded_beach_level:
			var water_to_sand_t = (height - w_level) / (expanded_beach_level - w_level)
			water_to_sand_t = clamp(water_to_sand_t, 0.0, 1.0)
			# Curva suave (ease-in-out)
			water_to_sand_t = water_to_sand_t * water_to_sand_t * (3.0 - 2.0 * water_to_sand_t)
			
			# Primeiro: água rasa → areia molhada (primeiros 30%)
			if water_to_sand_t < 0.3:
				var t = water_to_sand_t / 0.3
				t = t * t  # Curva quadrática para suavidade
				return world_theme.shallow_water_color.lerp(world_theme.beach_color.darkened(0.2), t)
			# Depois: areia molhada → areia seca (restante 70%)
			else:
				var t = (water_to_sand_t - 0.3) / 0.7
				t = t * t * (3.0 - 2.0 * t)  # Smoothstep
				var wet_beach = world_theme.beach_color.darkened(0.2)
				return wet_beach.lerp(world_theme.beach_color, t)
		
		# 4. TRANSIÇÃO PRAIA → GRAMA (mais suave e gradual)
		elif height < g_level + 5.0:  # Expandir zona de transição
			var t = (height - expanded_beach_level) / ((g_level + 5.0) - expanded_beach_level)
			t = clamp(t, 0.0, 1.0)
			# Curva muito suave (ease-in-out cúbica)
			t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
			return world_theme.beach_color.lerp(world_theme.grass_low_color, t)
		
		# 5. GRAMA BAIXA/PLANÍCIE
		elif height < m_level * 0.5:
			return world_theme.grass_low_color.lerp(world_theme.grass_high_color, moisture * 0.3)
		
		# 6. GRAMA ALTA/FLORESTA
		elif height < m_level * 0.8:
			var t = (height - m_level * 0.5) / (m_level * 0.3)
			t = clamp(t, 0.0, 1.0)
			return world_theme.grass_low_color.lerp(world_theme.grass_high_color, t)
		
		# 7. TRANSIÇÃO GRAMA → ROCHA
		elif height < rock_start:
			var distance_to_rock = rock_start - (m_level * 0.8)
			if distance_to_rock > 0:
				var t = (height - m_level * 0.8) / distance_to_rock
				t = clamp(t, 0.0, 1.0)
				t = t * t
				return world_theme.grass_high_color.lerp(world_theme.rock_color, t)
			else:
				return world_theme.grass_high_color
		
		# 8. ROCHA
		elif height < rock_end:
			return world_theme.rock_color
		
		# 9. TRANSIÇÃO ROCHA → NEVE
		elif height < snow_start + snow_transition:
			var t = (height - rock_end) / snow_transition
			t = clamp(t, 0.0, 1.0)
			t = t * t
			return world_theme.rock_color.lerp(world_theme.snow_color, t)
		
		# 10. NEVE
		else:
			return world_theme.snow_color
	
	# ========================================
	# CORES PADRÃO (sem tema)
	# ========================================
	
	# Água profunda
	if height < w_level - 2.0:
		return Color(0.08, 0.15, 0.35)
	
	# Água rasa (transição suave de água profunda para rasa)
	elif height < w_level:
		var t = (height - (w_level - 2.0)) / 2.0
		t = clamp(t, 0.0, 1.0)
		# Curva suave para transição gradual
		t = t * t * (3.0 - 2.0 * t)  # Smoothstep
		return Color(0.08, 0.15, 0.35).lerp(Color(0.15, 0.3, 0.5), t)
	
	# Praia/Areia (zona expandida para praia mais suave)
	# Expandir a zona de praia para criar transição mais gradual
	var expanded_beach_level = b_level + 3.0  # Praia vai até 3m acima do beach_level original
	if height < expanded_beach_level:
		# Transição água → areia molhada → areia seca
		var water_to_sand_t = (height - w_level) / (expanded_beach_level - w_level)
		water_to_sand_t = clamp(water_to_sand_t, 0.0, 1.0)
		# Curva suave (ease-in-out)
		water_to_sand_t = water_to_sand_t * water_to_sand_t * (3.0 - 2.0 * water_to_sand_t)
		
		# Cor da água rasa (mais clara perto da superfície)
		var shallow_water = Color(0.15, 0.3, 0.5)
		# Areia molhada (escura)
		var wet_sand = Color(0.6, 0.55, 0.45)
		# Areia seca (clara)
		var dry_sand = Color(0.85, 0.8, 0.65)
		
		# Primeiro: água → areia molhada (primeiros 30%)
		if water_to_sand_t < 0.3:
			var t = water_to_sand_t / 0.3
			t = t * t  # Curva quadrática para suavidade
			return shallow_water.lerp(wet_sand, t)
		# Depois: areia molhada → areia seca (restante 70%)
		else:
			var t = (water_to_sand_t - 0.3) / 0.7
			t = t * t * (3.0 - 2.0 * t)  # Smoothstep
			return wet_sand.lerp(dry_sand, t)
	
	# Transição praia → grama (mais suave e gradual)
	elif height < g_level + 5.0:  # Expandir zona de transição
		var t = (height - expanded_beach_level) / ((g_level + 5.0) - expanded_beach_level)
		t = clamp(t, 0.0, 1.0)
		# Curva muito suave (ease-in-out cúbica)
		t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
		var sand = Color(0.85, 0.8, 0.65)
		var grass = Color(0.4, 0.65, 0.35).lerp(Color(0.35, 0.6, 0.3), moisture)
		return sand.lerp(grass, t)
	
	# Grama baixa
	elif height < m_level * 0.4:
		var grass_light = Color(0.35, 0.6, 0.3)
		var grass_dark = Color(0.28, 0.5, 0.25)
		return grass_light.lerp(grass_dark, moisture * 0.5)
	
	# Grama média
	elif height < m_level * 0.7:
		var t = (height - m_level * 0.4) / (m_level * 0.3)
		t = clamp(t, 0.0, 1.0)
		var grass = Color(0.28, 0.5, 0.25)
		var grass_hill = Color(0.3, 0.48, 0.25)
		return grass.lerp(grass_hill, t)
	
	# Transição grama → rocha
	elif height < rock_start:
		var distance_to_rock = rock_start - (m_level * 0.7)
		if distance_to_rock > 0:
			var t = (height - m_level * 0.7) / distance_to_rock
			t = clamp(t, 0.0, 1.0)
			t = t * t
			var grass = Color(0.3, 0.48, 0.25)
			var rock_transition = Color(0.35, 0.4, 0.3)
			return grass.lerp(rock_transition, t)
		else:
			return Color(0.3, 0.48, 0.25)
	
	# ROCHA (camada pura)
	elif height < rock_end:
		return Color(0.5, 0.5, 0.5)
	
	# Transição rocha → neve
	elif height < snow_start + snow_transition:
		var t = (height - rock_end) / snow_transition
		t = clamp(t, 0.0, 1.0)
		t = t * t
		var rock = Color(0.5, 0.5, 0.5)
		var snow = Color(0.92, 0.92, 0.95)
		return rock.lerp(snow, t)
	
	# NEVE
	else:
		return Color(0.92, 0.92, 0.95)

func get_biome_at_position(x: float, z: float, height: float) -> BiomeData:
	var moisture = (moisture_noise.get_noise_2d(x, z) + 1.0) / 2.0
	var temperature = (temperature_noise.get_noise_2d(x, z) + 1.0) / 2.0
	var biome_value = (biome_noise.get_noise_2d(x, z) + 1.0) / 2.0
	
	# Calcular tier baseado na distância do spawn
	var distance_from_spawn = Vector2(x, z).length()
	var current_tier = calculate_difficulty_tier(distance_from_spawn)
	
	var best_biome: BiomeData = null
	var best_score = -999999.0
	
	for biome in biomes:
		if not biome:
			continue
		
		# Verificar altura
		if height < biome.min_height or height > biome.max_height:
			continue
		
		# FILTRO DE TIER: Só permite biomas do tier atual ou menor
		if biome.difficulty_tier > current_tier:
			continue
		
		# Aplicar raridade do bioma
		if randf() > biome.biome_rarity:
			continue
		
		# Calcular score baseado em umidade, temperatura e biome noise
		var moisture_diff = abs(moisture - biome.preferred_moisture)
		var temp_diff = abs(temperature - biome.preferred_temperature)
		var biome_diff = abs(biome_value - biome.biome_noise_value)
		
		var score = -(moisture_diff + temp_diff + biome_diff)
		
		# Bonus para biomas de tier mais alto (incentiva progressão)
		score += biome.difficulty_tier * 0.1
		
		if score > best_score:
			best_score = score
			best_biome = biome
	
	return best_biome

# ========================================
# SISTEMA DE POIS DINÂMICO POR DIFICULDADE
# ========================================

func check_and_spawn_pois():
	# Chance de NÃO spawnar nada
	if randf() > poi_per_area_chance:
		return
	
	var player_pos = player.global_position
	var distance_from_spawn = Vector2(player_pos.x, player_pos.z).length()
	
	# Calcular difficulty tier baseado na distância
	var current_tier = calculate_difficulty_tier(distance_from_spawn)
	
	# Filtrar POIs globais válidos para o tier atual
	var valid_pois = []
	for poi_data in pois:
		if not poi_data or not poi_data.scene:
			continue
		
		# POI deve estar no tier atual ou menor
		if poi_data.difficulty_tier <= current_tier and poi_data.difficulty_tier > 0:
			valid_pois.append(poi_data)
	
	# Tentar spawnar em local válido
	for attempt in range(8):
		var angle = randf() * TAU
		var distance = randf_range(80.0, 250.0)
		
		var pos_x = player_pos.x + cos(angle) * distance
		var pos_z = player_pos.z + sin(angle) * distance
		
		# Verificar espaçamento com POIs existentes
		if not check_poi_spacing(Vector2(pos_x, pos_z)):
			continue
		
		var height = get_terrain_height(pos_x, pos_z)
		
		# Verificar bioma nesta posição
		var biome = get_biome_at_position(pos_x, pos_z, height)
		
		# Adicionar POIs específicos do bioma à lista
		if biome and not biome.biome_pois.is_empty():
			for biome_poi in biome.biome_pois:
				if biome_poi and biome_poi.scene:
					# POIs do bioma também respeitam tier
					if biome_poi.difficulty_tier <= current_tier:
						valid_pois.append(biome_poi)
		
		if valid_pois.is_empty():
			continue
		
		# Escolher POI aleatório (pode ser global ou específico do bioma)
		var poi_data: POIData = valid_pois[randi() % valid_pois.size()]
		
		# Verificar altura
		if height < poi_data.min_height or height > poi_data.max_height:
			continue
		
		# Spawnar POI!
		var position = Vector3(pos_x, height + poi_data.height_offset, pos_z)
		var poi = poi_data.scene.instantiate()
		poi.position = position
		poi.rotation.y = randf_range(0, TAU)
		add_child(poi)
		
		# Registrar posição
		var grid_key = Vector2i(int(pos_x / poi_min_spacing), int(pos_z / poi_min_spacing))
		spawned_pois[grid_key] = poi
		
		var tier_name = get_tier_name(current_tier)
		var biome_name = biome.biome_name if biome else "Desconhecido"
		print("📍 POI '", poi_data.poi_name, "' [", tier_name, "] spawned em ", biome_name, " (", int(distance_from_spawn), "m)")
		break

func calculate_difficulty_tier(distance: float) -> int:
	# Sistema de tiers baseado na distância do spawn
	# Tier 1: 0-500m (Iniciante)
	# Tier 2: 500-1500m (Intermediário)
	# Tier 3: 1500-3000m (Avançado)
	# Tier 4: 3000-5000m (Difícil)
	# Tier 5: 5000+m (Extremo)
	
	if distance < 500:
		return 1
	elif distance < 1500:
		return 2
	elif distance < 3000:
		return 3
	elif distance < 5000:
		return 4
	else:
		return 5

func get_tier_name(tier: int) -> String:
	match tier:
		1: return "Tier 1 - Iniciante"
		2: return "Tier 2 - Intermediário"
		3: return "Tier 3 - Avançado"
		4: return "Tier 4 - Difícil"
		5: return "Tier 5 - Extremo"
		_: return "Tier " + str(tier)

func check_poi_spacing(pos: Vector2) -> bool:
	# Verifica se há POIs muito próximos
	for poi_key in spawned_pois.keys():
		var poi_pos = Vector2(poi_key.x * poi_min_spacing, poi_key.y * poi_min_spacing)
		if pos.distance_to(poi_pos) < poi_min_spacing:
			return false
	return true

# ========================================
# SISTEMA DE SPAWNERS DINÂMICO POR DIFICULDADE
# ========================================

func check_and_spawn_spawners():
	# Chance de NÃO spawnar nada
	if randf() > spawner_per_area_chance:
		return
	
	var player_pos = player.global_position
	var distance_from_spawn = Vector2(player_pos.x, player_pos.z).length()
	
	# Calcular difficulty tier
	var current_tier = calculate_difficulty_tier(distance_from_spawn)
	
	# Filtrar spawners globais válidos para o tier atual
	var valid_spawners = []
	for spawner_data in animal_spawners:
		if not spawner_data or not spawner_data.spawner_scene:
			continue
		
		# Spawner deve estar no tier atual ou menor
		if spawner_data.difficulty_tier <= current_tier and spawner_data.difficulty_tier > 0:
			valid_spawners.append(spawner_data)
	
	# Tentar spawnar em local válido
	for attempt in range(6):
		var angle = randf() * TAU
		var distance = randf_range(50.0, 180.0)
		
		var pos_x = player_pos.x + cos(angle) * distance
		var pos_z = player_pos.z + sin(angle) * distance
		
		# Verificar espaçamento
		if not check_spawner_spacing(Vector2(pos_x, pos_z)):
			continue
		
		var height = get_terrain_height(pos_x, pos_z)
		
		# Verificar bioma
		var biome = get_biome_at_position(pos_x, pos_z, height)
		
		if not biome:
			continue
		
		# Adicionar spawners específicos do bioma à lista
		if not biome.biome_spawners.is_empty():
			for biome_spawner in biome.biome_spawners:
				if biome_spawner and biome_spawner.spawner_scene:
					# Spawners do bioma também respeitam tier
					if biome_spawner.difficulty_tier <= current_tier:
						valid_spawners.append(biome_spawner)
		
		if valid_spawners.is_empty():
			continue
		
		# Escolher spawner aleatório (pode ser global ou específico do bioma)
		var spawner_data: AnimalSpawnerData = valid_spawners[randi() % valid_spawners.size()]
		
		# Verificar altura
		if height < spawner_data.min_height or height > spawner_data.max_height:
			continue
		
		# Verificar bioma se o spawner tem restrição (spawners globais)
		if not spawner_data.allowed_biomes.is_empty():
			var valid_biome = false
			for allowed in spawner_data.allowed_biomes:
				if allowed == biome.biome_name:
					valid_biome = true
					break
			
			if not valid_biome:
				continue
		
		# Spawnar spawner!
		var position = Vector3(pos_x, height+5, pos_z)
		var spawner = spawner_data.spawner_scene.instantiate()
		spawner.position = position
		add_child(spawner)
		
		# Registrar posição
		var grid_key = Vector2i(int(pos_x / spawner_min_spacing), int(pos_z / spawner_min_spacing))
		spawned_spawners[grid_key] = spawner
		
		var tier_name = get_tier_name(current_tier)
		print("🐾 Spawner '", spawner_data.spawner_name, "' [", tier_name, "] em ", biome.biome_name, " (", int(distance_from_spawn), "m)")
		break

func check_spawner_spacing(pos: Vector2) -> bool:
	# Verifica se há spawners muito próximos
	for spawner_key in spawned_spawners.keys():
		var spawner_pos = Vector2(spawner_key.x * spawner_min_spacing, spawner_key.y * spawner_min_spacing)
		if pos.distance_to(spawner_pos) < spawner_min_spacing:
			return false
	return true
