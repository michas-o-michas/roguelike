class_name Interactable
extends Node3D

## Texto exibido no prompt (pode ser sobrescrito em cada filho)
@export var interact_label: String = "Interact"

## Chamado pelo player ao pressionar E
func interact(interactor: Node) -> void:
	print("PADRAO Interactable.gd: Interagindo...")
	pass  # sobrescreva nos filhos

## Opcional: chamado quando o raycast entra/sai (hover)
func on_focus_enter() -> void:
	print("PADRAO Interactable.gd: Raycast entrou na area...")
	pass

func on_focus_exit() -> void:
	print("PADRAO Interactable.gd: Raycast saiu da area...")
