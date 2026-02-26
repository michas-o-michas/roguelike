extends Node3D
## Spawner noturno dedicado: nasce mobs ao redor do jogador quando a noite chega.
## Não usa activation_distance — está sempre ativo à noite enquanto o jogador existir.
## Coloque como filho de Level1 e configure mob_data_list no Inspector.

@export var mob_data_list: Array[MobData] = []

@export_group("Quantidade por Dia")
## Mobs simultâneos na 1ª noite
@export var base_mobs: int = 2
## Mobs adicionais por dia (frações permitidas — ex: 0.67 → dia 1=2, dia 10=8)
@export var mobs_per_extra_day: float = 0.67
## Máximo absoluto independente do dia
@export var max_mobs_cap: int = 20
@export_group("")

@export_group("Intervalo de Spawn")
## Segundos entre cada spawn (dia 1, base)
@export var spawn_interval: float = 6.0
## Redução do intervalo por dia (ex: 0.1 = −10% ao dia)
@export var interval_reduction_per_day: float = 0.08
## Intervalo mínimo — nunca vai abaixo disso
@export var min_spawn_interval: float = 2.0
@export_group("")

@export_group("Posição de Spawn")
## Distância mínima do jogador (não nasce na cara)
@export var min_distance: float = 15.0
## Distância máxima do jogador
@export var max_distance: float = 25.0
## Cone frontal (°) onde NÃO nascem mobs — nasce fora desse ângulo
@export var fov_degrees: float = 120.0
## Altura mínima acima do chão (evita entrar no terreno)
@export var ground_clearance: float = 0.35
@export_group("")

@export var debug_log: bool = false

var _alive_mobs: Array[Node] = []
var _player_ref: Node3D = null
var _is_night: bool = false
var _current_day: int = 1
var _target_mobs: int = 0
var _current_interval: float = 0.0
var _last_spawn_time: float = -999.0

func _ready() -> void:
	call_deferred("_connect_signals")

func _connect_signals() -> void:
	var dnc = get_tree().get_first_node_in_group("day_night_cycle")
	if not dnc:
		push_warning("NightSpawner: nó 'day_night_cycle' não encontrado.")
		return
	dnc.night_started.connect(_on_night_started)
	dnc.day_started.connect(_on_day_started)
	dnc.new_day_started.connect(_on_new_day)
	_current_day = dnc.current_day
	if dnc.is_night:
		_on_night_started()

func _process(_delta: float) -> void:
	if not _is_night:
		return
	_remove_dead_mobs()
	if _alive_mobs.size() >= _target_mobs:
		return
	if Time.get_ticks_msec() / 1000.0 - _last_spawn_time < _current_interval:
		return
	_ensure_player()
	if not is_instance_valid(_player_ref):
		return
	_spawn_one()

func _on_night_started() -> void:
	_is_night = true
	_recalculate()
	if debug_log:
		print("[NightSpawner] Noite começou. Dia %d → alvo %d mobs, intervalo %.1fs" % [_current_day, _target_mobs, _current_interval])

func _on_day_started() -> void:
	_is_night = false
	if debug_log:
		print("[NightSpawner] Amanheceu. Mobs vivos: %d (serão removidos naturalmente)" % _alive_mobs.size())

func _on_new_day(day: int) -> void:
	_current_day = day

func _recalculate() -> void:
	var extra := _current_day - 1
	_target_mobs = mini(base_mobs + int(extra * mobs_per_extra_day), max_mobs_cap)
	var reduction := 1.0 - extra * interval_reduction_per_day
	_current_interval = maxf(spawn_interval * reduction, min_spawn_interval)

func _ensure_player() -> void:
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D

func _spawn_one() -> void:
	if mob_data_list.is_empty():
		push_warning("NightSpawner: mob_data_list vazia — configure no Inspector.")
		return
	var mob_data: MobData = mob_data_list[randi() % mob_data_list.size()]
	if not mob_data or not mob_data.mob_scene:
		return

	var instance := mob_data.mob_scene.instantiate()
	if not instance:
		return

	var mob_ctrl := _find_mob_controller(instance)
	if not mob_ctrl:
		mob_ctrl = instance

	var pos := _get_spawn_pos()
	var ground_y := _get_ground_height_at(pos.x, pos.z)
	pos.y = ground_y if is_finite(ground_y) else _player_ref.global_position.y

	if mob_ctrl.has_method("set_mob_data"):
		mob_ctrl.set_mob_data(mob_data)
	if mob_ctrl.has_method("set_player_ref"):
		mob_ctrl.set_player_ref(_player_ref)

	add_child(instance)

	if mob_ctrl is Node3D:
		mob_ctrl.global_position = pos
	elif instance is Node3D:
		instance.global_position = pos

	_alive_mobs.append(instance)
	_last_spawn_time = Time.get_ticks_msec() / 1000.0

	var hc := mob_ctrl.get_node_or_null("HealthComponent") as HealthComponent
	if not hc:
		hc = instance.get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		hc.died.connect(_on_mob_died.bind(instance))

	if debug_log:
		print("[NightSpawner] spawn '%s' em (%.0f,%.0f,%.0f) vivos=%d/%d" % [
			mob_data.display_name, pos.x, pos.y, pos.z, _alive_mobs.size(), _target_mobs])

func _on_mob_died(mob: Node) -> void:
	var i := _alive_mobs.find(mob)
	if i >= 0:
		_alive_mobs.remove_at(i)

func _remove_dead_mobs() -> void:
	for i in range(_alive_mobs.size() - 1, -1, -1):
		var root := _alive_mobs[i]
		if not is_instance_valid(root):
			_alive_mobs.remove_at(i)
			continue
		var ctrl := _find_mob_controller(root)
		if not ctrl:
			ctrl = root
		var hc := ctrl.get_node_or_null("HealthComponent") as HealthComponent
		if not hc:
			hc = root.get_node_or_null("HealthComponent") as HealthComponent
		if hc and hc.is_dead:
			_alive_mobs.remove_at(i)

func _find_mob_controller(node: Node) -> Node:
	if node.has_method("set_mob_data") and node.has_method("set_player_ref"):
		return node
	for child in node.get_children():
		var found := _find_mob_controller(child)
		if found:
			return found
	return null

func _get_spawn_pos() -> Vector3:
	var player_pos := _player_ref.global_position
	var forward := -_player_ref.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
	var forward_angle := atan2(forward.x, forward.z)
	var half_avoid := deg_to_rad(fov_degrees * 0.5)
	var rand_arc := randf_range(half_avoid, TAU - half_avoid)
	var distance := randf_range(min_distance, max_distance)
	var angle := forward_angle + rand_arc
	return player_pos + Vector3(sin(angle) * distance, 0.0, cos(angle) * distance)

func _get_ground_height_at(x: float, z: float) -> float:
	var w3d := get_world_3d()
	if w3d:
		var space := w3d.direct_space_state
		if space:
			var y_ref := _player_ref.global_position.y
			var query := PhysicsRayQueryParameters3D.create(
				Vector3(x, y_ref + 400.0, z),
				Vector3(x, y_ref - 400.0, z)
			)
			query.collision_mask = 0x7FFFFFFF
			var result := space.intersect_ray(query)
			if result:
				return result.position.y + ground_clearance
	return NAN
