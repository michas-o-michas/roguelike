class_name Room
extends Node3D

## ID único desta dungeon. Deve ser único entre todas as dungeons da cena.
## Ex.: "dungeon_lv1", "dungeon_lv2"
@export var dungeon_id: String = ""

var original_position: Vector3

func _ready() -> void:
	if dungeon_id.is_empty():
		return
	var marker := get_node_or_null("EntranceMarker") as Node3D
	if DungeonManager:
		DungeonManager.register_dungeon(dungeon_id, self, marker)

func checkin():
	var wm := get_node_or_null("WaveManager") as DungeonWaveManager
	if wm:
		wm.start()

func checkout():
	var wm := get_node_or_null("WaveManager") as DungeonWaveManager
	if wm:
		wm.reset_state()
