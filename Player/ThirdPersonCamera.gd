extends Camera3D
## Câmera 3D terceira pessoa — padrão AAA.
## Spring para posição, rotação suave, look-ahead por velocidade, colisão suave, FOV dinâmico.
## Em combate (ataque): menos look-ahead e rotação mais estável.

# ---- Posição (spring) ----
@export_group("Posição")
@export var spring_stiffness := 58.0
@export var spring_damping := 15.0
@export var max_velocity := 22.0

# ---- Rotação ----
@export_group("Rotação")
@export var rotation_smooth := 11.0
@export var rotation_smooth_combat := 18.0
## Nó para onde a câmera sempre olha (ex.: Marker3D na frente do personagem). Se vazio, usa o pivot do player.
@export var look_at_marker: Node3D = null

# ---- Look-ahead (antecipação pelo movimento) ----
@export_group("Look-ahead")
@export var look_ahead_enabled := true
@export var look_ahead_scale := 0.06
@export var look_ahead_max := 0.5
## Reduz o look-ahead durante o ataque (evita câmera “correndo” em combate).
@export var look_ahead_combat_scale := 0.15

# ---- Colisão ----
@export_group("Colisão")
@export var enable_collision_check := true
@export var collision_margin := 0.35
@export var collision_rays := 3

# ---- FOV dinâmico ----
@export_group("FOV")
@export var fov_dynamic_enabled := true
@export var fov_sprint_add := 3.0
@export var fov_speed_threshold := 10.0
@export var fov_smooth := 6.0

var _position_velocity := Vector3.ZERO
var _base_fov := 75.0
var _current_fov := 75.0
var _is_in_combat := false


func _ready() -> void:
	_base_fov = fov
	_current_fov = _base_fov
	var player := _get_player()
	if player:
		var target := _get_target_global_position(player)
		global_position = target
		_position_velocity = Vector3.ZERO
		_align_rotation_to(_get_look_at_position(player))


func _physics_process(delta: float) -> void:
	var player := _get_player()
	if not player:
		return

	_is_in_combat = player.get("is_attacking") == true if "is_attacking" in player else false

	var look_at_pos := _get_look_at_position(player)
	var pivot = player.get_camera_pivot_global()
	var target_pos := _get_target_global_position(player)

	# Look-ahead: desloca o alvo no sentido da velocidade (reduzido em combate)
	if look_ahead_enabled and player is CharacterBody3D:
		var vel := (player as CharacterBody3D).velocity
		var horz := Vector3(vel.x, 0.0, vel.z)
		var len := horz.length()
		if len > 0.5:
			var scale_eff := look_ahead_scale * (look_ahead_combat_scale if _is_in_combat else 1.0)
			var ahead = horz.normalized() * min(len * scale_eff, look_ahead_max)
			target_pos += ahead

	if enable_collision_check:
		target_pos = _resolve_collision(pivot, target_pos)

	# Spring: aceleração suave em direção ao alvo
	var diff := target_pos - global_position
	var force := diff * spring_stiffness - _position_velocity * spring_damping
	_position_velocity += force * delta
	_position_velocity = _position_velocity.limit_length(max_velocity)
	global_position += _position_velocity * delta

	# Rotação: mais rápida em combate para acompanhar o personagem
	var rot_smooth := rotation_smooth_combat if _is_in_combat else rotation_smooth
	var ideal_basis := Basis.looking_at(look_at_pos - global_position, Vector3.UP)
	var rot_k := 1.0 - exp(-rot_smooth * delta)
	global_transform.basis = global_transform.basis.slerp(ideal_basis, rot_k)

	# FOV dinâmico ao correr (estável em combate)
	if fov_dynamic_enabled and not _is_in_combat:
		var vel_len := (player as CharacterBody3D).velocity.length() if player is CharacterBody3D else 0.0
		var t = clamp((vel_len - fov_speed_threshold) / 6.0, 0.0, 1.0)
		var target_fov = _base_fov + fov_sprint_add * t
		var fov_k := 1.0 - exp(-fov_smooth * delta)
		_current_fov = lerp(_current_fov, target_fov, fov_k)
		fov = _current_fov
	elif fov_dynamic_enabled and _is_in_combat:
		var fov_k := 1.0 - exp(-fov_smooth * delta)
		_current_fov = lerp(_current_fov, _base_fov, fov_k)
		fov = _current_fov


func _get_player() -> Node:
	var p := get_parent()
	return p if p is CharacterBody3D else null


func _get_target_global_position(player: Node) -> Vector3:
	if not player.has_method("get_camera_target_global_position"):
		return global_position
	return player.get_camera_target_global_position()


func _get_look_at_position(player: Node) -> Vector3:
	if look_at_marker and is_instance_valid(look_at_marker):
		return look_at_marker.global_position
	return player.get_camera_pivot_global()

func _align_rotation_to(point: Vector3) -> void:
	global_transform.basis = Basis.looking_at(point - global_position, Vector3.UP)


func _resolve_collision(from: Vector3, to: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if not space:
		return to

	var dir := (to - from)
	var dist := dir.length()
	if dist <= 0.001:
		return to
	dir /= dist

	var exclude: Array = []
	var parent := get_parent()
	if parent is PhysicsBody3D:
		exclude.append((parent as PhysicsBody3D).get_rid())

	# Múltiplos raios (centro, cima, baixo) para cantos e rampas
	var hit_dist := dist
	var step := 0.25
	for i in range(collision_rays):
		var t := (i - (collision_rays - 1) * 0.5) * step
		var origin := from + Vector3.UP * t * 0.5
		var end_pos := origin + dir * dist
		var query := PhysicsRayQueryParameters3D.create(origin, end_pos)
		query.exclude = exclude
		var result := space.intersect_ray(query)
		if not result.is_empty():
			var d := origin.distance_to(result.position)
			hit_dist = minf(hit_dist, d)

	var safe_dist = max(hit_dist - collision_margin, 0.0)
	return from + dir * safe_dist
