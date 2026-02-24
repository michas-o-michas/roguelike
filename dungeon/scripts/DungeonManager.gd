extends Node
## Gerencia entrada/saída de dungeons sem trocar cena.
## Dungeons se auto-registram via register_dungeon(); portais usam request_enter() por ID.

var _world_node: Node
var _dungeon_nodes: Array[Node] = []
var _current_dungeon: Node = null
var _return_position: Vector3 = Vector3.ZERO

## Registro ID → {node, marker}
var _registry: Dictionary = {}

# ─── Registro de dungeons ────────────────────────────────────────────────────

func register_dungeon(id: String, dungeon_node: Node3D, spawn_marker: Node3D) -> void:
	if id.is_empty():
		push_warning("DungeonManager: register_dungeon chamado com id vazio.")
		return
	_registry[id] = {&"node": dungeon_node, &"marker": spawn_marker}
	if not _dungeon_nodes.has(dungeon_node):
		_dungeon_nodes.append(dungeon_node)
	_set_dungeon_active(dungeon_node, false)

## Tenta entrar na dungeon pelo ID. Desconta custo de moedas se > 0.
## Retorna true se o teleporte foi iniciado, false caso contrário.
func request_enter(id: String, cost: int) -> bool:
	if cost > 0:
		if not InventoryManager or not InventoryManager.spend_coins(cost):
			return false
	if not _registry.has(id):
		push_warning("DungeonManager: dungeon não registrada: '%s'" % id)
		return false
	var entry: Dictionary = _registry[id]
	var dnode: Node3D = entry[&"node"]
	var marker: Node3D = entry[&"marker"]
	var spawn_pos: Vector3 = marker.global_position if marker else dnode.global_position + Vector3.UP * 2.0
	enter_dungeon(dnode, spawn_pos)
	return true

# ─── API legada (set_arena) ───────────────────────────────────────────────────

func set_arena(world: Node, dungeons: Array) -> void:
	_world_node = world
	for d in dungeons:
		if d is Node:
			if not _dungeon_nodes.has(d):
				_dungeon_nodes.append(d)
			_set_dungeon_active(d, false)

# ─── Entrada / Saída ──────────────────────────────────────────────────────────

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
	if dungeon_node.has_method("checkin"):
		dungeon_node.checkin()
	if player.has_method("request_teleport"):
		player.request_teleport(spawn_global_pos)
	else:
		player.global_position = spawn_global_pos
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO

func exit_dungeon() -> void:
	if not _current_dungeon:
		return
	if _current_dungeon.has_method("checkout"):
		_current_dungeon.checkout()
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
