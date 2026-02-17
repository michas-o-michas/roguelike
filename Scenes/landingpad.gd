
extends Interactable

enum PadType {
	IN,
	OUT
}

@export var destination: PackedScene
@export var Type:PadType = PadType.IN

func interact(interactor: Node) -> void:
	print("Interagindo")
	destination.original_position = global_position

func on_focus_enter():
	$SubViewport/Label.show()

func on_focus_exit() -> void:
	$SubViewport/Label.hide()
