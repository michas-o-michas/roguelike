extends Node3D
## Rastro tipo "vento" na ponta da espada durante o ataque.
## Deve ser filho do WeaponHandler; recebe hand_marker e desenha um ribbon que segue a ponta.

@export var tip_offset: Vector3 = Vector3(0, 0, -0.9)  # Offset da ponta em relação ao hand_marker (local)
@export var trail_duration: float = 0.45         # Tempo que continua registrando pontos
@export var point_lifetime: float = 0.35         # Tempo que cada ponto permanece visível
@export var ribbon_width: float = 0.06          # Largura do rastro
@export var min_point_distance: float = 0.025   # Distância mínima para adicionar novo ponto
@export var trail_color: Color = Color(0.85, 0.92, 1.0, 0.7)

var tip_source: Node3D  # hand_marker
var _points: Array = []  # { position: Vector3, time: float }
var _active: bool = false
var _start_time: float = 0.0

var _mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _material: ShaderMaterial

func _ready() -> void:
	_immediate_mesh = ImmediateMesh.new()
	var shader := load("res://effects/shaders/vertex_color_alpha.gdshader") as Shader
	_material = ShaderMaterial.new()
	_material.shader = shader

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _immediate_mesh
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)

func set_tip_source(node: Node3D) -> void:
	tip_source = node

func get_tip_global() -> Vector3:
	if not is_instance_valid(tip_source):
		return global_position
	return tip_source.global_position + tip_source.global_transform.basis * tip_offset

func start_trail() -> void:
	_active = true
	_start_time = Time.get_ticks_msec() / 1000.0
	_points.clear()

func stop_trail() -> void:
	_active = false

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	if _active and is_instance_valid(tip_source):
		if now - _start_time > trail_duration:
			_active = false
		else:
			var tip := get_tip_global()
			if _points.is_empty() or tip.distance_to(_points[-1].position) >= min_point_distance:
				_points.append({ "position": tip, "time": now })

	# Remove pontos antigos
	var i := 0
	while i < _points.size():
		if now - _points[i].time > point_lifetime:
			_points.remove_at(i)
		else:
			i += 1

	_draw_ribbon(now)

func _draw_ribbon(now: float) -> void:
	_immediate_mesh.clear_surfaces()
	if _points.size() < 2:
		return

	var up := Vector3.UP
	for seg in range(_points.size() - 1):
		var a: Vector3 = _points[seg].position
		var b: Vector3 = _points[seg + 1].position
		var t_a: float = _points[seg].time
		var t_b: float = _points[seg + 1].time
		var age_a := now - t_a
		var age_b := now - t_b
		var life := point_lifetime
		var alpha_a := (1.0 - clampf(age_a / life, 0.0, 1.0)) * (1.0 - clampf(age_a / life, 0.0, 1.0))
		var alpha_b := (1.0 - clampf(age_b / life, 0.0, 1.0)) * (1.0 - clampf(age_b / life, 0.0, 1.0))

		var seg_dir := (b - a).normalized()
		var right := seg_dir.cross(up)
		if right.length_squared() < 0.01:
			right = seg_dir.cross(Vector3.FORWARD).normalized()
		else:
			right = right.normalized()
		var half_w := ribbon_width * 0.5
		var p1 := to_local(a - right * half_w)
		var p2 := to_local(a + right * half_w)
		var p3 := to_local(b + right * half_w)
		var p4 := to_local(b - right * half_w)

		_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		_immediate_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha_a))
		_immediate_mesh.surface_add_vertex(p1)
		_immediate_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha_a))
		_immediate_mesh.surface_add_vertex(p2)
		_immediate_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha_b))
		_immediate_mesh.surface_add_vertex(p3)
		_immediate_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha_a))
		_immediate_mesh.surface_add_vertex(p1)
		_immediate_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha_b))
		_immediate_mesh.surface_add_vertex(p3)
		_immediate_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha_b))
		_immediate_mesh.surface_add_vertex(p4)
		_immediate_mesh.surface_end()
