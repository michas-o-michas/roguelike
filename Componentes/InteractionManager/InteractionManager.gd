extends Node

@export var ray_length: float = 3.0
@export var prompt_label: Label = null  # Label 3D ou CanvasLayer

@export var camera: Camera3D
@export var ray_cast_3d: RayCast3D 

var current_interactable: Interactable = null

func _physics_process(_delta: float) -> void:
	_do_raycast()

func _do_raycast() -> void:

	if ray_cast_3d:
		var collider = ray_cast_3d.get_collider()

		# Procura um Interactable no collider ou nos seus pais
		var found: Interactable = _find_interactable(collider)

		if found:
			if found != current_interactable:
				if current_interactable:
					current_interactable.on_focus_exit()
				current_interactable = found
				current_interactable.on_focus_enter()
			_show_prompt(found.interact_label)
			return

	# Nada encontrado
	if current_interactable:
		current_interactable.on_focus_exit()
		current_interactable = null
	_hide_prompt()

func _find_interactable(node: Node) -> Interactable:
	# Sobe na árvore procurando um Interactable
	var n := node
	while n:
		if n is Interactable:
			return n as Interactable
		# Também checa filhos diretos (caso Interactable seja filho do CollisionShape)
		for child in n.get_children():
			if child is Interactable:
				return child as Interactable
		n = n.get_parent()
	return null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_interactable:
		current_interactable.interact(owner)

func _show_prompt(text: String) -> void:
	if prompt_label:
		prompt_label.text = "[E] " + text
		prompt_label.visible = true

func _hide_prompt() -> void:
	if prompt_label:
		prompt_label.visible = false
