extends Interactable
## Pad no mapa/templo: ao interagir (E), entra na dungeon. Usa DungeonManager.

@export var dungeon_path: NodePath = NodePath("Main/Dungeon_Lv1")
@export var spawn_marker_path: NodePath = NodePath("Main/Dungeon_Lv1/EntranceMarker")

func _ready() -> void:
	if interact_label.is_empty():
		interact_label = "Entrar na dungeon"

func interact(_interactor: Node) -> void:
	var root := get_tree().root
	var dungeon: Node = root.get_node_or_null(dungeon_path)
	var spawn_marker: Node3D = root.get_node_or_null(spawn_marker_path) as Node3D
	if not dungeon:
		push_warning("DungeonEntrancePad: dungeon não encontrado no path: %s" % dungeon_path)
		return
	if not spawn_marker:
		push_warning("DungeonEntrancePad: spawn marker não encontrado: %s" % spawn_marker_path)
		return
	if not DungeonManager:
		push_error("DungeonEntrancePad: autoload DungeonManager não encontrado.")
		return
	DungeonManager.enter_dungeon(dungeon, spawn_marker.global_position)

func on_focus_enter() -> void:
	if has_node("SubViewport/Label"):
		$SubViewport/Label.show()

func on_focus_exit() -> void:
	if has_node("SubViewport/Label"):
		$SubViewport/Label.hide()
