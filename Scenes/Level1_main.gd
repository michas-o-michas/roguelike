extends Node3D
## Configura o DungeonManager: mundo (Level1) e dungeons; dungeons começam desabilitadas.

func _ready() -> void:
	if DungeonManager:
		DungeonManager.set_arena($Level1, [$Dungeon_Lv1, $Dungeon_Lv2])
