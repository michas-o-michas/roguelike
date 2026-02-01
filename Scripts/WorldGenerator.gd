extends Node3D
class_name WorldGenerator

@export var tree_scene: PackedScene
@export var rock_scene: PackedScene
@export var chest_scene: PackedScene  # Cena do baú

@export var map_size: int = 500
@export var spawn_spacing: float = 5.0
@export var world_seed: int = 0


@export_group("Cenas Decoração Pequena")
@export_range(0.0, 1.0) var small_rocks_density: float = 0.2
@export_range(0.0, 1.0) var grass_density: float = 0.5
@export_range(0.0, 1.0) var bush_density: float = 0.15
@export_range(0.0, 1.0) var log_density: float = 0.08

@export var small_rocks_scenes: Array[PackedScene] = []
@export var grass_scenes: Array[PackedScene] = []
@export var bush_scenes: Array[PackedScene] = []
@export var log_scenes: Array[PackedScene] = []
# Controles de densidade de vegetação
@export_group("Densidade de Objetos")
@export_range(0.0, 1.0) var tree_forest_density: float = 0.7
@export_range(0.0, 1.0) var tree_medium_density: float = 0.4
@export_range(0.0, 1.0) var tree_sparse_density: float = 0.1
@export_range(0.0, 1.0) var rock_cluster_density: float = 0.3
@export_range(0.0, 1.0) var rock_sparse_density: float = 0.08

# Terreno
@export_group("Configurações de Terreno")
@export var terrain_height: float = 12.0
@export var chunk_size: float = 20.0

# Níveis de altura para biomas
@export_group("Níveis de Biomas")
@export var water_level: float = -2.0
@export var sand_level: float = 0.5
@export var grass_level: float = 8.0

# Controles de baús
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
	if world_seed == 0:
		world_seed = randi()
	
	print("🌍 Gerando mundo GRANDE com seed: ", world_seed)
	print("⏳ Aguarde, isso pode demorar...")
	
	seed(world_seed)
	
	setup_noise()
	create_water()
	
	await create_chunked_terrain_async()
	await spawn_vegetation_async()
	
	print("✅ Mundo gerado com sucesso!")

func setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.008
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.4
	
	cluster_noise = FastNoiseLite.new()
	cluster_noise.seed = world_seed + 1000
	cluster_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	cluster_noise.frequency = 0.02
	cluster_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	cluster_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = world_seed + 2000
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = 0.05

func create_water():
	var water_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(map_size * 2, map_size * 2)
	water_mesh.mesh = plane
	water_mesh.position.y = water_level
	
	var water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.1, 0.3, 0.6, 0.7)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.metallic = 0.1
	water_material.roughness = 0.1
	water_material.rim_enabled = true
	water_material.rim = 0.3
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
			
			if current_chunk % 10 == 0:
				print("  Progresso: ", current_chunk, "/", total_chunks, " chunks")
				await get_tree().process_frame

func create_terrain_chunk(start_x: float, start_z: float):
	var mesh_instance = MeshInstance3D.new()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var subdivisions = 10
	var step = chunk_size / subdivisions
	
	var vertices = []
	var colors = []
	
	for z in range(subdivisions + 1):
		for x in range(subdivisions + 1):
			var pos_x = start_x + (x * step)
			var pos_z = start_z + (z * step)
			var height = get_terrain_height(pos_x, pos_z)
			
			vertices.append(Vector3(pos_x, height, pos_z))
			colors.append(get_terrain_color(pos_x, pos_z, height))
	
	for z in range(subdivisions):
		for x in range(subdivisions):
			var i = z * (subdivisions + 1) + x
			
			surface_tool.set_color(colors[i])
			surface_tool.add_vertex(vertices[i])
			surface_tool.set_color(colors[i + 1])
			surface_tool.add_vertex(vertices[i + 1])
			surface_tool.set_color(colors[i + subdivisions + 1])
			surface_tool.add_vertex(vertices[i + subdivisions + 1])
			
			surface_tool.set_color(colors[i + 1])
			surface_tool.add_vertex(vertices[i + 1])
			surface_tool.set_color(colors[i + subdivisions + 2])
			surface_tool.add_vertex(vertices[i + subdivisions + 2])
			surface_tool.set_color(colors[i + subdivisions + 1])
			surface_tool.add_vertex(vertices[i + subdivisions + 1])
	
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
	var noise_value = noise.get_noise_2d(x, z)
	return noise_value * terrain_height

func get_terrain_color(x: float, z: float, height: float) -> Color:
	var moisture = moisture_noise.get_noise_2d(x, z)
	
	if height < water_level:
		return Color(0.15, 0.25, 0.4)
	elif height < sand_level:
		var blend = (height - water_level) / (sand_level - water_level)
		var sand_color = Color(0.9, 0.85, 0.6)
		var wet_sand = Color(0.7, 0.65, 0.5)
		return wet_sand.lerp(sand_color, blend)
	elif height < grass_level:
		var blend = (height - sand_level) / (grass_level - sand_level)
		var light_grass = Color(0.4, 0.7, 0.3)
		var dark_grass = Color(0.2, 0.5, 0.2)
		var base_grass = light_grass.lerp(dark_grass, moisture * 0.5 + 0.5)
		var sand_color = Color(0.9, 0.85, 0.6)
		return sand_color.lerp(base_grass, smoothstep(0.0, 1.0, blend))
	else:
		var blend = clamp((height - grass_level) / (terrain_height - grass_level), 0.0, 1.0)
		var dark_grass = Color(0.15, 0.4, 0.15)
		var rock_color = Color(0.4, 0.4, 0.4)
		return dark_grass.lerp(rock_color, smoothstep(0.3, 1.0, blend))

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func spawn_vegetation_async():
	var spawned_trees = 0
	var spawned_rocks = 0
	var spawned_chests = 0
	var total_checked = 0

	print("🌲 Gerando vegetação...")

	var x = -map_size
	while x < map_size:
		var z = -map_size
		while z < map_size:
			var random_offset_x = randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			var random_offset_z = randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			
			var pos_x = x + random_offset_x
			var pos_z = z + random_offset_z
			
			# Área livre do spawn (perto do spawn do player)
			if Vector2(pos_x, pos_z).length() < 20:
				z += spawn_spacing
				continue
			
			var height = get_terrain_height(pos_x, pos_z)
			
			# Não spawna na água
			if height < water_level + 0.2:
				z += spawn_spacing
				continue
			
			var position = Vector3(pos_x, height, pos_z)
			var cluster_value = cluster_noise.get_noise_2d(pos_x, pos_z)
			var random_value = randf()
			
			# === SISTEMA DE BAÚS (PRIORIDADE) ===
			if enable_chests and chest_scene and randf() < chest_spawn_chance:
				if can_spawn_chest_here(position):
					spawn_chest(position)
					spawned_chests += 1
					chest_positions.append(position)
					z += spawn_spacing
					continue
			
			# === SISTEMA DE ÁRVORES ===
			if cluster_value > 0.3:
				if random_value < tree_forest_density and tree_scene:
					spawn_object(tree_scene, position)
					spawned_trees += 1
			elif cluster_value > 0.0 and cluster_value <= 0.3:
				if random_value < tree_medium_density and tree_scene:
					spawn_object(tree_scene, position)
					spawned_trees += 1
			elif cluster_value > -0.2 and cluster_value <= 0.0:
				if random_value < tree_sparse_density and tree_scene:
					spawn_object(tree_scene, position)
					spawned_trees += 1
			# === SISTEMA DE PEDRAS GRANDES ===
			elif cluster_value < -0.3:
				if random_value < rock_cluster_density and rock_scene:
					spawn_object(rock_scene, position)
					spawned_rocks += 1
			elif cluster_value < -0.1:
				if random_value < rock_sparse_density and rock_scene:
					spawn_object(rock_scene, position)
					spawned_rocks += 1
			
			# --- DETALHES: pedrinhas, grama, moitas, troncos ---
			if height > sand_level:
				# Grama
				if grass_scenes.size() > 0 and randf() < grass_density:
					var grass_pos = position
					grass_pos.y += 0.05
					spawn_random_from_array(grass_scenes, grass_pos, 0.8, 1.4)

				# Pedrinhas pequenas
				if small_rocks_scenes.size() > 0 and randf() < small_rocks_density:
					var srock_pos = position
					srock_pos.y += 0.03
					spawn_random_from_array(small_rocks_scenes, srock_pos, 0.6, 1.2)

				# Moitas em regiões mais "floresta"
				if bush_scenes.size() > 0 and cluster_value > 0.0 and randf() < bush_density:
					var bush_pos = position
					bush_pos.y += 0.05
					spawn_random_from_array(bush_scenes, bush_pos, 0.9, 1.5)

				# Troncos mais raros
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

	# Opcional: um pouco de grama perto de árvores/pedras grandes
	if grass_scenes.size() > 0 and randf() < 0.35:
		var offset = Vector3(
			randf_range(-1.5, 1.5),
			0.0,
			randf_range(-1.5, 1.5)
		)
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

	# Raridade
	var rarity_roll = randf()
	if rarity_roll < 0.7:
		chest.rarity = 0  # COMMON
	elif rarity_roll < 0.95:
		chest.rarity = 1  # RARE
	else:
		chest.rarity = 2  # EPIC
	
	add_child(chest)
	
	# SkillManager
	if skill_manager_path != NodePath(""):
		var manager_node = get_node_or_null(skill_manager_path)
		if manager_node:
			chest.skill_manager_path = chest.get_path_to(manager_node)
		else:
			print("⚠️ SkillManager não encontrado em: ", skill_manager_path)
	else:
		print("⚠️ skill_manager_path não configurado no WorldGenerator!")

# --- Helpers de random scenes ---
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
