extends Interactable
## Pad dentro da dungeon: ao interagir (E), volta para o mesmo lugar do mapa de onde entrou.

func _ready() -> void:
	if interact_label.is_empty():
		interact_label = "Voltar ao mapa"

func interact(_interactor: Node) -> void:
	if DungeonManager:
		DungeonManager.exit_dungeon()

func on_focus_enter() -> void:
	if has_node("SubViewport/Label"):
		$SubViewport/Label.show()

func on_focus_exit() -> void:
	if has_node("SubViewport/Label"):
		$SubViewport/Label.hide()
