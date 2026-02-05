extends Node3D
class_name WorldGenerator

@export var map_size: int = 500
@export var spawn_spacing: float = 5.0
@export var world_seed: int = 12345

@export_group("⚡ Otimização de Velocidade")
@export var fast_terrain: bool = true ## 🏔️ Gera terreno SEM yields (instantâneo). RECOMENDADO!
@export var skip_terrain_collision: bool = false ## ⚠️ Pular colisão (10x mais rápido, mas sem física). Só para testes!
@export var terrain_batch_size: int = 50 ## Chunks por batch quando fast_terrain = false
@export var vegetation_batch_size: int = 500 ## Tiles de vegetação por yield
@export var use_biome_cache: bool = true ## Cache de biomas (5x mais rápido)

# === CONFIGURAÇÃO DE TERRENO NATURAL ===
@export_group("Configuração de Terreno")
@export var noise_frequency: float = 0.002
@export var noise_amplitude: float = 25.0
@export var octaves: int = 5
@export var persistence: float = 0.45
@export var lacunarity: float = 2.0
@export var terrain_chunk_size: float = 20.0
@export var chunk_subdivisions: int = 20

@export_group("Níveis de Água e Biomas")
@export var water_level: float = -8.0
@export var beach_level: float = -6.0
@export var grass_level: float = 2.0
@export var mountain_level: float = 18.0

@export_group("Baús")
@export var enable_chests: bool = true
@export_range(0.0, 1.0) var chest_spawn_chance: float = 0.05
@export var chest_min_distance: float = 30.0
@export var chest_scene: PackedScene
@export var skill_manager_path: NodePath

@export_group("Biomas")
@export var biomes: Array[BiomeData] = []

@export_group("Pontos de Interesse (POIs)")
@export var pois: Array[POIData] = []

@export_group("Spawners de Animais")
@export var animal_spawners: Array[AnimalSpawnerData] = []

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var temperature_noise: FastNoiseLite
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
	await spawn_world_content_async()
	
	print("✅ Mundo gerado!")

func setup_noise():
	# === RUÍDO PRINCIPAL - FBM ===
	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = persistence
	
	# === BIOMAS ===
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = world_seed + 1000
	biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_noise.frequency = 0.008
	biome_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	
	# === UMIDADE ===
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = world_seed + 2000
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = 0.015
	
	# === TEMPERATURA ===
	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = world_seed + 3000
	temperature_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	temperature_noise.frequency = 0.012

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
	var chunks_x = int((map_size * 2) / terrain_chunk_size)
	var chunks_z = int((map_size * 2) / terrain_chunk_size)
	var total_chunks = chunks_x * chunks_z
	var current_chunk = 0
	
	print("📦 Gerando ", total_chunks, " chunks...")
	
	if fast_terrain:
		# MODO RÁPIDO: Gera tudo de uma vez SEM yields
		print("⚡ Modo rápido ativado - gerando instantaneamente...")
		for cx in range(chunks_x):
			for cz in range(chunks_z):
				var chunk_x = -map_size + (cx * terrain_chunk_size)
				var chunk_z = -map_size + (cz * terrain_chunk_size)
				create_terrain_chunk(chunk_x, chunk_z)
		print("  ✅ ", total_chunks, " chunks gerados instantaneamente!")
	else:
		# MODO NORMAL: Com yields (só para debug)
		for cx in range(chunks_x):
			for cz in range(chunks_z):
				var chunk_x = -map_size + (cx * terrain_chunk_size)
				var chunk_z = -map_size + (cz * terrain_chunk_size)
				create_terrain_chunk(chunk_x, chunk_z)
				
				current_chunk += 1
				if current_chunk % terrain_batch_size == 0:
					print("  ", current_chunk, "/", total_chunks)
					await get_tree().process_frame

func create_terrain_chunk(start_x: float, start_z: float):
	var mesh_instance = MeshInstance3D.new()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var step = terrain_chunk_size / chunk_subdivisions
	var vertices = []
	var colors = []
	
	for z in range(chunk_subdivisions + 1):
		for x in range(chunk_subdivisions + 1):
			var pos_x = start_x + (x * step)
			var pos_z = start_z + (z * step)
			var height = get_terrain_height(pos_x, pos_z)
			
			vertices.append(Vector3(pos_x, height, pos_z))
			colors.append(get_terrain_color(pos_x, pos_z, height))
	
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
	
	# Colisão (PESADO! - pode ser desabilitado para testes)
	if not skip_terrain_collision:
		var static_body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		collision.shape = mesh_instance.mesh.create_trimesh_shape()
		static_body.add_child(collision)
		add_child(static_body)

func get_terrain_height(x: float, z: float) -> float:
	var noise_value = noise.get_noise_2d(x, z)
	var amplitude = noise_amplitude
	var frequency = 1.0
	var height = noise_value * amplitude
	
	for i in range(1, octaves):
		frequency *= lacunarity
		amplitude *= persistence
		height += noise.get_noise_2d(x * frequency, z * frequency) * amplitude
	
	var distance_from_center = Vector2(x, z).length()
	var max_distance = map_size * 0.8
	
	if distance_from_center > max_distance * 0.6:
		var falloff = (distance_from_center - max_distance * 0.6) / (max_distance * 0.4)
		falloff = clamp(falloff, 0.0, 1.0)
		falloff = falloff * falloff * falloff
		height = lerp(height, water_level - 3.0, falloff)
	
	if height > 0:
		var normalized = height / noise_amplitude
		normalized = pow(normalized, 1.8)
		height = normalized * noise_amplitude
	else:
		var normalized = abs(height) / noise_amplitude
		normalized = pow(normalized, 1.5)
		height = -normalized * noise_amplitude
	
	var spawn_dist = Vector2(x, z).length()
	if spawn_dist < 40.0:
		var blend = 1.0 - (spawn_dist / 40.0)
		blend = blend * blend * blend
		height = lerp(height, 1.0, blend)
	
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

func spawn_world_content_async():
	var stats = {
		"total_checked": 0,
		"skipped_spawn_area": 0,
		"skipped_invalid_terrain": 0,
		"chests": 0,
		"pois": 0,
		"animal_spawners": 0
	}
	
	# Contador por bioma
	var biome_stats = {}
	for biome in biomes:
		if biome:
			biome_stats[biome.biome_name] = {
				"total": 0,
				"items": {}
			}
	
	print("🌲 Gerando conteúdo do mundo...")
	
	# Primeiro: spawnar POIs
	await spawn_pois(stats)
	
	# Segundo: spawnar spawners de animais
	await spawn_animal_spawners(stats)
	
	# Terceiro: spawnar vegetação e itens por bioma
	print("🌲 Spawning vegetation...")
	
	var biome_cache = {}
	var cache_res = 20.0
	
	var x = -map_size
	while x < map_size:
		var z = -map_size
		while z < map_size:
			var random_offset_x = randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			var random_offset_z = randf_range(-spawn_spacing * 0.4, spawn_spacing * 0.4)
			
			var pos_x = x + random_offset_x
			var pos_z = z + random_offset_z
			
			# Pular área de spawn do jogador
			if Vector2(pos_x, pos_z).length() < 25:
				stats.skipped_spawn_area += 1
				z += spawn_spacing
				continue
			
			var height = get_terrain_height(pos_x, pos_z)
			var position = Vector3(pos_x, height, pos_z)
			
			# Pular água muito profunda
			if height < beach_level + 1.0:
				stats.skipped_invalid_terrain += 1
				z += spawn_spacing
				continue
			
			stats.total_checked += 1
			
			# Spawnar baús
			if enable_chests and chest_scene and randf() < chest_spawn_chance:
				if can_spawn_chest_here(position):
					spawn_chest(position)
					stats.chests += 1
					chest_positions.append(position)
			
			# Determinar bioma atual com cache
			var current_biome: BiomeData
			if use_biome_cache:
				var cache_key = Vector2(int(pos_x / cache_res), int(pos_z / cache_res))
				if biome_cache.has(cache_key):
					current_biome = biome_cache[cache_key]
				else:
					current_biome = get_biome_at_position(pos_x, pos_z, height)
					biome_cache[cache_key] = current_biome
			else:
				current_biome = get_biome_at_position(pos_x, pos_z, height)
			
			if current_biome:
				# Spawnar itens do bioma
				spawn_biome_content(current_biome, position, pos_x, pos_z, height, biome_stats)
			
			if stats.total_checked % vegetation_batch_size == 0:
				await get_tree().process_frame
			
			z += spawn_spacing
		x += spawn_spacing
	
	print_world_stats(stats, biome_stats)

func get_biome_at_position(x: float, z: float, height: float) -> BiomeData:
	var moisture = (moisture_noise.get_noise_2d(x, z) + 1.0) / 2.0
	var temperature = (temperature_noise.get_noise_2d(x, z) + 1.0) / 2.0
	var biome_value = (biome_noise.get_noise_2d(x, z) + 1.0) / 2.0
	
	var best_biome: BiomeData = null
	var best_score = -999999.0
	
	for biome in biomes:
		if not biome:
			continue
		
		# Verificar altura
		if height < biome.min_height or height > biome.max_height:
			continue
		
		# Calcular score baseado em umidade, temperatura e biome noise
		var moisture_diff = abs(moisture - biome.preferred_moisture)
		var temp_diff = abs(temperature - biome.preferred_temperature)
		var biome_diff = abs(biome_value - biome.biome_noise_value)
		
		var score = -(moisture_diff + temp_diff + biome_diff)
		
		if score > best_score:
			best_score = score
			best_biome = biome
	
	return best_biome

func spawn_biome_content(biome: BiomeData, position: Vector3, x: float, z: float, height: float, stats: Dictionary):
	if not stats.has(biome.biome_name):
		return
	
	# Spawnar itens principais do bioma
	for item in biome.biome_items:
		if not item or item.variants.is_empty():
			continue
		
		if randf() < item.spawn_chance:
			var variant = get_random_variant_by_rarity(item.variants)
			if variant and variant.scene:
				spawn_item(variant.scene, position, item.min_scale, item.max_scale)
				
				# Atualizar stats
				if not stats[biome.biome_name].items.has(item.item_name):
					stats[biome.biome_name].items[item.item_name] = 0
				stats[biome.biome_name].items[item.item_name] += 1
				stats[biome.biome_name].total += 1
				
				# Spawnar sub-itens (decoração ao redor)
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
					
					var sub_variant = get_random_variant_by_rarity(sub_item.variants)
					if sub_variant and sub_variant.scene:
						spawn_item(sub_variant.scene, sub_pos, sub_item.min_scale, sub_item.max_scale)

func get_random_variant_by_rarity(variants: Array[ItemVariant]) -> ItemVariant:
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

func spawn_item(scene: PackedScene, position: Vector3, min_scale: float = 0.8, max_scale: float = 1.4):
	if not scene:
		return
	
	var obj = scene.instantiate()
	obj.position = position
	obj.rotation.y = randf_range(0, TAU)
	
	var random_scale = randf_range(min_scale, max_scale)
	obj.scale = Vector3(random_scale, random_scale, random_scale)
	
	add_child(obj)

func spawn_pois(stats: Dictionary):
	print("📍 Spawning POIs...")
	
	for poi_data in pois:
		if not poi_data:
			continue
		
		for i in range(poi_data.count):
			var attempts = 0
			var spawned = false
			
			while attempts < 50 and not spawned:
				var angle = randf() * TAU
				var distance = randf_range(poi_data.min_distance_from_center, poi_data.max_distance_from_center)
				
				var pos_x = cos(angle) * distance
				var pos_z = sin(angle) * distance
				var height = get_terrain_height(pos_x, pos_z)
				
				if height >= poi_data.min_height and height <= poi_data.max_height:
					var position = Vector3(pos_x, height + poi_data.height_offset, pos_z)
					
					if poi_data.scene:
						var poi = poi_data.scene.instantiate()
						poi.position = position
						poi.rotation.y = randf_range(0, TAU)
						add_child(poi)
						stats.pois += 1
						spawned = true
				
				attempts += 1
			
			await get_tree().process_frame
	
	print("  ✅ ", stats.pois, " POIs spawned")

func spawn_animal_spawners(stats: Dictionary):
	print("🐾 Spawning Animal Spawners...")
	
	for spawner_data in animal_spawners:
		if not spawner_data or not spawner_data.spawner_scene:
			continue
		
		for i in range(spawner_data.count):
			var attempts = 0
			var spawned = false
			
			while attempts < 50 and not spawned:
				var angle = randf() * TAU
				var distance = randf_range(spawner_data.min_distance, spawner_data.max_distance)
				
				var pos_x = cos(angle) * distance
				var pos_z = sin(angle) * distance
				var height = get_terrain_height(pos_x, pos_z)
				
				# Verificar bioma
				var biome = get_biome_at_position(pos_x, pos_z, height)
				var valid_biome = spawner_data.allowed_biomes.is_empty()
				
				if biome and not spawner_data.allowed_biomes.is_empty():
					for allowed in spawner_data.allowed_biomes:
						if allowed == biome.biome_name:
							valid_biome = true
							break
				
				if valid_biome and height >= spawner_data.min_height and height <= spawner_data.max_height:
					var position = Vector3(pos_x, height, pos_z)
					
					var spawner = spawner_data.spawner_scene.instantiate()
					spawner.position = position
					add_child(spawner)
					stats.animal_spawners += 1
					spawned = true
				
				attempts += 1
			
			await get_tree().process_frame
	
	print("  ✅ ", stats.animal_spawners, " Animal Spawners created")

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

func print_world_stats(stats: Dictionary, biome_stats: Dictionary):
	print("\n✅ ========== MUNDO GERADO ==========")
	print("📊 Estatísticas Gerais:")
	print("   Total verificado: ", stats.total_checked)
	print("   Bloqueados (área spawn): ", stats.skipped_spawn_area)
	print("   Bloqueados (terreno): ", stats.skipped_invalid_terrain)
	print("   📦 Baús: ", stats.chests)
	print("   📍 POIs: ", stats.pois)
	print("   🐾 Animal Spawners: ", stats.animal_spawners)
	
	print("\n🌳 Estatísticas por Bioma:")
	for biome_name in biome_stats.keys():
		var biome_data = biome_stats[biome_name]
		if biome_data.total > 0:
			print("   [", biome_name, "] Total: ", biome_data.total)
			for item_name in biome_data.items.keys():
				print("      - ", item_name, ": ", biome_data.items[item_name])
	
	print("=====================================\n")
