extends Node3D
class_name WorldGeneratorOld

@export var tree_scene: PackedScene
@export var rock_scene: PackedScene
@export var chest_scene: PackedScene

@export var map_size: int = 500
@export var spawn_spacing: float = 5.0
@export var world_seed: int = 12345

@export_group("Cenas Decoração Pequena")
@export_range(0.0, 1.0) var small_rocks_density: float = 0.2
@export_range(0.0, 1.0) var grass_density: float = 0.5
@export_range(0.0, 1.0) var bush_density: float = 0.15
@export_range(0.0, 1.0) var log_density: float = 0.08

@export var small_rocks_scenes: Array[PackedScene] = []
@export var grass_scenes: Array[PackedScene] = []
@export var bush_scenes: Array[PackedScene] = []
@export var log_scenes: Array[PackedScene] = []

@export_group("Densidade de Objetos")
@export_range(0.0, 1.0) var tree_forest_density: float = 0.85   # Aumentado de 0.7
@export_range(0.0, 1.0) var tree_medium_density: float = 0.5    # Aumentado de 0.4
@export_range(0.0, 1.0) var tree_sparse_density: float = 0.15   # Aumentado de 0.1
@export_range(0.0, 1.0) var rock_cluster_density: float = 0.3
@export_range(0.0, 1.0) var rock_sparse_density: float = 0.08

# === CONFIGURAÇÃO DE TERRENO NATURAL ===
@export_group("Configuração de Terreno")
@export var noise_frequency: float = 0.002  # Baixa = mais suave
@export var noise_amplitude: float = 25.0   # Altura máxima do terreno (reduzido de 40.0)
@export var octaves: int = 5                # Camadas de detalhe
@export var persistence: float = 0.45       # Como cada octave afeta (reduzido para suavizar)
@export var lacunarity: float = 2.0         # Frequência entre octaves
@export var terrain_chunk_size: float = 20.0
@export var chunk_subdivisions: int = 20    # Mais = mais suave

@export_group("Níveis de Água e Biomas")
@export var water_level: float = -8.0       # Reduzido de -2.0 para ter menos água
@export var beach_level: float = -6.0       # Ajustado proporcionalmente
@export var grass_level: float = 2.0
@export var mountain_level: float = 18.0    # Aumentado de 12.0

@export_group("Baús")
@export var enable_chests: bool = true
@export_range(0.0, 1.0) var chest_spawn_chance: float = 0.05
@export var chest_min_distance: float = 30.0
@export var skill_manager_path: NodePath

var noise: FastNoiseLite
var cluster_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var chest_positions: Array[Vector3] = []

func _ready():
	generate_world()

func generate_world():
	print("🌍 Gerando mundo natural com seed: ", world_seed)
	print("⏳ Aguarde...")
	
	seed(world_seed)
	setup_noise()
	create_water()
	
	await create_chunked_terrain_async()
	await spawn_vegetation_async()
	
	print("✅ Mundo gerado!")

func setup_noise():
	# === RUÍDO PRINCIPAL - FBM (Fractional Brownian Motion) ===
	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = persistence
	
	# === VEGETAÇÃO ===
	cluster_noise = FastNoiseLite.new()
	cluster_noise.seed = world_seed + 1000
	cluster_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	cluster_noise.frequency = 0.01  # Reduzido de 0.02 para criar clusters maiores
	
	# === UMIDADE ===
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = world_seed + 2000
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = 0.03

func create_water():
	var water_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(map_size * 2, map_size * 2)
	water_mesh.mesh = plane
	water_mesh.position.y = water_level
	
	var water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.1, 0.35, 0.65, 0.75)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.metallic = 0.2
	water_material.roughness = 0.1
	water_material.rim_enabled = true
	water_material.rim = 0.4
	water_mesh.material_override = water_material
	
	add_child(water_mesh)
	
	var water_body = StaticBody3D.new()
	var water_collision = CollisionShape3D.new()
	var water_shape = BoxShape3D.new()
	water_shape.size = Vector3(map_size * 2, 0.5, map_size * 2)
	water_collision.shape = water_shape
	water_collision.position.y = water_level - 0.25
	water_body.add_child(water_collision)
	add_child(water_body)

func create_chunked_terrain_async():
	var chunks_x = int((map_size * 2) / terrain_chunk_size)
	var chunks_z = int((map_size * 2) / terrain_chunk_size)
	var total_chunks = chunks_x * chunks_z
	var current_chunk = 0
	
	print("📦 Gerando ", total_chunks, " chunks...")
	
	for cx in range(chunks_x):
		for cz in range(chunks_z):
			var chunk_x = -map_size + (cx * terrain_chunk_size)
			var chunk_z = -map_size + (cz * terrain_chunk_size)
			create_terrain_chunk(chunk_x, chunk_z)
			
			current_chunk += 1
			if current_chunk % 10 == 0:
				print("  ", current_chunk, "/", total_chunks)
				await get_tree().process_frame

func create_terrain_chunk(start_x: float, start_z: float):
	var mesh_instance = MeshInstance3D.new()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var step = terrain_chunk_size / chunk_subdivisions
	var vertices = []
	var colors = []
	
	# Gerar vértices
	for z in range(chunk_subdivisions + 1):
		for x in range(chunk_subdivisions + 1):
			var pos_x = start_x + (x * step)
			var pos_z = start_z + (z * step)
			var height = get_terrain_height(pos_x, pos_z)
			
			vertices.append(Vector3(pos_x, height, pos_z))
			colors.append(get_terrain_color(pos_x, pos_z, height))
	
	# Criar triângulos
	for z in range(chunk_subdivisions):
		for x in range(chunk_subdivisions):
			var i = z * (chunk_subdivisions + 1) + x
			
			surface_tool.set_color(colors[i])
			surface_tool.add_vertex(vertices[i])
			surface_tool.set_color(colors[i + 1])
			surface_tool.add_vertex(vertices[i + 1])
			surface_tool.set_color(colors[i + chunk_subdivisions + 1])
			surface_tool.add_vertex(vertices[i + chunk_subdivisions + 1])
			
			surface_tool.set_color(colors[i + 1])
			surface_tool.add_vertex(vertices[i + 1])
			surface_tool.set_color(colors[i + chunk_subdivisions + 2])
			surface_tool.add_vertex(vertices[i + chunk_subdivisions + 2])
			surface_tool.set_color(colors[i + chunk_subdivisions + 1])
			surface_tool.add_vertex(vertices[i + chunk_subdivisions + 1])
	
	surface_tool.generate_normals()
	mesh_instance.mesh = surface_tool.commit()
	
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	mesh_instance.material_override = material
	
	add_child(mesh_instance)
	
	var static_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	collision.shape = mesh_instance.mesh.create_trimesh_shape()
	static_body.add_child(collision)
	add_child(static_body)

func get_terrain_height(x: float, z: float) -> float:
	# Pegar valor de ruído (-1 a 1)
	var noise_value = noise.get_noise_2d(x, z)
	
	# Aplicar FBM manualmente para mais controle
	var amplitude = noise_amplitude
	var frequency = 1.0
	var height = noise_value * amplitude
	
	# Adicionar octaves extras para detalhes
	for i in range(1, octaves):
		frequency *= lacunarity
		amplitude *= persistence
		height += noise.get_noise_2d(x * frequency, z * frequency) * amplitude
	
	# === FALLOFF para criar oceanos nas bordas ===
	var distance_from_center = Vector2(x, z).length()
	var max_distance = map_size * 0.8
	
	if distance_from_center > max_distance * 0.6:
		var falloff = (distance_from_center - max_distance * 0.6) / (max_distance * 0.4)
		falloff = clamp(falloff, 0.0, 1.0)
		falloff = falloff * falloff * falloff  # Curva cúbica = suave
		height = lerp(height, water_level - 3.0, falloff)
	
	# === REDISTRIBUIÇÃO para criar mais planícies ===
	# Elevar ao quadrado reduz valores médios, criando mais áreas planas
	if height > 0:
		var normalized = height / noise_amplitude
		normalized = pow(normalized, 1.8)  # Aumentado para 1.8 para criar MUITAS planícies
		height = normalized * noise_amplitude
	else:
		# Para valores negativos (abaixo do nível 0), também suavizar
		var normalized = abs(height) / noise_amplitude
		normalized = pow(normalized, 1.5)  # Suavizar depressões
		height = -normalized * noise_amplitude
	
	# === SPAWN AREA sempre plana ===
	var spawn_dist = Vector2(x, z).length()
	if spawn_dist < 40.0:
		var blend = 1.0 - (spawn_dist / 40.0)
		blend = blend * blend * blend
		height = lerp(height, 1.0, blend)
	
	# === ELEVAÇÃO BASE para criar mais terra e menos água ===
	# Adiciona uma elevação base para a maioria do terreno
	height += 3.0  # Eleva tudo em 3 unidades
	
	return height

func get_terrain_color(x: float, z: float, height: float) -> Color:
	var moisture = (moisture_noise.get_noise_2d(x, z) + 1.0) / 2.0
	
	# Água profunda
	if height < water_level - 2.0:
		return Color(0.08, 0.15, 0.35)
	
	# Água rasa
	elif height < water_level:
		var t = (height - (water_level - 2.0)) / 2.0
		return Color(0.08, 0.15, 0.35).lerp(Color(0.15, 0.3, 0.5), t)
	
	# Areia
	elif height < beach_level:
		var t = (height - water_level) / (beach_level - water_level)
		t = clamp(t, 0.0, 1.0)
		return Color(0.7, 0.65, 0.5).lerp(Color(0.85, 0.8, 0.65), t)
	
	# Grama baixa (planícies)
	elif height < grass_level + 3.0:  # Expandido para criar mais planícies verdes
		var t = (height - beach_level) / ((grass_level + 3.0) - beach_level)
		t = clamp(t, 0.0, 1.0)
		var sand = Color(0.85, 0.8, 0.65)
		var grass = Color(0.4, 0.65, 0.35).lerp(Color(0.35, 0.6, 0.3), moisture)
		return sand.lerp(grass, t * t)
	
	# Grama média (planícies)
	elif height < mountain_level * 0.4:  # Mais área de planície antes das montanhas
		var grass_light = Color(0.35, 0.6, 0.3)
		var grass_dark = Color(0.28, 0.5, 0.25)
		return grass_light.lerp(grass_dark, moisture * 0.5)
	
	# Grama de transição para montanha
	elif height < mountain_level * 0.7:
		var t = (height - mountain_level * 0.4) / (mountain_level * 0.3)
		t = clamp(t, 0.0, 1.0)
		var grass = Color(0.28, 0.5, 0.25)
		var grass_hill = Color(0.3, 0.48, 0.25)
		return grass.lerp(grass_hill, t)
	
	# Grama de montanha
	elif height < mountain_level:
		var t = (height - mountain_level * 0.7) / (mountain_level * 0.3)
		t = clamp(t, 0.0, 1.0)
		t = t * t  # Quadrática = transição suave
		var grass = Color(0.3, 0.48, 0.25)
		var rock_grass = Color(0.35, 0.4, 0.3)
		return grass.lerp(rock_grass, t)
	
	# Rocha
	elif height < mountain_level + 8.0:
		var t = (height - mountain_level) / 8.0
		t = clamp(t, 0.0, 1.0)
		t = t * t
		var rock_grass = Color(0.35, 0.4, 0.3)
		var rock = Color(0.5, 0.5, 0.5)
		return rock_grass.lerp(rock, t)
	
	# Neve
	else:
		var t = (height - mountain_level - 8.0) / 8.0
		t = clamp(t, 0.0, 1.0)
		t = t * t
		var rock = Color(0.5, 0.5, 0.5)
		var snow = Color(0.92, 0.92, 0.95)
		return rock.lerp(snow, t)

func spawn_vegetation_async():
	var spawned_trees = 0
	var spawned_rocks = 0
	var spawned_chests = 0
	var total_checked = 0
	var skipped_height = 0
	var skipped_spawn_area = 0

	print("🌲 Gerando vegetação...")
	print("   beach_level: ", beach_level)
	print("   mountain_level: ", mountain_level)
	print("   tree_scene existe: ", tree_scene != null)

	var x = -map_size
	while x < map_size:
		var z = -map_size
		while z < map_size:
			var random_offset_x = randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			var random_offset_z = randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			
			var pos_x = x + random_offset_x
			var pos_z = z + random_offset_z
			
			if Vector2(pos_x, pos_z).length() < 25:
				skipped_spawn_area += 1
				z += spawn_spacing
				continue
			
			var height = get_terrain_height(pos_x, pos_z)
			
			# Permitir vegetação em áreas acima da praia até montanhas altas
			if height < beach_level + 1.0 or height > mountain_level + 12.0:
				skipped_height += 1
				z += spawn_spacing
				continue
			
			var position = Vector3(pos_x, height, pos_z)
			var cluster_value = cluster_noise.get_noise_2d(pos_x, pos_z)
			var random_value = randf()
			
			# BAÚS (não bloqueiam mais outras vegetações)
			if enable_chests and chest_scene and randf() < chest_spawn_chance:
				if can_spawn_chest_here(position):
					spawn_chest(position)
					spawned_chests += 1
					chest_positions.append(position)
			
			# ÁRVORES (lógica mais simples e permissiva)
			var tree_chance = 0.0
			if cluster_value > 0.3:
				tree_chance = tree_forest_density  # Floresta densa
			elif cluster_value > -0.1:
				tree_chance = tree_medium_density  # Floresta média
			else:
				tree_chance = tree_sparse_density  # Árvores esparsas
			
			if random_value < tree_chance and tree_scene:
				spawn_object(tree_scene, position)
				spawned_trees += 1
			
			# PEDRAS
			elif cluster_value < -0.3:
				if random_value < rock_cluster_density and rock_scene:
					spawn_object(rock_scene, position)
					spawned_rocks += 1
			elif cluster_value < -0.1:
				if random_value < rock_sparse_density and rock_scene:
					spawn_object(rock_scene, position)
					spawned_rocks += 1
			
			# DECORAÇÃO
			if height > beach_level:
				if grass_scenes.size() > 0 and randf() < grass_density:
					var grass_pos = position
					grass_pos.y += 0.05
					spawn_random_from_array(grass_scenes, grass_pos, 0.8, 1.4)

				if small_rocks_scenes.size() > 0 and randf() < small_rocks_density:
					var srock_pos = position
					srock_pos.y += 0.03
					spawn_random_from_array(small_rocks_scenes, srock_pos, 0.6, 1.2)

				if bush_scenes.size() > 0 and cluster_value > 0.0 and randf() < bush_density:
					var bush_pos = position
					bush_pos.y += 0.05
					spawn_random_from_array(bush_scenes, bush_pos, 0.9, 1.5)

				if log_scenes.size() > 0 and randf() < log_density:
					var log_pos = position
					log_pos.y += 0.05
					spawn_random_from_array(log_scenes, log_pos, 0.9, 1.4)

			total_checked += 1
			if total_checked % 100 == 0:
				await get_tree().process_frame
			
			z += spawn_spacing
		x += spawn_spacing
	
	print("✅ 🌲 Árvores: ", spawned_trees, " | 🪨 Pedras: ", spawned_rocks, " | 📦 Baús: ", spawned_chests)
	print("📊 Debug:")
	print("   Total verificado: ", total_checked)
	print("   Bloqueados por área spawn: ", skipped_spawn_area)
	print("   Bloqueados por altura: ", skipped_height)
	print("   Área válida: ", total_checked - skipped_spawn_area - skipped_height)

func spawn_object(scene: PackedScene, position: Vector3):
	if not scene:
		return
	var obj = scene.instantiate()
	obj.position = position
	obj.rotation.y = randf_range(0, TAU)
	obj.position.y = position.y - 0.2
	var random_scale = randf_range(0.8, 1.4)
	obj.scale = Vector3(random_scale, random_scale, random_scale)
	add_child(obj)
	
	if grass_scenes.size() > 0 and randf() < 0.35:
		var offset = Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		var grass_pos = position + offset
		grass_pos.y += 0.05
		spawn_random_from_array(grass_scenes, grass_pos, 0.7, 1.3)

func can_spawn_chest_here(pos: Vector3) -> bool:
	for chest_pos in chest_positions:
		if pos.distance_to(chest_pos) < chest_min_distance:
			return false
	return true

func spawn_chest(position: Vector3):
	if not chest_scene:
		return
	var chest = chest_scene.instantiate()
	chest.position = position
	chest.rotation.y = randf_range(0, TAU)
	chest.position.y += 0.5
	
	var rarity_roll = randf()
	if rarity_roll < 0.7:
		chest.rarity = 0
	elif rarity_roll < 0.95:
		chest.rarity = 1
	else:
		chest.rarity = 2
	
	add_child(chest)
	
	if skill_manager_path != NodePath(""):
		var manager_node = get_node_or_null(skill_manager_path)
		if manager_node:
			chest.skill_manager_path = chest.get_path_to(manager_node)

func get_random_scene(scenes: Array[PackedScene]) -> PackedScene:
	if scenes.is_empty():
		return null
	return scenes[randi() % scenes.size()]

func spawn_random_from_array(scenes: Array[PackedScene], position: Vector3, min_scale := 0.7, max_scale := 1.3):
	var scene := get_random_scene(scenes)
	if scene == null:
		return
	var obj = scene.instantiate()
	obj.position = position
	obj.rotation.y = randf_range(0, TAU)
	var random_scale = randf_range(min_scale, max_scale)
	obj.scale = Vector3(random_scale, random_scale, random_scale)
	add_child(obj)
