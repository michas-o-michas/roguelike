extends Node
## Gerencia entrada/saída de dungeons sem trocar cena.
## Desabilita o mapa (Level1) e habilita a dungeon ativa; ao sair, restaura e teleporta para onde saiu.

var _world_node: Node
var _dungeon_nodes: Array[Node] = []
var _current_dungeon: Node = null
var _return_position: Vector3 = Vector3.ZERO

func set_arena(world: Node, dungeons: Array) -> void:
	_world_node = world
	_dungeon_nodes.clear()
	for d in dungeons:
		if d is Node:
			_dungeon_nodes.append(d)
			_set_dungeon_active(d, false)

func _set_dungeon_active(dungeon: Node, active: bool) -> void:
	dungeon.visible = active
	dungeon.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _set_world_active(active: bool) -> void:
	if not _world_node or not is_instance_valid(_world_node):
		return
	_world_node.visible = active
	_world_node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func enter_dungeon(dungeon_node: Node, spawn_global_pos: Vector3) -> void:
	if not dungeon_node or not is_instance_valid(dungeon_node):
		push_warning("DungeonManager: dungeon_node inválido.")
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("DungeonManager: nenhum node no grupo 'player'.")
		return
	_return_position = player.global_position
	_set_world_active(false)
	for d in _dungeon_nodes:
		_set_dungeon_active(d, d == dungeon_node)
	_current_dungeon = dungeon_node
	if player.has_method("request_teleport"):
		player.request_teleport(spawn_global_pos)
	else:
		player.global_position = spawn_global_pos
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO

func exit_dungeon() -> void:
	if not _current_dungeon:
		return
	_set_dungeon_active(_current_dungeon, false)
	_current_dungeon = null
	_set_world_active(true)
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("request_teleport"):
			player.request_teleport(_return_position)
		else:
			player.global_position = _return_position
			if player is CharacterBody3D:
				(player as CharacterBody3D).velocity = Vector3.ZERO
