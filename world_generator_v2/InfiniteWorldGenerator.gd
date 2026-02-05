extends Node3D
class_name InfiniteWorldGenerator

## Sistema de mundo infinito - gera chunks ao redor do jogador dinamicamente

@export var player_path: NodePath ## Caminho para o jogador (ex: ../Player)
@export var chunk_size: int = 100 ## Tamanho de cada chunk em metros
@export var view_distance: int = 3 ## Quantos chunks carregar ao redor do jogador (3 = 7x7 chunks)
@export var world_seed: int = 12345

@export_group("Otimização")
@export var chunks_per_frame: int = 1 ## Quantos chunks gerar por frame (1 = suave, 3+ = mais rápido)
@export var unload_distance: int = 5 ## Quando descarregar chunks (maior que view_distance)
@export var skip_terrain_collision: bool = false ## ⚠️ Pular colisão (MUITO mais rápido, mas sem física)

@export_group("Terreno")
@export var noise_frequency: float = 0.002
@export var noise_amplitude: float = 25.0
@export var octaves: int = 5
@export var persistence: float = 0.45
@export var lacunarity: float = 2.0
@export var height_redistribution: float = 1.8
@export var terrain_subdivisions: int = 20 ## Subdivisões do mesh (20 = suave)

@export_group("Níveis")
@export var water_level: float = -8.0
@export var beach_level: float = -6.0
@export var grass_level: float = 2.0
@export var mountain_level: float = 18.0

@export_group("Vegetação")
@export var spawn_spacing: float = 5.0
@export var biomes: Array[BiomeData] = []
@export var enable_vegetation: bool = true

@export_group("Água")
@export var enable_water: bool = true
@export var water_size: float = 2000.0 ## Tamanho do plano de água

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

class ChunkData:
	var chunk_pos: Vector2i
	var terrain_mesh: MeshInstance3D
	var terrain_collision: StaticBody3D
	var objects: Array[Node3D] = []
	var is_loaded: bool = false

func _ready():
	setup_noise()
	
	if enable_water:
		create_water()
	
	if player_path != NodePath(""):
		player = get_node_or_null(player_path)
	
	if not player:
		push_warning("⚠️ Player não encontrado! Procurando automaticamente...")
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		print("🌍 Mundo infinito iniciado! Player: ", player.name)
		update_chunks()
	else:
		push_error("❌ Player não encontrado! Configure player_path ou adicione o player ao grupo 'player'")

func _process(_delta):
	if not player:
		return
	
	var current_chunk = world_to_chunk(player.global_position)
	
	# Player mudou de chunk?
	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		update_chunks()
	
	# Gerar chunks da fila
	generate_queued_chunks()

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
	water_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(water_size, water_size)
	water_mesh.mesh = plane
	water_mesh.position.y = water_level
	
	var water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.15, 0.5, 0.8, 0.6)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.metallic = 0.8
	water_material.roughness = 0.05
	water_material.rim_enabled = true
	water_material.rim = 0.6
	water_material.rim_tint = 0.5
	water_material.clearcoat_enabled = true
	water_material.clearcoat = 0.5
	water_material.clearcoat_roughness = 0.1
	water_mesh.material_override = water_material
	
	add_child(water_mesh)
	
	# Colisão da água
	var water_body = StaticBody3D.new()
	var water_collision = CollisionShape3D.new()
	var water_shape = BoxShape3D.new()
	water_shape.size = Vector3(water_size, 0.5, water_size)
	water_collision.shape = water_shape
	water_collision.position.y = water_level - 0.25
	water_body.add_child(water_collision)
	add_child(water_body)

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

func generate_queued_chunks():
	var generated = 0
	
	while generated < chunks_per_frame and chunks_to_generate.size() > 0:
		var chunk_pos = chunks_to_generate.pop_front()
		
		if not loaded_chunks.has(chunk_pos):
			chunks_generating[chunk_pos] = true
			generate_chunk(chunk_pos)
			chunks_generating.erase(chunk_pos)
			generated += 1

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

func create_chunk_terrain(chunk_data: ChunkData, start_pos: Vector3):
	var mesh_instance = MeshInstance3D.new()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var step = float(chunk_size) / terrain_subdivisions
	var vertices = []
	var colors = []
	
	# Gerar vértices
	for z in range(terrain_subdivisions + 1):
		for x in range(terrain_subdivisions + 1):
			var pos_x = start_pos.x + (x * step)
			var pos_z = start_pos.z + (z * step)
			var height = get_terrain_height(pos_x, pos_z)
			
			vertices.append(Vector3(pos_x, height, pos_z))
			colors.append(get_terrain_color(pos_x, pos_z, height))
	
	# Criar triângulos
	for z in range(terrain_subdivisions):
		for x in range(terrain_subdivisions):
			var i = z * (terrain_subdivisions + 1) + x
			
			surface_tool.set_color(colors[i])
			surface_tool.add_vertex(vertices[i])
			surface_tool.set_color(colors[i + 1])
			surface_tool.add_vertex(vertices[i + 1])
			surface_tool.set_color(colors[i + terrain_subdivisions + 1])
			surface_tool.add_vertex(vertices[i + terrain_subdivisions + 1])
			
			surface_tool.set_color(colors[i + 1])
			surface_tool.add_vertex(vertices[i + 1])
			surface_tool.set_color(colors[i + terrain_subdivisions + 2])
			surface_tool.add_vertex(vertices[i + terrain_subdivisions + 2])
			surface_tool.set_color(colors[i + terrain_subdivisions + 1])
			surface_tool.add_vertex(vertices[i + terrain_subdivisions + 1])
	
	surface_tool.generate_normals()
	mesh_instance.mesh = surface_tool.commit()
	
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	mesh_instance.material_override = material
	
	add_child(mesh_instance)
	chunk_data.terrain_mesh = mesh_instance
	
	# Colisão
	if not skip_terrain_collision:
		var static_body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		collision.shape = mesh_instance.mesh.create_trimesh_shape()
		static_body.add_child(collision)
		add_child(static_body)
		chunk_data.terrain_collision = static_body

func create_chunk_vegetation(chunk_data: ChunkData, start_pos: Vector3):
	var biome_cache = {}
	
	var x = start_pos.x
	while x < start_pos.x + chunk_size:
		var z = start_pos.z
		while z < start_pos.z + chunk_size:
			var pos_x = x + randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			var pos_z = z + randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			
			var height = get_terrain_height(pos_x, pos_z)
			
			if height < beach_level + 1.0:
				z += spawn_spacing
				continue
			
			var position = Vector3(pos_x, height, pos_z)
			
			# Bioma com cache
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

func spawn_biome_item(biome: BiomeData, position: Vector3, chunk_data: ChunkData):
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

func get_terrain_height(x: float, z: float) -> float:
	var noise_value = noise.get_noise_2d(x, z)
	var amplitude = noise_amplitude
	var frequency = 1.0
	var height = noise_value * amplitude
	
	for i in range(1, octaves):
		frequency *= lacunarity
		amplitude *= persistence
		height += noise.get_noise_2d(x * frequency, z * frequency) * amplitude
	
	if height > 0:
		var normalized = height / noise_amplitude
		normalized = pow(normalized, height_redistribution)
		height = normalized * noise_amplitude
	else:
		var normalized = abs(height) / noise_amplitude
		normalized = pow(normalized, 1.5)
		height = -normalized * noise_amplitude
	
	height += 3.0
	return height

func get_terrain_color(x: float, z: float, height: float) -> Color:
	var moisture = (moisture_noise.get_noise_2d(x, z) + 1.0) / 2.0
	
	if height < water_level - 2.0:
		return Color(0.08, 0.15, 0.35)
	elif height < water_level:
		var t = (height - (water_level - 2.0)) / 2.0
		return Color(0.08, 0.15, 0.35).lerp(Color(0.15, 0.3, 0.5), t)
	elif height < beach_level:
		var t = (height - water_level) / (beach_level - water_level)
		t = clamp(t, 0.0, 1.0)
		return Color(0.7, 0.65, 0.5).lerp(Color(0.85, 0.8, 0.65), t)
	elif height < grass_level + 3.0:
		var t = (height - beach_level) / ((grass_level + 3.0) - beach_level)
		t = clamp(t, 0.0, 1.0)
		var sand = Color(0.85, 0.8, 0.65)
		var grass = Color(0.4, 0.65, 0.35).lerp(Color(0.35, 0.6, 0.3), moisture)
		return sand.lerp(grass, t * t)
	elif height < mountain_level * 0.4:
		var grass_light = Color(0.35, 0.6, 0.3)
		var grass_dark = Color(0.28, 0.5, 0.25)
		return grass_light.lerp(grass_dark, moisture * 0.5)
	elif height < mountain_level * 0.7:
		var t = (height - mountain_level * 0.4) / (mountain_level * 0.3)
		t = clamp(t, 0.0, 1.0)
		var grass = Color(0.28, 0.5, 0.25)
		var grass_hill = Color(0.3, 0.48, 0.25)
		return grass.lerp(grass_hill, t)
	elif height < mountain_level:
		var t = (height - mountain_level * 0.7) / (mountain_level * 0.3)
		t = clamp(t, 0.0, 1.0)
		t = t * t
		var grass = Color(0.3, 0.48, 0.25)
		var rock_grass = Color(0.35, 0.4, 0.3)
		return grass.lerp(rock_grass, t)
	elif height < mountain_level + 8.0:
		var t = (height - mountain_level) / 8.0
		t = clamp(t, 0.0, 1.0)
		t = t * t
		var rock_grass = Color(0.35, 0.4, 0.3)
		var rock = Color(0.5, 0.5, 0.5)
		return rock_grass.lerp(rock, t)
	else:
		var t = (height - mountain_level - 8.0) / 8.0
		t = clamp(t, 0.0, 1.0)
		t = t * t
		var rock = Color(0.5, 0.5, 0.5)
		var snow = Color(0.92, 0.92, 0.95)
		return rock.lerp(snow, t)

func get_biome_at_position(x: float, z: float, height: float) -> BiomeData:
	var moisture = (moisture_noise.get_noise_2d(x, z) + 1.0) / 2.0
	var temperature = (temperature_noise.get_noise_2d(x, z) + 1.0) / 2.0
	var biome_value = (biome_noise.get_noise_2d(x, z) + 1.0) / 2.0
	
	var best_biome: BiomeData = null
	var best_score = -999999.0
	
	for biome in biomes:
		if not biome:
			continue
		
		if height < biome.min_height or height > biome.max_height:
			continue
		
		var moisture_diff = abs(moisture - biome.preferred_moisture)
		var temp_diff = abs(temperature - biome.preferred_temperature)
		var biome_diff = abs(biome_value - biome.biome_noise_value)
		
		var score = -(moisture_diff + temp_diff + biome_diff)
		
		if score > best_score:
			best_score = score
			best_biome = biome
	
	return best_biome
