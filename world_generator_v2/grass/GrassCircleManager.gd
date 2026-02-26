extends Node
class_name GrassCircleManager

var _world_gen: InfiniteWorldGenerator
var _grass_circle_mi: MultiMeshInstance3D
var _grass_positions: PackedVector3Array = PackedVector3Array()

var _grass_last_player_pos: Vector3
var _next_recycle_index: int = 0


# =====================================================
# READY
# =====================================================

func _ready() -> void:
	_world_gen = get_parent() as InfiniteWorldGenerator


func _process(_delta: float) -> void:
	if not _world_gen \
	or not _world_gen.player \
	or not _world_gen.grass_mesh \
	or not _world_gen.enable_grass_multimesh:
		return
	
	if _grass_circle_mi == null:
		_setup_grass_circle()
		return
	
	_process_grass_circle()


# =====================================================
# SETUP
# =====================================================

func _setup_grass_circle() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = _world_gen.grass_circle_count
	mm.mesh = _world_gen.grass_mesh
	
	_grass_positions.resize(_world_gen.grass_circle_count)
	
	var player_pos := _world_gen.player.global_position
	var radius := _world_gen.grass_circle_radius
	
	for i in _world_gen.grass_circle_count:

		var angle := randf() * TAU
		var r := sqrt(randf()) * radius

		var wx := player_pos.x + cos(angle) * r
		var wz := player_pos.z + sin(angle) * r
		var h := _world_gen.get_terrain_height(wx, wz)

		var tr := Transform3D()
		if h > _world_gen.beach_level + 1.0 and h < _world_gen.grass_max_height:
			tr.origin = _world_gen.to_local(Vector3(wx, h, wz))
			tr.basis = Basis(Vector3.UP, randf() * TAU)
			var s := randf_range(
				_world_gen.grass_min_scale,
				_world_gen.grass_max_scale
			)
			tr.basis = tr.basis.scaled(Vector3(s, s, s))
		else:
			tr.origin = Vector3(0.0, -9999.0, 0.0)

		mm.set_instance_transform(i, tr)
		_grass_positions[i] = Vector3(wx, h, wz)
	
	_grass_circle_mi = MultiMeshInstance3D.new()
	_grass_circle_mi.multimesh = mm
	_world_gen.add_child(_grass_circle_mi)
	
	_grass_last_player_pos = player_pos


# =====================================================
# SISTEMA ULTRA PERFORMÁTICO
# =====================================================

func _process_grass_circle() -> void:
	var mm: MultiMesh = _grass_circle_mi.multimesh
	var player_pos := _world_gen.player.global_position
	
	var movement := player_pos - _grass_last_player_pos
	movement.y = 0
	
	# Só atualiza se realmente houve movimento
	if movement.length_squared() < 0.25:
		return
	
	var move_dir := movement.normalized()
	var radius := _world_gen.grass_circle_radius
	var radius_sq := radius * radius
	
	for i in _grass_positions.size():
		
		var gp := _grass_positions[i]
		
		var dx := gp.x - player_pos.x
		var dz := gp.z - player_pos.z
		
		var dist_sq := dx * dx + dz * dz
		
		# Se saiu do círculo, mover para frente do movimento
		if dist_sq > radius_sq:

			var angle_variation := randf_range(-PI * 0.4, PI * 0.4)
			var base_angle := atan2(move_dir.z, move_dir.x)
			var angle := base_angle + angle_variation

			var spawn_distance := radius * 0.95

			var wx := player_pos.x + cos(angle) * spawn_distance
			var wz := player_pos.z + sin(angle) * spawn_distance
			var h := _world_gen.get_terrain_height(wx, wz)

			var tr := Transform3D()
			if h > _world_gen.beach_level + 1.0 and h < _world_gen.grass_max_height:
				tr.origin = _world_gen.to_local(Vector3(wx, h, wz))
				tr.basis = Basis(Vector3.UP, randf() * TAU)
				var s := randf_range(
					_world_gen.grass_min_scale,
					_world_gen.grass_max_scale
				)
				tr.basis = tr.basis.scaled(Vector3(s, s, s))
			else:
				tr.origin = Vector3(0.0, -9999.0, 0.0)

			mm.set_instance_transform(i, tr)
			_grass_positions[i] = Vector3(wx, h, wz)
	
	_grass_last_player_pos = player_pos
