extends Node
## Aplica balanço de vento nas folhas (opaco: mantém cores e texturas, sem transparência).

@export var mesh_instances_to_animate: Array[NodePath] = []

## Se preenchido e mesh_instances_to_animate vazio, aplica vento em todos os MeshInstance3D sob este nó (útil com PropWithVariants).
@export var visual_root_path: NodePath

## Aplicar vento só nas folhas: primeiro mesh/superfície 0 = tronco (parado); resto = folhas (vento).
@export var apply_only_to_leaves: bool = true

## Força do balanço (quanto maior, mais movimento).
@export_range(0.0, 0.5, 0.01) var wind_strength: float = 0.12
## Velocidade da animação do vento.
@export_range(0.5, 4.0, 0.1) var wind_speed: float = 1.5
## Base (Y): abaixo disso quase não balança. 0 = pé em Y=0. Se nada mexer, use -0.5 ou -1.
@export_range(-5.0, 5.0, 0.05) var wind_base_height: float = -0.5
## Escala: a partir de que altura o vento sobe (acima da base).
@export_range(0.05, 2.0, 0.05) var wind_height_scale: float = 0.4
## Quanto maior, mais vento só no topo (base quase parada).
@export_range(1.0, 6.0, 0.1) var wind_height_power: float = 3.5

var _wind_shader: Shader
var _opaque_texture_cache: Dictionary = {}

func _ready() -> void:
	_wind_shader = load("res://Scenes/tree_wind.gdshader") as Shader
	if _wind_shader == null:
		return
	if not mesh_instances_to_animate.is_empty():
		for path in mesh_instances_to_animate:
			var node = get_node_or_null(path)
			if node is MeshInstance3D:
				_apply_wind_to_mesh_instance(node as MeshInstance3D)
	elif visual_root_path != NodePath():
		# Variantes: meshes são adicionados pelo PropWithVariants; aplicar vento no próximo frame.
		call_deferred("_apply_wind_to_visual_root")


func _apply_wind_to_visual_root() -> void:
	var root := get_node_or_null(visual_root_path) as Node
	if root == null:
		return
	var list: Array[Node] = []
	_collect_mesh_instances(root, list)
	var idx := 0
	for n in list:
		if n is MeshInstance3D:
			_apply_wind_to_mesh_instance(n as MeshInstance3D, idx)
			idx += 1


func _collect_mesh_instances(node: Node, out: Array[Node]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_mesh_instances(c, out)


func _apply_wind_to_mesh_instance(mi: MeshInstance3D, mesh_index_in_tree: int = 0) -> void:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return
	var surface_count := mesh.get_surface_count()
	var start_surface := 0
	if apply_only_to_leaves:
		if mesh_index_in_tree == 0 and surface_count > 1:
			# Vários materiais: superfície 0 = tronco (fixo), 1+ = folhas (vento)
			start_surface = 1
		# Se só tem 1 superfície, aplica vento nela; se mesh_index >= 1, aplica em todas
	for i in range(start_surface, surface_count):
		# Respeita override do MeshInstance (cores que você alterou nas árvores).
		var orig: Material = mi.get_surface_override_material(i)
		if orig == null:
			orig = mesh.surface_get_material(i)
		if orig == null:
			continue
		var wind_mat := _make_wind_material(orig)
		if wind_mat != null:
			mi.set_surface_override_material(i, wind_mat)


func _make_wind_material(orig: Material) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _wind_shader
	# Sempre preservar cores e textura do material original (nunca sobrescrever).
	if orig is StandardMaterial3D:
		var std := orig as StandardMaterial3D
		mat.set_shader_parameter("albedo_color", std.albedo_color)
		if std.albedo_texture != null:
			var opaque_tex := _get_opaque_texture(std.albedo_texture)
			mat.set_shader_parameter("albedo_texture", opaque_tex if opaque_tex != null else std.albedo_texture)
		else:
			mat.set_shader_parameter("albedo_texture", null)
	else:
		mat.set_shader_parameter("albedo_color", Color.WHITE)
		mat.set_shader_parameter("albedo_texture", null)
	# Parâmetros de vento (expostos no Inspector)
	mat.set_shader_parameter("wind_strength", wind_strength)
	mat.set_shader_parameter("wind_speed", wind_speed)
	mat.set_shader_parameter("wind_base_height", wind_base_height)
	mat.set_shader_parameter("wind_height_scale", wind_height_scale)
	mat.set_shader_parameter("wind_height_power", wind_height_power)
	return mat


func _get_opaque_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _opaque_texture_cache.has(tex.get_rid()):
		return _opaque_texture_cache[tex.get_rid()]
	var opaque := _make_texture_opaque(tex)
	_opaque_texture_cache[tex.get_rid()] = opaque
	return opaque


func _make_texture_opaque(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if not (tex is ImageTexture):
		return null
	var img: Image = (tex as ImageTexture).get_image()
	if img == null:
		return null
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	return ImageTexture.create_from_image(img)
