extends Node3D
class_name WorldGenerator2

# ============================================================================
# SISTEMA DE GERAÇÃO PROCEDURAL DE MUNDO - GODOT 4.6
# Terreno com Montanhas, Planícies e Relevos Acentuados
# ============================================================================

# Cenas de Objetos Principais
@export var tree_scene: PackedScene
@export var rock_scene: PackedScene
@export var chest_scene: PackedScene

# Configurações do Mapa
@export var map_size: int = 500
@export var spawn_spacing: float = 5.0
@export var world_seed: int = 0

# ============================================================================
# CENAS DE DECORAÇÃO PEQUENA
# ============================================================================
@export_group("Decoração Pequena")
@export_range(0.0, 1.0) var small_rocks_density: float = 0.25
@export_range(0.0, 1.0) var grass_density: float = 0.6
@export_range(0.0, 1.0) var bush_density: float = 0.2
@export_range(0.0, 1.0) var log_density: float = 0.1
@export_range(0.0, 1.0) var flower_density: float = 0.15

@export var small_rocks_scenes: Array[PackedScene] = []
@export var grass_scenes: Array[PackedScene] = []
@export var bush_scenes: Array[PackedScene] = []
@export var log_scenes: Array[PackedScene] = []
@export var flower_scenes: Array[PackedScene] = []

# ============================================================================
# DENSIDADE DE VEGETAÇÃO
# ============================================================================
@export_group("Densidade de Vegetação")
@export_range(0.0, 1.0) var tree_forest_density: float = 0.75
@export_range(0.0, 1.0) var tree_medium_density: float = 0.45
@export_range(0.0, 1.0) var tree_sparse_density: float = 0.12
@export_range(0.0, 1.0) var rock_cluster_density: float = 0.35
@export_range(0.0, 1.0) var rock_sparse_density: float = 0.1

# ============================================================================
# CONFIGURAÇÕES DE TERRENO - RELEVOS REALISTAS
# ============================================================================
@export_group("Configurações de Terreno")
@export var terrain_height: float = 25.0           # Altura máxima aumentada
@export var mountain_height: float = 45.0          # Altura extra para montanhas
@export var valley_depth: float = -8.0             # Profundidade dos vales
@export var chunk_size: float = 20.0
@export var terrain_roughness: float = 0.5         # Rugosidade do terreno

# ============================================================================
# NÍVEIS DE BIOMAS
# ============================================================================
@export_group("Níveis de Biomas")
@export var water_level: float = -4.0
@export var sand_level: float = -1.5
@export var grass_level: float = 8.0
@export var forest_level: float = 18.0
@export var mountain_level: float = 28.0
@export var snow_level: float = 38.0

# ============================================================================
# CONFIGURAÇÕES DE BAÚS
# ============================================================================
@export_group("Baús")
@export var enable_chests: bool = true
@export_range(0.0, 1.0) var chest_spawn_chance: float = 0.03
@export var chest_min_distance: float = 40.0
@export var skill_manager_path: NodePath

# ============================================================================
# SISTEMA DE RIOS
# ============================================================================
@export_group("Rios")
@export var enable_rivers: bool = true
@export var river_width: float = 8.0
@export var river_depth: float = -6.0
@export_range(0.0, 1.0) var river_frequency: float = 0.015

# ============================================================================
# VARIÁVEIS INTERNAS
# ============================================================================

# Sistema de ruído multi-camada
var noise_base: FastNoiseLite          # Terreno base
var noise_detail: FastNoiseLite        # Detalhes finos
var noise_mountain: FastNoiseLite      # Formação de montanhas
var noise_valley: FastNoiseLite        # Vales e depressões
var cluster_noise: FastNoiseLite       # Distribuição de vegetação
var moisture_noise: FastNoiseLite      # Umidade para biomas
var river_noise: FastNoiseLite         # Sistema de rios
var temperature_noise: FastNoiseLite   # Temperatura para biomas

var chest_positions: Array[Vector3] = []
var river_points: Array[Vector3] = []

const SPAWN_SAFE_RADIUS: float = 25.0

# ============================================================================
# INICIALIZAÇÃO
# ============================================================================

func _ready():
	generate_world()

func generate_world():
	if world_seed == 0:
		world_seed = randi()
	
	print("🌍 ============================================")
	print("🌍  GERANDO MUNDO PROCEDURAL MASSIVO")
	print("🌍  Seed: ", world_seed)
	print("🌍  Tamanho: ", map_size * 2, "x", map_size * 2)
	print("🌍 ============================================")
	print("⏳ Iniciando geração...")
	
	seed(world_seed)
	
	setup_noise_system()
	create_water_plane()
	
	if enable_rivers:
		await generate_river_system_async()
	
	await create_chunked_terrain_async()
	await spawn_vegetation_async()
	
	print("✅ ============================================")
	print("✅ MUNDO GERADO COM SUCESSO!")
	print("✅ ============================================")

# ============================================================================
# SISTEMA DE RUÍDO AVANÇADO
# ============================================================================

func setup_noise_system():
	# Ruído base - forma geral do terreno
	noise_base = FastNoiseLite.new()
	noise_base.seed = world_seed
	noise_base.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_base.frequency = 0.003
	noise_base.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_base.fractal_octaves = 4
	noise_base.fractal_lacunarity = 2.2
	noise_base.fractal_gain = 0.5
	
	# Ruído de detalhes - rugosidade local
	noise_detail = FastNoiseLite.new()
	noise_detail.seed = world_seed + 500
	noise_detail.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_detail.frequency = 0.02
	noise_detail.fractal_octaves = 2
	noise_detail.fractal_gain = 0.3
	
	# Ruído de montanhas - picos acentuados
	noise_mountain = FastNoiseLite.new()
	noise_mountain.seed = world_seed + 1000
	noise_mountain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_mountain.frequency = 0.008
	noise_mountain.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise_mountain.fractal_octaves = 5
	noise_mountain.fractal_lacunarity = 2.5
	noise_mountain.fractal_gain = 0.55
	
	# Ruído de vales - depressões naturais
	noise_valley = FastNoiseLite.new()
	noise_valley.seed = world_seed + 1500
	noise_valley.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_valley.frequency = 0.006
	noise_valley.fractal_octaves = 3
	noise_valley.fractal_gain = 0.4
	
	# Ruído de clusters para vegetação
	cluster_noise = FastNoiseLite.new()
	cluster_noise.seed = world_seed + 2000
	cluster_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	cluster_noise.frequency = 0.018
	cluster_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	cluster_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	
	# Ruído de umidade
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = world_seed + 2500
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = 0.004
	moisture_noise.fractal_octaves = 3
	
	# Ruído de temperatura
	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = world_seed + 3000
	temperature_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	temperature_noise.frequency = 0.003
	temperature_noise.fractal_octaves = 2
	
	# Ruído de rios
	river_noise = FastNoiseLite.new()
	river_noise.seed = world_seed + 3500
	river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	river_noise.frequency = river_frequency
	river_noise.fractal_octaves = 2

# ============================================================================
# CÁLCULO DE ALTURA DO TERRENO
# ============================================================================

func get_terrain_height(x: float, z: float) -> float:
	var base_value = noise_base.get_noise_2d(x, z)
	var detail_value = noise_detail.get_noise_2d(x, z)
	var mountain_value = noise_mountain.get_noise_2d(x, z)
	var valley_value = noise_valley.get_noise_2d(x, z)
	
	# Suavização para rios
	var river_influence = 0.0
	if enable_rivers:
		river_influence = get_river_influence(x, z)
	
	# Composição multi-camada do terreno
	# Base: terreno geral suave
	var height = base_value * terrain_height * 0.6
	
	# Detalhes: rugosidade local
	height += detail_value * terrain_height * 0.15 * terrain_roughness
	
	# Montanhas: picos acentuados (apenas onde o valor é alto)
	var mountain_mask = smoothstep(0.2, 0.8, mountain_value)
	height += mountain_value * mountain_height * mountain_mask * 0.8
	
	# Vales: depressões naturais
	var valley_mask = smoothstep(-0.3, 0.3, valley_value)
	height += valley_value * abs(valley_depth) * (1.0 - valley_mask) * 0.5
	
	# Aplicar influência dos rios (criar leitos)
	if river_influence > 0:
		height = lerp(height, river_depth, river_influence * 0.7)
	
	return height

func get_river_influence(x: float, z: float) -> float:
	var river_val = abs(river_noise.get_noise_2d(x, z))
	# Criar corredores de rio
	var river_mask = 1.0 - smoothstep(0.0, river_width * 0.001, river_val)
	return river_mask

# ============================================================================
# SISTEMA DE RIOS
# ============================================================================

func generate_river_system_async():
	print("🌊 Gerando sistema de rios...")
	
	var river_count = int(map_size / 150.0)
	var generated_rivers = 0
	
	for i in range(river_count):
		var start_x = randf_range(-map_size * 0.8, map_size * 0.8)
		var start_z = randf_range(-map_size * 0.8, map_size * 0.8)
		
		# Encontrar caminho do rio descendo a elevação
		var current_pos = Vector3(start_x, get_terrain_height(start_x, start_z), start_z)
		var path_points: Array[Vector3] = []
		var max_steps = 200
		var step = 0
		
		while step < max_steps:
			path_points.append(current_pos)
			
			# Encontrar direção de descida
			var best_dir = Vector2.ZERO
			var best_height = current_pos.y
			
			for dx in [-5, 0, 5]:
				for dz in [-5, 0, 5]:
					if dx == 0 and dz == 0:
						continue
					var check_x = current_pos.x + dx
					var check_z = current_pos.z + dz
					var h = get_terrain_height(check_x, check_z)
					if h < best_height:
						best_height = h
						best_dir = Vector2(dx, dz)
						
			if best_dir == Vector2.ZERO:
				break
				
			current_pos.x += best_dir.x
			current_pos.z += best_dir.y
			current_pos.y = best_height
			
			if current_pos.y < water_level:
				break
				
			step += 1
		
		# Criar mesh do rio
		if path_points.size() > 10:
			create_river_mesh(path_points)
			generated_rivers += 1
		
		if i % 2 == 0:
			await get_tree().process_frame
	
	print("🌊 ", generated_rivers, " rios gerados")

func create_river_mesh(points: Array[Vector3]):
	if points.size() < 2:
		return
		
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_width = river_width * 0.5
	
	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i + 1]
		
		var direction = Vector2(p2.x - p1.x, p2.z - p1.z).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)
		
		# Criar segmento do rio
		var v1 = p1 + Vector3(perpendicular.x * half_width, 0, perpendicular.y * half_width)
		var v2 = p1 - Vector3(perpendicular.x * half_width, 0, perpendicular.y * half_width)
		var v3 = p2 + Vector3(perpendicular.x * half_width, 0, perpendicular.y * half_width)
		var v4 = p2 - Vector3(perpendicular.x * half_width, 0, perpendicular.y * half_width)
		
		v1.y = river_depth
		v2.y = river_depth
		v3.y = river_depth
		v4.y = river_depth
		
		# Triângulos
		surface_tool.set_color(Color(0.15, 0.35, 0.55, 0.85))
		surface_tool.add_vertex(v1)
		surface_tool.add_vertex(v2)
		surface_tool.add_vertex(v3)
		
		surface_tool.add_vertex(v2)
		surface_tool.add_vertex(v4)
		surface_tool.add_vertex(v3)
	
	surface_tool.generate_normals()
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = surface_tool.commit()
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.35, 0.55, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.2
	material.roughness = 0.05
	material.rim_enabled = true
	material.rim = 0.4
	mesh_instance.material_override = material
	
	add_child(mesh_instance)

# ============================================================================
# ÁGUA
# ============================================================================

func create_water_plane():
	var water_mesh = MeshInstance3D.new()
	water_mesh.name = "WaterPlane"
	
	var plane = PlaneMesh.new()
	plane.size = Vector2(map_size * 2.5, map_size * 2.5)
	plane.subdivide_depth = 50
	plane.subdivide_width = 50
	water_mesh.mesh = plane
	water_mesh.position.y = water_level
	
	# Material de água melhorado
	var water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.08, 0.25, 0.5, 0.75)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.metallic = 0.15
	water_material.roughness = 0.08
	water_material.rim_enabled = true
	water_material.rim = 0.35
	water_material.rim_tint = 0.6
	water_material.clearcoat_enabled = true
	water_material.clearcoat = 0.3
	water_mesh.material_override = water_material
	
	add_child(water_mesh)
	
	# Corpo de colisão da água
	var water_body = StaticBody3D.new()
	water_body.name = "WaterBody"
	var water_collision = CollisionShape3D.new()
	var water_shape = BoxShape3D.new()
	water_shape.size = Vector3(map_size * 2.5, 1.0, map_size * 2.5)
	water_collision.shape = water_shape
	water_collision.position.y = water_level - 0.5
	water_body.add_child(water_collision)
	add_child(water_body)

# ============================================================================
# GERAÇÃO DE TERRENO EM CHUNKS
# ============================================================================

func create_chunked_terrain_async():
	var chunks_x = int((map_size * 2) / chunk_size)
	var chunks_z = int((map_size * 2) / chunk_size)
	
	var total_chunks = chunks_x * chunks_z
	var current_chunk = 0
	
	print("📦 Gerando ", total_chunks, " chunks de terreno...")
	
	for cx in range(chunks_x):
		for cz in range(chunks_z):
			var chunk_x = -map_size + (cx * chunk_size)
			var chunk_z = -map_size + (cz * chunk_size)
			create_terrain_chunk(chunk_x, chunk_z)
			
			current_chunk += 1
			
			if current_chunk % 15 == 0:
				print("  Progresso: ", current_chunk, "/", total_chunks, " chunks (", 
					int(float(current_chunk) / total_chunks * 100), "%)")
				await get_tree().process_frame

func create_terrain_chunk(start_x: float, start_z: float):
	var mesh_instance = MeshInstance3D.new()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var subdivisions = 12
	var step = chunk_size / subdivisions
	
	var vertices = []
	var colors = []
	var uvs = []
	
	for z in range(subdivisions + 1):
		for x in range(subdivisions + 1):
			var pos_x = start_x + (x * step)
			var pos_z = start_z + (z * step)
			var height = get_terrain_height(pos_x, pos_z)
			
			vertices.append(Vector3(pos_x, height, pos_z))
			colors.append(get_terrain_color(pos_x, pos_z, height))
			uvs.append(Vector2(float(x) / subdivisions, float(z) / subdivisions))
	
	for z in range(subdivisions):
		for x in range(subdivisions):
			var i = z * (subdivisions + 1) + x
			
			# Triângulo 1
			surface_tool.set_color(colors[i])
			surface_tool.set_uv(uvs[i])
			surface_tool.add_vertex(vertices[i])
			
			surface_tool.set_color(colors[i + 1])
			surface_tool.set_uv(uvs[i + 1])
			surface_tool.add_vertex(vertices[i + 1])
			
			surface_tool.set_color(colors[i + subdivisions + 1])
			surface_tool.set_uv(uvs[i + subdivisions + 1])
			surface_tool.add_vertex(vertices[i + subdivisions + 1])
			
			# Triângulo 2
			surface_tool.set_color(colors[i + 1])
			surface_tool.set_uv(uvs[i + 1])
			surface_tool.add_vertex(vertices[i + 1])
			
			surface_tool.set_color(colors[i + subdivisions + 2])
			surface_tool.set_uv(uvs[i + subdivisions + 2])
			surface_tool.add_vertex(vertices[i + subdivisions + 2])
			
			surface_tool.set_color(colors[i + subdivisions + 1])
			surface_tool.set_uv(uvs[i + subdivisions + 1])
			surface_tool.add_vertex(vertices[i + subdivisions + 1])
	
	surface_tool.generate_normals()
	mesh_instance.mesh = surface_tool.commit()
	
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	material.specular = 0.1
	mesh_instance.material_override = material
	
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	
	# Colisão
	var static_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	collision.shape = mesh_instance.mesh.create_trimesh_shape()
	static_body.add_child(collision)
	add_child(static_body)

# ============================================================================
# CORES DO TERRENO POR BIOMA
# ============================================================================

func get_terrain_color(x: float, z: float, height: float) -> Color:
	var moisture = moisture_noise.get_noise_2d(x, z)
	var temperature = temperature_noise.get_noise_2d(x, z)
	var river_influence = get_river_influence(x, z) if enable_rivers else 0.0
	
	# Água profunda
	if height < water_level - 2:
		return Color(0.08, 0.18, 0.35)
	
	# Água rasa
	if height < water_level:
		return Color(0.1, 0.25, 0.45)
	
	# Solo de rio (úmido)
	if river_influence > 0.3:
		return Color(0.35, 0.4, 0.25).lerp(Color(0.5, 0.55, 0.35), river_influence)
	
	# Areia
	if height < sand_level:
		var blend = smoothstep(water_level, sand_level, height)
		var wet_sand = Color(0.65, 0.6, 0.45)
		var dry_sand = Color(0.9, 0.85, 0.65)
		return wet_sand.lerp(dry_sand, blend)
	
	# Grama baixa
	if height < grass_level:
		var blend = smoothstep(sand_level, grass_level, height)
		var sand_color = Color(0.85, 0.8, 0.6)
		var light_grass = Color(0.45, 0.75, 0.35)
		var dark_grass = Color(0.25, 0.55, 0.2)
		var grass_color = light_grass.lerp(dark_grass, moisture * 0.5 + 0.5)
		return sand_color.lerp(grass_color, blend)
	
	# Floresta
	if height < forest_level:
		var blend = smoothstep(grass_level, forest_level, height)
		var forest_light = Color(0.2, 0.5, 0.18)
		var forest_dark = Color(0.12, 0.38, 0.12)
		return forest_light.lerp(forest_dark, blend * (moisture * 0.3 + 0.7))
	
	# Montanha
	if height < mountain_level:
		var blend = smoothstep(forest_level, mountain_level, height)
		var mountain_grass = Color(0.15, 0.35, 0.15)
		var mountain_rock = Color(0.45, 0.42, 0.38)
		return mountain_grass.lerp(mountain_rock, blend)
	
	# Neve
	if height < snow_level:
		var blend = smoothstep(mountain_level, snow_level, height)
		var rock = Color(0.5, 0.48, 0.45)
		var snow = Color(0.95, 0.95, 0.98)
		return rock.lerp(snow, blend)
	
	# Pico nevado
	return Color(0.98, 0.98, 1.0)

# ============================================================================
# VEGETAÇÃO
# ============================================================================

func spawn_vegetation_async():
	var spawned_trees = 0
	var spawned_rocks = 0
	var spawned_chests = 0
	var spawned_details = 0
	var total_checked = 0

	print("🌲 Gerando vegetação e detalhes...")

	var x = -map_size
	while x < map_size:
		var z = -map_size
		while z < map_size:
			var random_offset_x = randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			var random_offset_z = randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			
			var pos_x = x + random_offset_x
			var pos_z = z + random_offset_z
			
			# Área segura do spawn do jogador
			if Vector2(pos_x, pos_z).length() < SPAWN_SAFE_RADIUS:
				z += spawn_spacing
				continue
			
			var height = get_terrain_height(pos_x, pos_z)
			
			# Não spawna na água ou em rios
			if height < water_level + 0.5:
				z += spawn_spacing
				continue
			
			var position = Vector3(pos_x, height, pos_z)
			var cluster_value = cluster_noise.get_noise_2d(pos_x, pos_z)
			var moisture = moisture_noise.get_noise_2d(pos_x, pos_z)
			var random_value = randf()
			
			# === SISTEMA DE BAÚS (PRIORIDADE) ===
			if enable_chests and chest_scene and randf() < chest_spawn_chance:
				if can_spawn_chest_here(position):
					spawn_chest(position)
					spawned_chests += 1
					chest_positions.append(position)
					z += spawn_spacing
					continue
			
			# === SISTEMA DE ÁRVORES POR BIOM ===
			if height >= sand_level and height < mountain_level:
				if cluster_value > 0.25:
					# Floresta densa
					if random_value < tree_forest_density and tree_scene:
						spawn_object(tree_scene, position, 0.9, 1.3)
						spawned_trees += 1
				elif cluster_value > -0.1:
					# Floresta média
					if random_value < tree_medium_density and tree_scene:
						spawn_object(tree_scene, position, 0.8, 1.2)
						spawned_trees += 1
				elif cluster_value > -0.3:
					# Árvores esparsas
					if random_value < tree_sparse_density and tree_scene:
						spawn_object(tree_scene, position, 0.7, 1.1)
						spawned_trees += 1
			
			# === SISTEMA DE PEDRAS ===
			if height >= grass_level:
				if cluster_value < -0.35:
					if random_value < rock_cluster_density and rock_scene:
						spawn_object(rock_scene, position, 1.0, 1.8)
						spawned_rocks += 1
				elif cluster_value < -0.15:
					if random_value < rock_sparse_density and rock_scene:
						spawn_object(rock_scene, position, 0.8, 1.4)
						spawned_rocks += 1
			
			# === DETALHES PEQUENOS ===
			if height > sand_level and height < forest_level:
				spawned_details += spawn_small_details(position, cluster_value, moisture)
			
			total_checked += 1
			
			if total_checked % 150 == 0:
				await get_tree().process_frame
			
			z += spawn_spacing
		x += spawn_spacing
	
	print("✅ ============================================")
	print("✅ 🌲 Árvores: ", spawned_trees)
	print("✅ 🪨 Pedras: ", spawned_rocks)
	print("✅ 📦 Baús: ", spawned_chests)
	print("✅ 🌿 Detalhes: ", spawned_details)
	print("✅ ============================================")

func spawn_small_details(position: Vector3, cluster_value: float, moisture: float) -> int:
	var count = 0
	
	# Grama
	if grass_scenes.size() > 0 and randf() < grass_density:
		var grass_pos = position + Vector3(randf_range(-0.8, 0.8), 0.05, randf_range(-0.8, 0.8))
		grass_pos.y = get_terrain_height(grass_pos.x, grass_pos.z) + 0.05
		spawn_random_from_array(grass_scenes, grass_pos, 0.7, 1.3)
		count += 1
	
	# Pedrinhas
	if small_rocks_scenes.size() > 0 and randf() < small_rocks_density:
		var rock_pos = position + Vector3(randf_range(-1.0, 1.0), 0.03, randf_range(-1.0, 1.0))
		rock_pos.y = get_terrain_height(rock_pos.x, rock_pos.z) + 0.03
		spawn_random_from_array(small_rocks_scenes, rock_pos, 0.5, 1.0)
		count += 1
	
	# Moitas (mais em florestas)
	if bush_scenes.size() > 0 and cluster_value > 0.0 and randf() < bush_density:
		var bush_pos = position + Vector3(randf_range(-0.5, 0.5), 0.05, randf_range(-0.5, 0.5))
		bush_pos.y = get_terrain_height(bush_pos.x, bush_pos.z) + 0.05
		spawn_random_from_array(bush_scenes, bush_pos, 0.8, 1.4)
		count += 1
	
	# Troncos
	if log_scenes.size() > 0 and randf() < log_density:
		var log_pos = position + Vector3(randf_range(-1.5, 1.5), 0.05, randf_range(-1.5, 1.5))
		log_pos.y = get_terrain_height(log_pos.x, log_pos.z) + 0.05
		spawn_random_from_array(log_scenes, log_pos, 0.8, 1.3)
		count += 1
	
	# Flores (áreas com boa umidade)
	if flower_scenes.size() > 0 and moisture > 0.2 and randf() < flower_density:
		var flower_pos = position + Vector3(randf_range(-0.6, 0.6), 0.05, randf_range(-0.6, 0.6))
		flower_pos.y = get_terrain_height(flower_pos.x, flower_pos.z) + 0.05
		spawn_random_from_array(flower_scenes, flower_pos, 0.6, 1.0)
		count += 1
	
	return count

# ============================================================================
# SPAWN DE OBJETOS
# ============================================================================

func spawn_object(scene: PackedScene, position: Vector3, min_scale: float = 0.8, max_scale: float = 1.4):
	if not scene:
		return
		
	var obj = scene.instantiate()
	obj.position = position
	obj.rotation.y = randf_range(0, TAU)
	
	# Ajustar altura baseada no terreno
	obj.position.y = position.y - 0.15
	
	# Escala variada
	var random_scale = randf_range(min_scale, max_scale)
	obj.scale = Vector3(random_scale, random_scale, random_scale)
	
	# Variação de rotação para naturalidade
	obj.rotation.x = randf_range(-0.1, 0.1)
	obj.rotation.z = randf_range(-0.1, 0.1)
	
	add_child(obj)
	
	# Vegetação adicional ao redor de árvores grandes
	if grass_scenes.size() > 0 and randf() < 0.4:
		for i in range(randi() % 3 + 1):
			var offset = Vector3(
				randf_range(-2.0, 2.0),
				0.0,
				randf_range(-2.0, 2.0)
			)
			var grass_pos = position + offset
			grass_pos.y = get_terrain_height(grass_pos.x, grass_pos.z) + 0.05
			spawn_random_from_array(grass_scenes, grass_pos, 0.6, 1.2)

# ============================================================================
# SISTEMA DE BAÚS
# ============================================================================

func can_spawn_chest_here(pos: Vector3) -> bool:
	# Verificar distância mínima de outros baús
	for chest_pos in chest_positions:
		if pos.distance_to(chest_pos) < chest_min_distance:
			return false
	
	# Verificar se está em terreno plano o suficiente
	var h1 = get_terrain_height(pos.x + 1, pos.z)
	var h2 = get_terrain_height(pos.x - 1, pos.z)
	var h3 = get_terrain_height(pos.x, pos.z + 1)
	var h4 = get_terrain_height(pos.x, pos.z - 1)
	
	var max_diff = max(abs(h1 - pos.y), abs(h2 - pos.y), abs(h3 - pos.y), abs(h4 - pos.y))
	if max_diff > 1.5:
		return false
	
	return true

func spawn_chest(position: Vector3):
	if not chest_scene:
		return
	
	var chest = chest_scene.instantiate()
	chest.position = position
	chest.rotation.y = randf_range(0, TAU)
	chest.position.y += 0.3
	
	# Sistema de raridade
	var rarity_roll = randf()
	var rarity_name = ""
	
	if rarity_roll < 0.6:
		chest.rarity = 0  # COMUM
		rarity_name = "Comum"
	elif rarity_roll < 0.9:
		chest.rarity = 1  # RARO
		rarity_name = "Raro"
	elif rarity_roll < 0.98:
		chest.rarity = 2  # ÉPICO
		rarity_name = "Épico"
	else:
		chest.rarity = 3  # LENDÁRIO
		rarity_name = "Lendário"
	
	add_child(chest)
	
	# Configurar SkillManager
	if skill_manager_path != NodePath(""):
		var manager_node = get_node_or_null(skill_manager_path)
		if manager_node:
			chest.skill_manager_path = chest.get_path_to(manager_node)
		else:
			push_warning("SkillManager não encontrado em: " + str(skill_manager_path))

# ============================================================================
# HELPERS
# ============================================================================

func get_random_scene(scenes: Array[PackedScene]) -> PackedScene:
	if scenes.is_empty():
		return null
	return scenes[randi() % scenes.size()]

func spawn_random_from_array(scenes: Array[PackedScene], position: Vector3, min_scale := 0.6, max_scale := 1.2):
	var scene := get_random_scene(scenes)
	if scene == null:
		return
	
	var obj = scene.instantiate()
	obj.position = position
	obj.rotation.y = randf_range(0, TAU)
	
	# Pequena variação de inclinação para naturalidade
	obj.rotation.x = randf_range(-0.15, 0.15)
	obj.rotation.z = randf_range(-0.15, 0.15)
	
	var random_scale = randf_range(min_scale, max_scale)
	obj.scale = Vector3(random_scale, random_scale, random_scale)
	add_child(obj)

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * clamp(t, 0.0, 1.0)

# ============================================================================
# FUNÇÕES DE DEBUG
# ============================================================================

func get_biome_at(x: float, z: float) -> String:
	var height = get_terrain_height(x, z)
	
	if height < water_level:
		return "Oceano"
	elif height < sand_level:
		return "Praia"
	elif height < grass_level:
		return "Planície"
	elif height < forest_level:
		return "Floresta"
	elif height < mountain_level:
		return "Montanha"
	elif height < snow_level:
		return "Montanha Nevada"
	else:
		return "Pico Glacial"

func get_world_stats() -> Dictionary:
	var stats = {
		"seed": world_seed,
		"size": map_size * 2,
		"chunks": int((map_size * 2) / chunk_size) ** 2,
		"chests_spawned": chest_positions.size(),
		"water_level": water_level,
		"max_height": mountain_height + terrain_height
	}
	return stats
