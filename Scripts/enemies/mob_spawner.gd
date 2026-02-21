extends Node3D
## Spawne mobs quando o jogador está dentro de activation_distance.
## SpawnerManager instancia esta cena; defina mob_data no Inspector (ex. wolf_spawner.tscn).

@export var mob_data: MobData
@export var activation_distance: float = 80.0
@export var max_mobs: int = 4
@export var spawn_interval: float = 8.0
@export var spawn_radius: float = 6.0
## Altura mínima acima do chão para os pés do mob (evita nascer enterrado)
@export var ground_clearance: float = 0.35
## Se true, imprime logs de spawn e referência ao jogador (debug)
@export var debug_log: bool = true

var _alive_mobs: Array[Node] = []
var _last_spawn_time: float = -999.0
var _player_ref: Node3D = null

func _get_world_generator() -> Node:
	var n: Node = self
	while n:
		if n.has_method("get_terrain_height"):
			return n
		n = n.get_parent()
	return null

## Retorna a altura Y do chão em (x, z): raycast primeiro, depois get_terrain_height. Retorna NAN se falhar.
func _get_ground_height_at(x: float, z: float) -> float:
	var w3d := get_world_3d()
	if w3d:
		var space = w3d.direct_space_state
		if space:
			# Raio bem largo para acertar o terreno em qualquer origem (ex.: world rebase)
			var y_center := global_position.y
			var from := Vector3(x, y_center + 400.0, z)
			var to := Vector3(x, y_center - 400.0, z)
			var query := PhysicsRayQueryParameters3D.create(from, to)
			# Colide com qualquer layer (terreno costuma ser layer 1)
			query.collision_mask = 0x7FFFFFFF
			var result = space.intersect_ray(query)
			if result:
				return result.position.y + ground_clearance
	var wg = _get_world_generator()
	if wg:
		return wg.get_terrain_height(x, z) + ground_clearance
	return NAN

func _ready() -> void:
	print("[MobSpawner] _ready (spawner ativo)")
	if not mob_data:
		push_warning("MobSpawner: mob_data não definido. Defina no Inspector ou set_mob_data().")
	# Referência ao jogador: do grupo ou do world generator (pai)
	var p = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(p):
		_player_ref = p
		if debug_log:
			print("[MobSpawner] _ready: jogador obtido pelo grupo 'player'")
	else:
		var wg = _get_world_generator()
		if wg:
			var pl = wg.get("player")
			if pl is Node3D and is_instance_valid(pl):
				_player_ref = pl as Node3D
				if debug_log:
					print("[MobSpawner] _ready: jogador obtido do world generator (pai)")
		if not is_instance_valid(_player_ref) and debug_log:
			print("[MobSpawner] _ready: jogador NÃO encontrado (grupo nem world gen)")

func set_mob_data(data: MobData) -> void:
	mob_data = data

## Encontra o nó que tem o script do mob (set_mob_data), na raiz ou em algum filho.
func _find_mob_controller(node: Node) -> Node:
	if node.has_method("set_mob_data") and node.has_method("set_player_ref"):
		return node
	for child in node.get_children():
		var found = _find_mob_controller(child)
		if found:
			return found
	return null

func _process(_delta: float) -> void:
	_remove_dead_mobs()
	if not mob_data or not mob_data.mob_scene:
		return

	var player = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		return

	var dist := global_position.distance_to(player.global_position)
	if dist > activation_distance:
		return
	if _alive_mobs.size() >= max_mobs:
		return
	if Time.get_ticks_msec() / 1000.0 - _last_spawn_time < spawn_interval:
		return

	_spawn_one()

func _remove_dead_mobs() -> void:
	for i in range(_alive_mobs.size() - 1, -1, -1):
		var root = _alive_mobs[i]
		if not is_instance_valid(root):
			_alive_mobs.remove_at(i)
			continue
		var ctrl = _find_mob_controller(root)
		if not ctrl:
			ctrl = root
		var hc = ctrl.get_node_or_null("HealthComponent") as HealthComponent
		if not hc:
			hc = root.get_node_or_null("HealthComponent") as HealthComponent
		if hc and hc.is_dead:
			_alive_mobs.remove_at(i)

func _spawn_one() -> void:
	# Garantir referência ao jogador (pode não existir no _ready)
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D
		if not _player_ref:
			var wg = _get_world_generator()
			if wg:
				var pl = wg.get("player")
				if pl is Node3D and is_instance_valid(pl):
					_player_ref = pl as Node3D
		if debug_log and not is_instance_valid(_player_ref):
			print("[MobSpawner] _spawn_one: jogador ainda null, mob pode não perseguir")

	var instance = mob_data.mob_scene.instantiate()
	if not instance:
		if debug_log:
			print("[MobSpawner] _spawn_one: falha ao instanciar cena do mob")
		return

	# Nó que realmente tem mob_base.gd (pode ser a raiz ou um filho, ex. CharacterBody3D dentro de Node3D)
	var mob_controller = _find_mob_controller(instance)
	if not mob_controller:
		mob_controller = instance
	elif debug_log and mob_controller != instance:
		print("[MobSpawner] script do mob está em filho: ", mob_controller.get_path())

	var offset_x := randf_range(-spawn_radius, spawn_radius)
	var offset_z := randf_range(-spawn_radius, spawn_radius)
	var pos := global_position + Vector3(offset_x, 0, offset_z)

	var ground_y := _get_ground_height_at(pos.x, pos.z)
	if is_finite(ground_y):
		pos.y = ground_y
	else:
		pos.y = maxf(global_position.y, 1.0)

	if mob_controller.has_method("set_mob_data"):
		mob_controller.set_mob_data(mob_data)
	if is_instance_valid(_player_ref) and mob_controller.has_method("set_player_ref"):
		mob_controller.set_player_ref(_player_ref)
	add_child(instance)
	# Posição no nó que realmente se move (CharacterBody3D com mob_base); se for filho, só ele precisa estar em pos
	if mob_controller is Node3D:
		mob_controller.global_position = pos
	elif instance is Node3D:
		instance.global_position = pos
	_alive_mobs.append(instance)
	if debug_log:
		var name_str = mob_data.display_name if mob_data else instance.name
		print("[MobSpawner] spawn: 1x '%s' em (%.1f, %.1f, %.1f), vivos=%d, player_ref=%s" % [
			name_str, pos.x, pos.y, pos.z, _alive_mobs.size(), "OK" if is_instance_valid(_player_ref) else "null"
		])

	# HealthComponent pode estar no controller (mob) ou na raiz
	var hc = mob_controller.get_node_or_null("HealthComponent") as HealthComponent
	if not hc:
		hc = instance.get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		hc.died.connect(_on_mob_died.bind(instance))

	_last_spawn_time = Time.get_ticks_msec() / 1000.0

func _on_mob_died(_mob: Node) -> void:
	for i in range(_alive_mobs.size()):
		if _alive_mobs[i] == _mob:
			if debug_log:
				print("[MobSpawner] mob morreu, vivos=%d" % (_alive_mobs.size() - 1))
			_alive_mobs.remove_at(i)
			break
