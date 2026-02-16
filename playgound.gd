extends Node3D

@export var grass_mesh: Mesh
@export var area_size: float = 50.0
@export var grass_count: int = 2000

@export var min_scale: float = 1.2
@export var max_scale: float = 2.0

@export var render_distance: float = 40.0

@export var wind_strength: float = 0.05
@export var wind_speed: float = 2.0

var multimesh_instance: MultiMeshInstance3D
var material: ShaderMaterial

func _ready():
	_create_grass()
	_apply_wind_shader()

func _create_grass():
	multimesh_instance = MultiMeshInstance3D.new()
	add_child(multimesh_instance)
	multimesh_instance.position.y = .9
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = grass_count
	multimesh.mesh = grass_mesh

	multimesh_instance.multimesh = multimesh

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for i in grass_count:
		var transform = Transform3D()
		
		# posição aleatória na área
		transform.origin = Vector3(
			rng.randf_range(-area_size, area_size),
			0,
			rng.randf_range(-area_size, area_size)
		)

			# rotação aleatória no Y
		var rotation_y = Basis(Vector3.UP, rng.randf_range(0, TAU))

		# rotaciona -90° no X para levantar corretamente
		var rotation_x = Basis(Vector3.RIGHT, deg_to_rad(0))

		# combina rotações
		transform.basis = rotation_y * rotation_x

		# escala
		var scale = rng.randf_range(min_scale, max_scale)
		transform.basis = transform.basis.scaled(Vector3.ONE * scale)



		multimesh.set_instance_transform(i, transform)

	# distância máxima de renderização
	multimesh_instance.visibility_range_end = render_distance

func _apply_wind_shader():
	material = ShaderMaterial.new()
	var shader = Shader.new()

	shader.code = """
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.2, 0.6, 0.2);
uniform float wind_strength = 0.05;
uniform float wind_speed = 2.0;

void vertex() {
	float height_factor = clamp(VERTEX.y, 0.0, 1.0);
	float sway = sin(TIME * wind_speed + VERTEX.x * 2.0) * wind_strength;
	VERTEX.x += sway * height_factor;
}

void fragment() {
	ALBEDO = base_color;
}
"""

	material.shader = shader

	material.set_shader_parameter("wind_strength", wind_strength)
	material.set_shader_parameter("wind_speed", wind_speed)

	multimesh_instance.material_override = material
