extends Node
## Adicione como filho da raiz da cena. Ao carregar, se PortalSpawn.next_marker_name estiver
## definido, move o jogador (grupo "player") para esse nó (ex.: MarkerIn, MarkerOut).

func _ready() -> void:
	var portal_spawn = get_node_or_null("/root/PortalSpawn")
	if not portal_spawn:
		return
	var marker_name: String = portal_spawn.next_marker_name
	portal_spawn.next_marker_name = ""
	if marker_name.is_empty():
		return
	var root: Node = get_parent()
	var marker: Node3D = root.find_child(marker_name, true, false) as Node3D
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if marker and player:
		player.global_position = marker.global_position
		player.global_rotation = marker.global_rotation
