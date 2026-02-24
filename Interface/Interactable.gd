class_name Interactable
extends Node3D

## Texto exibido no prompt (pode ser sobrescrito em cada filho)
@export var interact_label: String = "Interact"

func _ready() -> void:
	add_to_group("interactable")

## Retorna o texto do prompt; sobrescreva nos filhos para calcular na hora (ex.: landing pad).
func get_display_label() -> String:
	return interact_label

## Chamado pelo player ao pressionar E.
## Ordem: se o pai tiver on_interact(interactor), usa; senão, se for ResourceNode, inicia coleta.
## Baús, NPCs e portais: implemente on_interact(interactor) no nó pai do Interactable.
func interact(interactor: Node) -> void:
	var parent: Node = get_parent()
	if parent.has_method("on_interact"):
		parent.on_interact(interactor)
		return
	if parent is ResourceNode:
		(parent as ResourceNode).try_start_harvest(interactor)

## Opcional: chamado quando o raycast entra/sai (hover)
func on_focus_enter() -> void:
	pass

func on_focus_exit() -> void:
	pass
