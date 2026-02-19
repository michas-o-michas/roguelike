extends Node
class_name PropWithVariants

## Carrega uma variante visual aleatória ao iniciar e esconde o visual padrão.
## Use na mesma cena que ResourceNode/Interactable: colisão e lógica ficam na raiz.

@export var variant_set: PropVariantSet
## Nó onde a variante será adicionada (ex.: VisualRoot).
@export var visual_root_path: NodePath
## Nós do visual padrão a esconder quando uma variante for usada (ex.: Leaves, Tree_3).
@export var default_visual_paths: Array[NodePath] = []

var _visual_root: Node3D

func _ready() -> void:
	_visual_root = get_node_or_null(visual_root_path) as Node3D
	if _visual_root == null:
		return
	if variant_set == null or not variant_set.has_variants():
		return

	var scene: PackedScene = variant_set.get_random_variant()
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	if instance == null:
		return

	# Reparenta a instância para o visual root (mantém transform global se quiser depois)
	instance.set_as_top_level(false)
	_visual_root.add_child(instance)
	var tree := get_tree()
	instance.owner = tree.edited_scene_root if Engine.is_editor_hint() else tree.current_scene

	# Esconde o visual padrão
	for path in default_visual_paths:
		var n := get_node_or_null(path)
		if n is Node3D:
			(n as Node3D).visible = false
