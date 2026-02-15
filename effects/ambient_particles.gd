extends Node3D
## Mantém as partículas ambientais na área do jogador (mundo infinito).

func _process(_delta: float) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p and is_instance_valid(p):
		global_position.x = p.global_position.x
		global_position.z = p.global_position.z
		global_position.y = p.global_position.y + 5.0
