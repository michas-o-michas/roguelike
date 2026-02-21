extends Node
class_name SpawnerManager

## Gerencia spawn dinâmico de Animal Spawners quando o mundo está pronto.
## Para desativar: enable_spawners = false no InfiniteWorldGenerator ou remova este nó.

var spawned_spawners: Dictionary = {}  ## {Vector2i: Spawner_node}
var last_check_pos: Vector3 = Vector3(999999, 0, 999999)


func check_and_spawn_spawners(world_gen: InfiniteWorldGenerator) -> void:
	if not world_gen.enable_spawners:
		return
	if not world_gen.player:
		return

	var player_pos := world_gen.player.global_position
	if player_pos.distance_to(last_check_pos) <= world_gen.spawner_check_interval:
		return
	last_check_pos = player_pos

	if randf() > world_gen.spawner_per_area_chance:
		return

	var distance_from_spawn := Vector2(player_pos.x, player_pos.z).length()
	var current_tier: int = world_gen.calculate_difficulty_tier(distance_from_spawn)
	var valid_spawners: Array = []
	for spawner_data in world_gen.animal_spawners:
		if not spawner_data or not spawner_data.spawner_scene:
			continue
		if spawner_data.difficulty_tier <= current_tier and spawner_data.difficulty_tier > 0:
			valid_spawners.append(spawner_data)

	for attempt in range(6):
		var angle = randf() * TAU
		var distance = randf_range(50.0, 180.0)
		var pos_x = player_pos.x + cos(angle) * distance
		var pos_z = player_pos.z + sin(angle) * distance

		if not _check_spacing(Vector2(pos_x, pos_z), world_gen.spawner_min_spacing):
			continue

		var height: float = world_gen.get_terrain_height(pos_x, pos_z)
		var biome = world_gen.get_biome_at_position(pos_x, pos_z, height)
		if not biome:
			continue

		if not biome.biome_spawners.is_empty():
			for biome_spawner in biome.biome_spawners:
				if biome_spawner and biome_spawner.spawner_scene and biome_spawner.difficulty_tier <= current_tier:
					valid_spawners.append(biome_spawner)

		if valid_spawners.is_empty():
			continue

		var spawner_data = valid_spawners[randi() % valid_spawners.size()]
		if height < spawner_data.min_height or height > spawner_data.max_height:
			continue

		if not spawner_data.allowed_biomes.is_empty():
			var valid_biome = false
			for allowed in spawner_data.allowed_biomes:
				if allowed == biome.biome_name:
					valid_biome = true
					break
			if not valid_biome:
				continue

		var position = Vector3(pos_x, height + 5, pos_z)
		if not spawner_data.spawner_scene:
			push_warning("SpawnerManager: spawner_scene está vazio em '%s'" % spawner_data.spawner_name)
			continue
		var spawner = spawner_data.spawner_scene.instantiate()
		if not spawner:
			push_warning("SpawnerManager: falha ao instanciar cena do spawner '%s'" % spawner_data.spawner_name)
			continue
		spawner.position = position
		world_gen.add_child(spawner)

		var grid_key = Vector2i(int(pos_x / world_gen.spawner_min_spacing), int(pos_z / world_gen.spawner_min_spacing))
		spawned_spawners[grid_key] = spawner

		if world_gen.debug_log:
			var tier_name = world_gen.get_tier_name(current_tier)
			print("🐾 Spawner '", spawner_data.spawner_name, "' [", tier_name, "] em ", biome.biome_name, " (", int(distance_from_spawn), "m)")
		break


func unload_far(world_gen: InfiniteWorldGenerator) -> void:
	if not world_gen.player:
		return
	var player_chunk := world_gen.world_to_chunk(world_gen.player.global_position)
	var to_remove: Array[Vector2i] = []
	for grid_key in spawned_spawners.keys():
		var spawner_node = spawned_spawners[grid_key]
		if not is_instance_valid(spawner_node):
			to_remove.append(grid_key)
			continue
		var chunk_pos := world_gen.world_to_chunk(spawner_node.global_position)
		var dist = maxi(abs(chunk_pos.x - player_chunk.x), abs(chunk_pos.y - player_chunk.y))
		if dist > world_gen.unload_distance:
			spawner_node.queue_free()
			to_remove.append(grid_key)
	for k in to_remove:
		spawned_spawners.erase(k)


func _check_spacing(pos: Vector2, min_spacing: float) -> bool:
	for key in spawned_spawners.keys():
		var other_pos = Vector2(key.x * min_spacing, key.y * min_spacing)
		if pos.distance_to(other_pos) < min_spacing:
			return false
	return true
