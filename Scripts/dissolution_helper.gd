extends Node
## Efeito de decomposição (dissolution): mantém a cor do mesh, pedaços grandes, borda azul clara.
## Uso: DissolutionHelper.run(node, 1.4)

const DISSOLUTION_MAT_PATH := "res://materials/dissolution.gdshader"

func run(target: Node, duration: float = 5.0, remove_after: bool = true) -> void:
	if target == null:
		return
	var template := load("res://materials/dissolution_material.tres") as ShaderMaterial
	if template == null:
		template = _make_dissolution_material()
	var materials: Array[ShaderMaterial] = []
	_apply_to_node(target, template, materials)
	if materials.is_empty():
		if remove_after:
			target.queue_free()
		return
	var tween := target.create_tween()
	# Curva linear: dissolve progressivo do início ao fim, bem visível
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(
		func(v: float) -> void:
			for m in materials:
				m.set_shader_parameter("dissolve", v),
		0.0, 1.0, duration
	)
	if remove_after:
		tween.tween_callback(target.queue_free)

func _apply_to_node(node: Node, template: ShaderMaterial, out_materials: Array[ShaderMaterial]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				var dup := template.duplicate() as ShaderMaterial
				var orig := mesh.surface_get_material(i)
				if orig is BaseMaterial3D:
					var base := orig as BaseMaterial3D
					dup.set_shader_parameter("albedo_color", base.albedo_color)
					if base.albedo_texture != null:
						dup.set_shader_parameter("albedo_texture", base.albedo_texture)
				else:
					dup.set_shader_parameter("albedo_color", Color(0.5, 0.45, 0.4, 1.0))
				mi.set_surface_override_material(i, dup)
				out_materials.append(dup)
	for child in node.get_children():
		_apply_to_node(child, template, out_materials)

func _make_dissolution_material() -> ShaderMaterial:
	var shader := load(DISSOLUTION_MAT_PATH) as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("fragment_scale", 0.11)
	mat.set_shader_parameter("edge_width", 0.09)
	mat.set_shader_parameter("edge_color", Color(0.5, 0.82, 1, 1))
	mat.set_shader_parameter("edge_emissive", 0.25)
	return mat
