extends Node
## Sistema de mira e interação (E).
## Uma única regra: o raycast é a linha do centro da tela — mesma direção do crosshair e dos projéteis.
## Alcance fixo (ex.: 20 m), não depende do zoom da câmera.

## Label fixo no topo (nome · ferramenta).
@export var prompt_label: Label = null
## Painel flutuante "E para coletar" (posicionado na tela conforme o alvo).
@export var prompt_label_floating: Control = null
@export var camera: Camera3D
@export var ray_cast_3d: RayCast3D

## Ponto de onde o ray sai. Se vazio, sai do plano da câmera (e o jogador é excluído do ray).
@export var ray_origin_marker: Node3D = null
## Alcance em metros. Fixo, não depende do zoom.
@export var ray_length: float = 20.0
## Offset em pixels do centro da tela (0,0 = centro exato).
@export var aim_screen_offset: Vector2 = Vector2.ZERO
@export var crosshair_control: Control = null

@export var outline_enabled := true
@export var outline_color := Color(0.3, 0.85, 0.4)
@export var outline_scale := 1.03

var current_interactable: Interactable = null
var _outline_material: StandardMaterial3D
var _outline_copies: Array[MeshInstance3D] = []


func _ready() -> void:
	if ray_cast_3d and owner is CollisionObject3D:
		ray_cast_3d.add_exception(owner)
	# Ray em mundo: não herdar transform do pai (evita gambiarra com câmera/pivot).
	if ray_cast_3d:
		ray_cast_3d.top_level = true
	_outline_material = StandardMaterial3D.new()
	_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_material.albedo_color = outline_color
	_outline_material.roughness = 1.0
	_outline_material.metallic = 0.0


func _physics_process(_delta: float) -> void:
	_update_aim_ray()
	_update_crosshair_position()
	_do_raycast()


func _do_raycast() -> void:
	if not ray_cast_3d:
		_hide_prompt()
		return

	var collider = ray_cast_3d.get_collider()
	var found: Interactable = _find_interactable(collider)

	if found:
		if found != current_interactable:
			_clear_outline()
			if current_interactable:
				_focus_exit_resource(current_interactable)
				current_interactable.on_focus_exit()
			current_interactable = found
			current_interactable.on_focus_enter()
			if outline_enabled:
				_apply_outline(found)
		var resource_node: ResourceNode = _get_resource_node(found)
		if resource_node and ray_cast_3d.is_colliding():
			resource_node.raycast_position = ray_cast_3d.get_collision_point()
		var world_pos: Vector3 = ray_cast_3d.get_collision_point() if ray_cast_3d.is_colliding() else found.global_position
		_show_prompt(_get_prompt_text(found), world_pos)
		return

	_clear_outline()
	if current_interactable:
		_focus_exit_resource(current_interactable)
		current_interactable.on_focus_exit()
		current_interactable = null
	_hide_prompt()


## Regra única: direção = centro da tela (project_ray_normal). Origem = marker ou câmera.
func _update_aim_ray() -> void:
	if not camera or not ray_cast_3d:
		return
	var vp := camera.get_viewport()
	if not vp:
		return

	var center := vp.get_visible_rect().size / 2.0 + aim_screen_offset
	# Direção exata do centro da tela — mesma linha do crosshair e dos projéteis.
	var direction := camera.project_ray_normal(center).normalized()
	var origin: Vector3
	if ray_origin_marker and is_instance_valid(ray_origin_marker):
		origin = ray_origin_marker.global_position
	else:
		origin = camera.project_ray_origin(center)

	ray_cast_3d.global_position = origin
	# -Z do RayCast3D = direction (para target_position (0,0,-ray_length) ir para frente).
	ray_cast_3d.global_transform.basis = Basis.looking_at(direction, Vector3.UP)
	ray_cast_3d.target_position = Vector3(0, 0, -ray_length)
	ray_cast_3d.force_raycast_update()


func _update_crosshair_position() -> void:
	if not crosshair_control or not camera:
		return
	var vp := camera.get_viewport()
	if not vp:
		return
	# Mesmo centro exato usado no raycast (project_ray_normal) — em coordenadas globais da tela.
	var viewport_center := vp.get_visible_rect().size / 2.0 + aim_screen_offset
	var size := crosshair_control.size
	# Sempre posicionar em global para coincidir com o centro do viewport (onde o raycast “aponta”).
	crosshair_control.global_position = viewport_center - size / 2.0


func _get_prompt_text(interactable: Interactable) -> String:
	var parent = interactable.get_parent()
	if parent is ResourceNode:
		var rn: ResourceNode = parent as ResourceNode
		var name_text := interactable.get_display_label()
		var tool_text := rn.get_required_tool_label()
		if tool_text.is_empty():
			return name_text
		return name_text + " · " + tool_text
	return interactable.get_display_label()


func _get_resource_node(interactable: Interactable) -> ResourceNode:
	var parent = interactable.get_parent()
	return parent as ResourceNode if parent is ResourceNode else null


func _focus_exit_resource(interactable: Interactable) -> void:
	var resource_node := _get_resource_node(interactable)
	if resource_node and resource_node.has_method("remove_health_bar"):
		resource_node.remove_health_bar()


## Só considera o nó atingido e seus filhos — não sobe ao pai (evita "E Teleportar" ao mirar em mobs).
func _find_interactable(node: Node) -> Interactable:
	if not node:
		return null
	if node is Interactable:
		return node as Interactable
	for child in node.get_children():
		if child is Interactable:
			return child as Interactable
		var found := _find_interactable(child)
		if found:
			return found
	return null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_interactable:
		current_interactable.interact(owner)


func _show_prompt(text: String, world_pos: Vector3) -> void:
	if prompt_label:
		prompt_label.text = text
		prompt_label.visible = true
		var box: CanvasItem = prompt_label.get_parent()
		if box:
			box.visible = true
	if prompt_label_floating and camera:
		prompt_label_floating.visible = true
		var viewport_size := camera.get_viewport().get_visible_rect().size
		var screen_pos: Vector2 = camera.unproject_position(world_pos)
		screen_pos += Vector2(156, -128)
		screen_pos.x = clampf(screen_pos.x, 80, viewport_size.x - 80)
		screen_pos.y = clampf(screen_pos.y, 40, viewport_size.y - 40)
		var sz := prompt_label_floating.size
		if sz.x <= 0:
			sz = prompt_label_floating.custom_minimum_size
		prompt_label_floating.position = screen_pos - sz / 2


func _hide_prompt() -> void:
	if prompt_label:
		prompt_label.visible = false
		var box: CanvasItem = prompt_label.get_parent()
		if box:
			box.visible = false
	if prompt_label_floating:
		prompt_label_floating.visible = false


func _apply_outline(interactable: Interactable) -> void:
	_outline_material.albedo_color = outline_color
	var root: Node = interactable.get_parent() if interactable.get_parent() is ResourceNode else interactable
	var meshes: Array[MeshInstance3D] = _collect_mesh_instances(root)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.skeleton = mi.skeleton
		copy.material_override = _outline_material
		var scale_basis := Basis().scaled(Vector3(outline_scale, outline_scale, outline_scale))
		copy.transform = mi.transform * Transform3D(scale_basis, Vector3.ZERO)
		mi.get_parent().add_child(copy)
		copy.top_level = false
		_outline_copies.append(copy)


func _clear_outline() -> void:
	for copy in _outline_copies:
		if is_instance_valid(copy):
			copy.queue_free()
	_outline_copies.clear()


func _collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_collect_mesh_instances(child))
	return out
