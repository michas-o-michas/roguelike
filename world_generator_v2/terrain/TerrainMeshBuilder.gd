# TerrainMeshBuilder.gd
# Constrói a mesh do terreno e o material compartilhado. Usado por InfiniteWorldGenerator.

class_name TerrainMeshBuilder

static func build_terrain_mesh(world_gen: InfiniteWorldGenerator, chunk_data, start_pos: Vector3) -> void:
	var chunk_size: int = world_gen.chunk_size
	var terrain_subs: int = mini(world_gen.terrain_subdivisions, 12)
	var step := float(chunk_size) / terrain_subs
	var vert_count := (terrain_subs + 1) * (terrain_subs + 1)

	var vertices := PackedVector3Array()
	vertices.resize(vert_count)
	var colors := PackedColorArray()
	colors.resize(vert_count)
	chunk_data.heights.resize(vert_count)
	chunk_data.terrain_subs = terrain_subs

	var idx := 0
	for z in range(terrain_subs + 1):
		var pos_z_world := start_pos.z + z * step
		var local_z := snappedf(z * step, 0.001)
		for x in range(terrain_subs + 1):
			var pos_x_world := start_pos.x + x * step
			var local_x := snappedf(x * step, 0.001)
			var h := world_gen.get_terrain_height(pos_x_world, pos_z_world)
			chunk_data.heights[idx] = h
			vertices[idx] = Vector3(local_x, h, local_z)
			colors[idx] = world_gen.get_terrain_color(pos_x_world, pos_z_world, h)
			idx += 1

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var row_width := terrain_subs + 1
	for z in range(terrain_subs):
		var row_base := z * row_width
		for x in range(terrain_subs):
			var i := row_base + x
			var i1 := i + 1
			var i_next := i + row_width
			var i_next1 := i_next + 1
			st.set_color(colors[i])
			st.add_vertex(vertices[i])
			st.set_color(colors[i1])
			st.add_vertex(vertices[i1])
			st.set_color(colors[i_next])
			st.add_vertex(vertices[i_next])
			st.set_color(colors[i1])
			st.add_vertex(vertices[i1])
			st.set_color(colors[i_next1])
			st.add_vertex(vertices[i_next1])
			st.set_color(colors[i_next])
			st.add_vertex(vertices[i_next])
	st.generate_normals()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	if world_gen.use_shared_material and world_gen.shared_terrain_material:
		mesh_instance.material_override = world_gen.shared_terrain_material
	else:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		mesh_instance.material_override = mat
	mesh_instance.position = start_pos
	world_gen.add_child(mesh_instance)
	chunk_data.terrain_mesh = mesh_instance


static func get_albedo_texture_from_material(m: Material) -> Texture2D:
	if m is StandardMaterial3D:
		var std := m as StandardMaterial3D
		if std.albedo_texture:
			return std.albedo_texture
	return null


static func get_terrain_layer_texture(world_gen: InfiniteWorldGenerator, m: Material) -> Texture2D:
	var tex := get_albedo_texture_from_material(m)
	if tex:
		return tex
	if not world_gen.get("_terrain_white_fallback"):
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		world_gen.set("_terrain_white_fallback", ImageTexture.create_from_image(img))
	return world_gen.get("_terrain_white_fallback")


static func create_terrain_material(world_gen: InfiniteWorldGenerator) -> Material:
	var world_theme = world_gen.world_theme
	if world_theme and world_theme.use_terrain_textures:
		var has_any := (
			world_theme.material_sand != null or world_theme.material_grass != null
			or world_theme.material_rock != null or world_theme.material_snow != null
		)
		if has_any:
			var shader_path := "res://world_generator_v2/shader/terrain_textured.gdshader"
			if not ResourceLoader.exists(shader_path):
				shader_path = "res://shaders/terrain_textured.gdshader"
			var shader_res := load(shader_path) as Shader
			if shader_res:
				var mat := ShaderMaterial.new()
				mat.shader = shader_res
				mat.set_shader_parameter("texture_sand", get_terrain_layer_texture(world_gen, world_theme.material_sand))
				mat.set_shader_parameter("texture_grass", get_terrain_layer_texture(world_gen, world_theme.material_grass))
				mat.set_shader_parameter("texture_rock", get_terrain_layer_texture(world_gen, world_theme.material_rock))
				mat.set_shader_parameter("texture_snow", get_terrain_layer_texture(world_gen, world_theme.material_snow))
				mat.set_shader_parameter("water_level", world_gen.water_level)
				mat.set_shader_parameter("beach_level", world_gen.beach_level + 3.0)
				mat.set_shader_parameter("grass_level", world_gen.grass_level)
				mat.set_shader_parameter("rock_start", world_gen.rock_start_height)
				mat.set_shader_parameter("rock_end", world_gen.rock_start_height + world_gen.rock_thickness)
				var snow_start_val := (world_gen.rock_start_height + world_gen.rock_thickness) if world_gen.snow_start_height < 0 else world_gen.snow_start_height
				mat.set_shader_parameter("snow_start", snow_start_val)
				mat.set_shader_parameter("transition_width", maxf(world_theme.transition_width, 2.0))
				var softness := 2.0
				if "transition_softness" in world_theme:
					softness = world_theme.transition_softness
				var noise_amt := 2.0
				if "transition_noise" in world_theme:
					noise_amt = world_theme.transition_noise
				mat.set_shader_parameter("transition_softness", clampf(softness, 0.5, 3.0))
				mat.set_shader_parameter("transition_noise", clampf(noise_amt, 0.0, 5.0))
				mat.set_shader_parameter("texture_scale_uv", world_theme.texture_scale if world_theme.texture_scale > 0 else 0.05)
				mat.set_shader_parameter("use_vertex_cwolor_tint", true)
				return mat
			else:
				push_warning("Shader de terreno não encontrado, usando cor por vértice.")
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	return mat
