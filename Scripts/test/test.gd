extends Node3D

@export var grass_mesh: Mesh
@export var grass_material: Material

@export var radius: float = 200.0
@export var spacing: float = 0.7

@export var chunk_size: float = 20.0
@export var view_distance: float = 80.0

@export var lod1_distance: float = 30.0
@export var lod2_distance: float = 60.0

var player: Node3D
var chunks = []

func _ready():
	player = get_tree().get_first_node_in_group("player")
	generate_chunks()

func _process(delta):
	update_chunks()

func generate_chunks():
	var area = radius * 2

	for x in range(int(area / chunk_size)):
		for z in range(int(area / chunk_size)):

			var chunk_pos = Vector3(
				x * chunk_size - radius,
				0,
				z * chunk_size - radius
			)

			create_chunk(chunk_pos)

func create_chunk(position: Vector3):

	var points = []

	for x in range(int(chunk_size / spacing)):
		for z in range(int(chunk_size / spacing)):

			var px = position.x + x * spacing
			var pz = position.z + z * spacing

			if Vector2(px, pz).length() > radius:
				continue

			points.append(Vector3(px, 0, pz))

	if points.is_empty():
		return

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = grass_mesh
	mm.instance_count = points.size()

	for i in range(points.size()):
		var t = Transform3D()
		t.origin = points[i]
		t.basis = Basis(Vector3.UP, randf() * TAU)
		mm.set_instance_transform(i, t)

	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = grass_material

	add_child(mmi)

	chunks.append({
		"node": mmi,
		"position": position,
		"total_instances": points.size()
	})

func update_chunks():
	if not player:
		return

	for chunk in chunks:
		var node: MultiMeshInstance3D = chunk["node"]
		var pos: Vector3 = chunk["position"]
		var total: int = chunk["total_instances"]

		var dist = player.global_position.distance_to(pos)

		if dist > view_distance:
			node.visible = false
			continue

		node.visible = true

		# LOD POR DENSIDADE
		var factor = 1.0

		if dist > lod2_distance:
			factor = 0.2
		elif dist > lod1_distance:
			factor = 0.5

		var new_count = int(total * factor)

		node.multimesh.instance_count = max(1, new_count)
