# VegetationBuilder.gd
# Cria vegetação (árvores, pedras, etc.) por chunk e partículas ambientais. Usado por InfiniteWorldGenerator.

class_name VegetationBuilder

const ChunkAmbientParticlesScene = preload("res://effects/AmbientParticles.tscn")

static func create_chunk_vegetation(world_gen: InfiniteWorldGenerator, chunk_data, start_pos: Vector3) -> void:
	var vegetation_density := 1.0
	if world_gen.player:
		var dist := world_gen.get_chunk_distance_to_player(chunk_data.chunk_pos)
		if dist > world_gen.visual_lod_far:
			vegetation_density = 0.3
		elif dist > world_gen.visual_lod_near:
			vegetation_density = 0.6

	var biome_cache := {}
	var end_x := start_pos.x + world_gen.chunk_size
	var end_z := start_pos.z + world_gen.chunk_size
	var max_points := world_gen.max_vegetation_points_per_chunk

	var cells: Array[Vector2] = []
	var x := start_pos.x
	while x < end_x:
		var z := start_pos.z
		while z < end_z:
			cells.append(Vector2(x, z))
			z += world_gen.spawn_spacing
		x += world_gen.spawn_spacing
	cells.shuffle()

	var points_done := 0
	for cell in cells:
		if max_points > 0 and points_done >= max_points:
			break
		if vegetation_density < 1.0 and randf() > vegetation_density:
			continue
		var pos_x := cell.x + randf_range(0.0, world_gen.spawn_spacing)
		var pos_z := cell.y + randf_range(0.0, world_gen.spawn_spacing)
		var height := world_gen.get_terrain_height(pos_x, pos_z)
		if height < world_gen.beach_level + 1.0:
			continue
		var position := Vector3(pos_x, height, pos_z)
		var cache_key := Vector2i(int(pos_x / 20.0), int(pos_z / 20.0))
		var current_biome: BiomeData
		if biome_cache.has(cache_key):
			current_biome = biome_cache[cache_key]
		else:
			current_biome = world_gen.get_biome_at_position(pos_x, pos_z, height)
			biome_cache[cache_key] = current_biome
		if current_biome:
			_spawn_biome_item(world_gen, current_biome, position, chunk_data)
		points_done += 1

	if world_gen.enable_ambient_particles and ChunkAmbientParticlesScene:
		var center_x := start_pos.x + world_gen.chunk_size * 0.5
		var center_z := start_pos.z + world_gen.chunk_size * 0.5
		var center_y := world_gen.get_terrain_height(center_x, center_z) + 3.0
		var particles := ChunkAmbientParticlesScene.instantiate()
		particles.position = Vector3(center_x, center_y, center_z)
		world_gen.add_child(particles)
		chunk_data.objects.append(particles)


static func _spawn_biome_item(world_gen: InfiniteWorldGenerator, biome: BiomeData, position: Vector3, chunk_data) -> void:
	var total_weight := 1.0
	for item in biome.biome_items:
		if item and not item.variants.is_empty():
			total_weight += item.spawn_chance
	var roll := randf() * total_weight
	if roll < 1.0:
		return
	roll -= 1.0
	for item in biome.biome_items:
		if not item or item.variants.is_empty():
			continue
		if roll < item.spawn_chance:
			var variant := get_random_variant(item.variants)
			if variant and variant.scene:
				var obj := variant.scene.instantiate()
				obj.position = position
				obj.rotation.y = randf_range(0, TAU)
				var s := randf_range(item.min_scale, item.max_scale)
				obj.scale = Vector3(s, s, s)
				world_gen.add_child(obj)
				chunk_data.objects.append(obj)
				for sub_item in item.sub_items:
					if not sub_item:
						continue
					var count := sub_item.spawn_count
					for _idx in count:
						if randf() > sub_item.spawn_chance:
							continue
						var offset := Vector3(
							randf_range(-sub_item.spawn_radius, sub_item.spawn_radius),
							0.0,
							randf_range(-sub_item.spawn_radius, sub_item.spawn_radius)
						)
						var sub_pos := position + offset
						sub_pos.y = world_gen.get_terrain_height(sub_pos.x, sub_pos.z) + sub_item.height_offset
						var sub_variant := get_random_variant(sub_item.variants)
						if sub_variant and sub_variant.scene:
							var sub_obj := sub_variant.scene.instantiate()
							sub_obj.position = sub_pos
							sub_obj.rotation.y = randf_range(0, TAU)
							var sub_s := randf_range(sub_item.min_scale, sub_item.max_scale)
							sub_obj.scale = Vector3(sub_s, sub_s, sub_s)
							world_gen.add_child(sub_obj)
							chunk_data.objects.append(sub_obj)
			return
		roll -= item.spawn_chance


static func get_random_variant(variants: Array[ItemVariant]) -> ItemVariant:
	if variants.is_empty():
		return null
	var total_weight := 0.0
	for variant in variants:
		if variant:
			total_weight += get_rarity_weight(variant.rarity)
	var roll := randf() * total_weight
	var current_weight := 0.0
	for variant in variants:
		if not variant:
			continue
		current_weight += get_rarity_weight(variant.rarity)
		if roll <= current_weight:
			return variant
	return variants[0]


static func get_rarity_weight(rarity: ItemVariant.Rarity) -> float:
	match rarity:
		ItemVariant.Rarity.COMMON: return 10.0
		ItemVariant.Rarity.UNCOMMON: return 5.0
		ItemVariant.Rarity.RARE: return 2.0
		ItemVariant.Rarity.EPIC: return 0.5
		ItemVariant.Rarity.LEGENDARY: return 0.1
	return 1.0
