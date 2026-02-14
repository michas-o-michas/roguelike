extends Node
class_name POIManager

## Gerencia spawn dinâmico de Pontos de Interesse (POIs) conforme o jogador explora.
## Para desativar: enable_pois = false no InfiniteWorldGenerator ou remova este nó.

var spawned_pois: Dictionary = {}  ## {Vector2i: POI_node}
var last_check_pos: Vector3 = Vector3(999999, 0, 999999)


func check_and_spawn_pois(world_gen: InfiniteWorldGenerator) -> void:
	if not world_gen.enable_pois:
		return
	if not world_gen.player:
		return

	var player_pos := world_gen.player.global_position
	if player_pos.distance_to(last_check_pos) <= world_gen.poi_check_interval:
		return
	last_check_pos = player_pos

	if randf() > world_gen.poi_per_area_chance:
		return

	var distance_from_spawn := Vector2(player_pos.x, player_pos.z).length()
	var current_tier: int = world_gen.calculate_difficulty_tier(distance_from_spawn)
	var valid_pois: Array = []
	for poi_data in world_gen.pois:
		if not poi_data or not poi_data.scene:
			continue
		if poi_data.difficulty_tier <= current_tier and poi_data.difficulty_tier > 0:
			valid_pois.append(poi_data)

	for attempt in range(8):
		var angle = randf() * TAU
		var distance = randf_range(80.0, 250.0)
		var pos_x = player_pos.x + cos(angle) * distance
		var pos_z = player_pos.z + sin(angle) * distance

		if not _check_spacing(Vector2(pos_x, pos_z), world_gen.poi_min_spacing):
			continue

		var height: float = world_gen.get_terrain_height(pos_x, pos_z)
		var biome = world_gen.get_biome_at_position(pos_x, pos_z, height)

		if biome and not biome.biome_pois.is_empty():
			for biome_poi in biome.biome_pois:
				if biome_poi and biome_poi.scene and biome_poi.difficulty_tier <= current_tier:
					valid_pois.append(biome_poi)

		if valid_pois.is_empty():
			continue

		var poi_data = valid_pois[randi() % valid_pois.size()]
		if height < poi_data.min_height or height > poi_data.max_height:
			continue

		var position = Vector3(pos_x, height + poi_data.height_offset, pos_z)
		var poi = poi_data.scene.instantiate()
		poi.position = position
		poi.rotation.y = randf_range(0, TAU)
		world_gen.add_child(poi)

		var grid_key = Vector2i(int(pos_x / world_gen.poi_min_spacing), int(pos_z / world_gen.poi_min_spacing))
		spawned_pois[grid_key] = poi

		if world_gen.debug_log:
			var tier_name = world_gen.get_tier_name(current_tier)
			var biome_name = biome.biome_name if biome else "Desconhecido"
			print("📍 POI '", poi_data.poi_name, "' [", tier_name, "] spawned em ", biome_name, " (", int(distance_from_spawn), "m)")
		break


func unload_far(world_gen: InfiniteWorldGenerator) -> void:
	if not world_gen.player:
		return
	var player_chunk := world_gen.world_to_chunk(world_gen.player.global_position)
	var to_remove: Array[Vector2i] = []
	for grid_key in spawned_pois.keys():
		var poi_node = spawned_pois[grid_key]
		if not is_instance_valid(poi_node):
			to_remove.append(grid_key)
			continue
		var chunk_pos := world_gen.world_to_chunk(poi_node.global_position)
		var dist = maxi(abs(chunk_pos.x - player_chunk.x), abs(chunk_pos.y - player_chunk.y))
		if dist > world_gen.unload_distance:
			poi_node.queue_free()
			to_remove.append(grid_key)
	for k in to_remove:
		spawned_pois.erase(k)


func _check_spacing(pos: Vector2, min_spacing: float) -> bool:
	for poi_key in spawned_pois.keys():
		var poi_pos = Vector2(poi_key.x * min_spacing, poi_key.y * min_spacing)
		if pos.distance_to(poi_pos) < min_spacing:
			return false
	return true
