# ChunkCollisionBuilder.gd
# Cria colisão HeightMapShape3D e LOD por chunk. Usado por InfiniteWorldGenerator.

class_name ChunkCollisionBuilder

static func create_heightmap_shape(chunk_data, lod_level: int, chunk_size: int) -> Dictionary:
	if chunk_data.heights.is_empty() or chunk_data.terrain_subs <= 0:
		return {}
	var full_size = chunk_data.terrain_subs + 1
	var step := 1
	match lod_level:
		1: step = 2
		2: step = 4
	var w := int((float(chunk_data.terrain_subs) / float(step)) + 1.0)
	var d := w
	var n := w * d
	var map_data := PackedFloat32Array()
	map_data.resize(n)
	var shape_scale := float(chunk_size) / float(w - 1) if w > 1 else 1.0
	var inv_scale := 1.0 / shape_scale if shape_scale > 0.001 else 1.0
	var idx := 0
	for z in range(0, full_size, step):
		for x in range(0, full_size, step):
			var src_idx = z * full_size + x
			map_data[idx] = chunk_data.heights[src_idx] * inv_scale
			idx += 1
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = map_data
	return { "shape": shape, "scale": shape_scale }


## Cria StaticBody3D com HeightMapShape3D. Quem chama deve add_child e atualizar chunk_data.terrain_collision / chunks_with_collision.
static func create_chunk_collision(world_gen: InfiniteWorldGenerator, chunk_data, start_pos: Vector3) -> StaticBody3D:
	var lod_level := 0
	if world_gen.enable_collision_lod and world_gen.player:
		var dist := world_gen.get_chunk_distance_to_player(chunk_data.chunk_pos)
		if dist <= world_gen.collision_lod_near:
			lod_level = 0
		elif dist <= world_gen.collision_lod_far:
			lod_level = 1
		else:
			lod_level = 2
	chunk_data.collision_lod_level = lod_level

	var result := create_heightmap_shape(chunk_data, lod_level, world_gen.chunk_size)
	if result.is_empty():
		return null
	var static_body := StaticBody3D.new()
	static_body.position = start_pos + Vector3(world_gen.chunk_size * 0.5, 0.0, world_gen.chunk_size * 0.5)
	var s: float = result.get("scale", 1.0)
	static_body.scale = Vector3(s, s, s)
	var collision := CollisionShape3D.new()
	collision.shape = result.get("shape", null)
	static_body.add_child(collision)
	return static_body


static func create_simplified_collision(world_gen: InfiniteWorldGenerator, start_pos: Vector3, subdivisions: int) -> Shape3D:
	var chunk_size: int = world_gen.chunk_size
	var step := float(chunk_size) / subdivisions
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := PackedVector3Array()
	verts.resize((subdivisions + 1) * (subdivisions + 1))
	var idx := 0
	for z in range(subdivisions + 1):
		for x in range(subdivisions + 1):
			var px := start_pos.x + x * step
			var pz := start_pos.z + z * step
			verts[idx] = Vector3(px, world_gen.get_terrain_height(px, pz), pz)
			idx += 1
	var row_w := subdivisions + 1
	for z in range(subdivisions):
		var row_base := z * row_w
		for x in range(subdivisions):
			var i := row_base + x
			st.set_uv(Vector2.ZERO)
			st.add_vertex(verts[i])
			st.set_uv(Vector2.RIGHT)
			st.add_vertex(verts[i + 1])
			st.set_uv(Vector2.DOWN)
			st.add_vertex(verts[i + row_w])
			st.set_uv(Vector2.RIGHT)
			st.add_vertex(verts[i + 1])
			st.set_uv(Vector2.ONE)
			st.add_vertex(verts[i + row_w + 1])
			st.set_uv(Vector2.DOWN)
			st.add_vertex(verts[i + row_w])
	st.generate_normals()
	return st.commit().create_trimesh_shape()
