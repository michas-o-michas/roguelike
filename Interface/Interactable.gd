class_name Interactable
extends Node3D

## Texto exibido no prompt (pode ser sobrescrito em cada filho)
@export var interact_label: String = "Interact"

## Retorna o texto do prompt; sobrescreva nos filhos para calcular na hora (ex.: landing pad).
func get_display_label() -> String:
	return interact_label

## Chamado pelo player ao pressionar E
func interact(interactor: Node) -> void:
	pass  # sobrescreva nos filhos

## Opcional: chamado quando o raycast entra/sai (hover)
func on_focus_enter() -> void:
	pass

func on_focus_exit() -> void:
	pass
