# GrassCircleManager.gd
# Node que gerencia a grama em círculo ao redor do jogador (estilo Muck). Adicionar como filho de InfiniteWorldGenerator.

extends Node
class_name GrassCircleManager

var _world_gen: InfiniteWorldGenerator
var _grass_circle_mi: MultiMeshInstance3D
var _grass_positions: PackedVector3Array = PackedVector3Array()
var _grass_free_slots: Array[int] = []
var _grass_last_player_pos: Vector3 = Vector3(0, -9999, 0)
var _grass_wind_material: ShaderMaterial

func _ready() -> void:
	_world_gen = get_parent() as InfiniteWorldGenerator


func _process(delta: float) -> void:
	if not _world_gen or not _world_gen.player or not _world_gen.grass_mesh or not _world_gen.enable_grass_multimesh:
		return
	if _grass_circle_mi == null:
		_setup_grass_circle()
	if _grass_circle_mi == null:
		return
	_process_grass_circle(delta)


func _setup_grass_circle() -> void:
	if not _world_gen or not _world_gen.player or not _world_gen.grass_mesh or _grass_circle_mi != null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = _world_gen.grass_circle_count
	mm.mesh = _world_gen.grass_mesh

	_grass_positions.resize(_world_gen.grass_circle_count)
	_grass_free_slots.clear()
	for i in _world_gen.grass_circle_count:
		var tr := Transform3D()
		tr.origin = Vector3(0, -1000, 0)
		tr.basis = Basis().scaled(Vector3(0.001, 0.001, 0.001))
		mm.set_instance_transform(i, tr)
		_grass_positions[i] = Vector3(0, -1000, 0)
		_grass_free_slots.append(i)

	_grass_circle_mi = MultiMeshInstance3D.new()
	_grass_circle_mi.multimesh = mm
	if _world_gen.grass_with_animation:
		var wind_mat := _get_grass_wind_material()
		if wind_mat:
			_grass_circle_mi.material_override = wind_mat
	_world_gen.add_child(_grass_circle_mi)
	_grass_circle_mi.position = Vector3.ZERO
	_grass_last_player_pos = _world_gen.player.global_position


func _process_grass_circle(_delta: float) -> void:
	if not _world_gen or not _world_gen.player or _grass_circle_mi == null:
		return
	var mm: MultiMesh = _grass_circle_mi.multimesh
	if mm == null:
		return
	var player_pos := _world_gen.player.global_position
	var radius_sq := _world_gen.grass_circle_radius * _world_gen.grass_circle_radius
	var grass_circle_count: int = _world_gen.grass_circle_count

	# Otimização: só varre para cullar tufos se o jogador se moveu >= 1m.
	# Evita loop de N instâncias todo frame quando o jogador está parado (ex.: durante geração).
	var moved_sq := player_pos.distance_squared_to(_grass_last_player_pos)
	if moved_sq >= 1.0:
		for i in grass_circle_count:
			var gp := _grass_positions[i]
			if gp.y < -500.0:
				continue
			var dx := gp.x - player_pos.x
			var dz := gp.z - player_pos.z
			if (dx * dx + dz * dz) > radius_sq:
				var tr := Transform3D()
				tr.origin = Vector3(0, -1000, 0)
				tr.basis = Basis().scaled(Vector3(0.001, 0.001, 0.001))
				mm.set_instance_transform(i, tr)
				_grass_positions[i] = Vector3(0, -1000, 0)
				_grass_free_slots.append(i)

	var spawned := 0
	var max_tries_per_slot := 6
	var forward_2d := Vector2(-_world_gen.player.global_transform.basis.z.x, -_world_gen.player.global_transform.basis.z.z)
	if forward_2d.length_squared() < 0.01:
		forward_2d = Vector2(1.0, 0.0)
	else:
		forward_2d = forward_2d.normalized()
	var angle_fwd := atan2(forward_2d.y, forward_2d.x)
	var r_min := _world_gen.grass_circle_radius * _world_gen.grass_spawn_min_ratio
	var r_range := _world_gen.grass_circle_radius - r_min

	while spawned < _world_gen.grass_spawn_per_frame and _grass_free_slots.size() > 0:
		var slot: int = _grass_free_slots.pop_back()
		var placed := false
		for _attempt in max_tries_per_slot:
			var angle: float
			if randf() < 0.7:
				angle = angle_fwd + randf_range(-PI / 2.0, PI / 2.0)
			else:
				angle = randf() * TAU
			var r := r_min + sqrt(randf()) * r_range
			var wx := player_pos.x + cos(angle) * r
			var wz := player_pos.z + sin(angle) * r
			var h := _world_gen.get_terrain_height(wx, wz)
			if h <= _world_gen.water_level or h < _world_gen.beach_level + 1.0 or h >= _world_gen.grass_max_height:
				continue
			var tr := Transform3D()
			tr.origin = Vector3(wx, h, wz)
			tr.basis = Basis(Vector3.UP, randf() * TAU)
			var s := randf_range(_world_gen.grass_min_scale, _world_gen.grass_max_scale)
			tr.basis = tr.basis.scaled(Vector3(s, s, s))
			mm.set_instance_transform(slot, tr)
			_grass_positions[slot] = Vector3(wx, h, wz)
			placed = true
			break
		if not placed:
			_grass_free_slots.append(slot)
		else:
			spawned += 1
	_grass_last_player_pos = player_pos


func _get_grass_wind_material() -> ShaderMaterial:
	if _grass_wind_material != null or not _world_gen or not _world_gen.grass_mesh:
		return _grass_wind_material
	var shader := load("res://world_generator_v2/shader/grass_wind.gdshader") as Shader
	if not shader:
		return null
	_grass_wind_material = ShaderMaterial.new()
	_grass_wind_material.shader = shader
	_grass_wind_material.set_shader_parameter("wind_strength", _world_gen.grass_wind_strength)
	_grass_wind_material.set_shader_parameter("wind_speed", _world_gen.grass_wind_speed)
	var grass_color := Color(0.25, 0.55, 0.25)
	if _world_gen.world_theme:
		grass_color = _world_gen.world_theme.grass_low_color
	_grass_wind_material.set_shader_parameter("base_color", grass_color)
	var tint := grass_color
	var tex: Texture2D = null
	if _world_gen.grass_mesh.get_surface_count() > 0:
		var mat := _world_gen.grass_mesh.surface_get_material(0)
		if mat:
			tex = TerrainMeshBuilder.get_albedo_texture_from_material(mat)
			if mat is StandardMaterial3D:
				tint = (mat as StandardMaterial3D).albedo_color
	if tex:
		_grass_wind_material.set_shader_parameter("albedo_texture", tex)
	_grass_wind_material.set_shader_parameter("albedo_tint", tint)
	return _grass_wind_material
