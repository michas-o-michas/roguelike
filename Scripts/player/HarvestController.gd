# HarvestController.gd
# Módulo de coleta (E em árvore/pedra): aplica dano a cada attack_speed até o recurso morrer.
# Usado como filho do WeaponHandler; referência ao handler = get_parent().

extends Node

var _target: Node = null
var _timer: float = 0.0
var _start_position: Vector3 = Vector3.ZERO
var _active: bool = false

func _get_handler() -> Node:
	return get_parent()

func is_harvesting() -> bool:
	return _active

func start_harvesting(resource_node: Node) -> void:
	if resource_node == null or not resource_node.has_method("take_hit"):
		return
	stop_harvesting()
	_target = resource_node
	_active = true
	_timer = 0.0
	var player: Node = _get_handler().get_parent()
	_start_position = (player.global_position if player is Node3D else Vector3.ZERO)
	if resource_node is ResourceNode:
		if not resource_node.depleted.is_connected(_on_target_depleted):
			resource_node.depleted.connect(_on_target_depleted)
	if player.has_method("play_attack_animation"):
		player.play_attack_animation("Work")


func stop_harvesting() -> void:
	if _target != null and is_instance_valid(_target) and _target is ResourceNode:
		if _target.depleted.is_connected(_on_target_depleted):
			_target.depleted.disconnect(_on_target_depleted)
	_active = false
	_target = null
	_timer = 0.0
	var handler: Node = _get_handler()
	if handler.get_parent().has_method("stop_attack_animation"):
		handler.get_parent().stop_attack_animation()

func _on_target_depleted() -> void:
	stop_harvesting()

## Retorna true se consumiu o frame (coleta em andamento); o WeaponHandler não deve processar ataque.
func tick(delta: float) -> bool:
	if not _active or _target == null:
		return false
	if not is_instance_valid(_target):
		stop_harvesting()
		return false
	var handler: Node = _get_handler()
	var player: Node3D = handler.get_parent() as Node3D
	var cancel_dist: float = handler.get("harvest_move_cancel_distance")
	if cancel_dist == null:
		cancel_dist = 0.2
	var move_dist: float = (player.global_position - _start_position).length() if player else 0.0
	if move_dist > cancel_dist:
		stop_harvesting()
		return false
	var weapon: Weapon = handler.get("equipped_weapon") as Weapon
	if not weapon:
		return false
	_timer += delta
	if _timer < weapon.attack_speed:
		return true
	_timer = 0.0
	if player and player.has_method("play_attack_animation"):
		player.play_attack_animation("Work")
	if _target.has_method("take_hit"):
		_target.take_hit(weapon.damage)
	if _target is ResourceNode and _target.health <= 0:
		stop_harvesting()
	elif not is_instance_valid(_target):
		stop_harvesting()
	return true
