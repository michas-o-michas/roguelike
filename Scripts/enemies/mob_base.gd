extends CharacterBody3D
## Base para todos os mobs/inimigos. Usa HealthComponent e MobData.
## O spawner deve setar mob_data antes de add_child (ou usar @export para teste no editor).

@export var mob_data: MobData

var _health_component: HealthComponent
var _player: Node3D
var _provoked: bool = false
var _attack_cooldown: float = 0.0

@export_group("AI")
## Raio em que o mob detecta o jogador (persegue/ataca). Spawner coloca mobs ~50–80 m do jogador; use ≥ 25 para reagir ao se aproximar.
@export var detection_radius: float = 30.0
@export var attack_radius: float = 1.8
@export var attack_cooldown_time: float = 1.0
@export var provocation_radius: float = 4.0
@export var flee_radius: float = 8.0
@export var gravity: float = 22.0
## Se true, no primeiro frame faz raycast para colar os pés no chão (evita nascer embaixo do terreno)
@export var snap_to_ground_on_spawn: bool = true

@export_group("Animações")
## AnimationTree (state machine): use travel("Idle"), travel("Walk"), etc. Se vazio, tenta AnimationPlayer.
@export var animation_tree_path: NodePath = NodePath("")
## AnimationPlayer: use play("Idle"), play("Walk"), etc. Usado se animation_tree_path estiver vazio.
@export var animation_player_path: NodePath = NodePath("")
## Duração em segundos da animação de ataque (evita trocar para Walk no meio do golpe)
@export var attack_anim_duration: float = 0.5
## Se true, imprime logs de AI, jogador e dano (debug)
@export var debug_log: bool = true

const FLOOR_SNAP_LENGTH := 0.2
const GROUND_CLEARANCE := 0.15

var _animation_tree: AnimationTree
var _animation_player: AnimationPlayer
var _is_playing_attack_anim: bool = false
var _attack_anim_end_time: float = 0.0
var _current_anim_name: String = ""
var _last_log_chase_time: float = -999.0
var _logged_no_mob_data: bool = false
const _ANIM_IDLE := "Idle"
const _ANIM_WALK := "Walk"
const _ANIM_RUN := "Run"
const _ANIM_ATTACK := "Attack"
const _ANIM_DEATH := "Death"

func _ready() -> void:
	print("[MobBase] _ready: ", name)
	_health_component = get_node_or_null("HealthComponent") as HealthComponent
	if not _health_component:
		push_warning("MobBase: HealthComponent não encontrado. Adicione como filho.")
		return

	if snap_to_ground_on_spawn:
		call_deferred("_snap_to_ground")

	if mob_data:
		_apply_mob_data()
		if debug_log:
			print("[MobBase] _ready: mob_data='%s', detection_radius=%.1f, behaviour=%d" % [
				mob_data.display_name, detection_radius, mob_data.behaviour
			])
	else:
		add_to_group("enemy")
		if _health_component:
			_health_component.max_health = 50.0
			_health_component.current_health = 50.0
		if debug_log:
			print("[MobBase] _ready: sem mob_data (fallback), detection_radius=%.1f" % detection_radius)

	if _health_component:
		_health_component.died.connect(_on_died)

	# Animações (opcional)
	if animation_tree_path:
		_animation_tree = get_node_or_null(animation_tree_path) as AnimationTree
		if _animation_tree:
			_animation_tree.active = true
			_set_animation(_ANIM_IDLE)
	if not _animation_tree and animation_player_path:
		_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
		if _animation_player:
			_animation_player.play(_ANIM_IDLE)

func set_mob_data(data: MobData) -> void:
	mob_data = data
	if is_node_ready():
		_apply_mob_data()

func _apply_mob_data() -> void:
	if not mob_data or not _health_component:
		return
	_health_component.max_health = mob_data.max_health
	_health_component.current_health = mob_data.max_health
	_health_component.defense = mob_data.defense
	_health_component.auto_destroy_on_death = true
	_health_component.destroy_delay = 2.0
	if mob_data.detection_radius > 0:
		detection_radius = mob_data.detection_radius

	if mob_data.is_hostile():
		add_to_group("enemy")

func take_damage(amount: float, attacker: Node = null) -> float:
	if not _health_component:
		return 0.0
	if mob_data and mob_data.behaviour == MobData.Behaviour.PASSIVE_AGGRESSIVE and attacker != null:
		_provoked = true
	if mob_data and mob_data.behaviour == MobData.Behaviour.NEUTRAL and attacker != null:
		_provoked = true
	var taken := _health_component.take_damage(amount, 0.0, attacker)
	if debug_log and taken > 0:
		var name_str := mob_data.display_name if mob_data else name
		print("[MobBase] take_damage: '%s' recebeu %.1f (vida %.1f/%.1f)" % [
			name_str, taken, _health_component.current_health, _health_component.max_health
		])
	return taken

func _on_died() -> void:
	remove_from_group("enemy")
	_set_animation(_ANIM_DEATH)
	if debug_log:
		var name_str := mob_data.display_name if mob_data else name
		print("[MobBase] _on_died: '%s' morreu" % name_str)

## Raycast para baixo e cola o mob na superfície do chão (evita nascer enterrado).
func _snap_to_ground() -> void:
	var w3d = get_world_3d()
	if not w3d:
		return
	var space = w3d.direct_space_state
	if not space:
		return
	var from := global_position + Vector3(0, 50.0, 0)
	var to := global_position + Vector3(0, -150.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0x7FFFFFFF
	# Excluir a gente mesmo (CharacterBody3D)
	query.exclude = [get_rid()]
	var result = space.intersect_ray(query)
	if result:
		global_position.y = result.position.y + GROUND_CLEARANCE
		velocity.y = 0.0

func _get_player() -> Node3D:
	var p = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(p):
		return p
	# Fallback: subir a árvore e usar .player do world generator (InfiniteWorldGenerator)
	var n: Node = get_parent()
	while n:
		var pl = n.get("player")
		if pl is Node3D and is_instance_valid(pl as Node3D):
			return pl as Node3D
		n = n.get_parent()
	return null

func set_player_ref(player_node: Node3D) -> void:
	_player = player_node
	if debug_log and is_instance_valid(player_node):
		print("[MobBase] set_player_ref: jogador definido (pos %.1f, %.1f, %.1f)" % [
			player_node.global_position.x, player_node.global_position.y, player_node.global_position.z
		])

func _physics_process(delta: float) -> void:
	if _attack_cooldown > 0:
		_attack_cooldown -= delta
	
	if not is_instance_valid(_player):
		_player = _get_player()
	if not is_instance_valid(_player):
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	else:
		_run_ai(delta)
		if debug_log:
			var dist := global_position.distance_to(_player.global_position)
			if dist <= detection_radius and Time.get_ticks_msec() / 1000.0 - _last_log_chase_time > 3.0:
				_last_log_chase_time = Time.get_ticks_msec() / 1000.0
				var name_str := mob_data.display_name if mob_data else name
				print("[MobBase] AI: '%s' perseguindo jogador (dist=%.1f m, vel=%.1f)" % [
					name_str, dist, Vector2(velocity.x, velocity.z).length()
				])

	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	_update_animation(delta)

func _run_ai(delta: float) -> void:
	if not mob_data:
		if debug_log and not _logged_no_mob_data:
			_logged_no_mob_data = true
			print("[MobBase] _run_ai: mob_data é null, AI não roda. Nome: ", name)
		return

	var dist_sq := global_position.distance_squared_to(_player.global_position)
	var dist := sqrt(dist_sq)
	var speed_val := mob_data.speed if mob_data else 5.0

	match mob_data.behaviour:
		MobData.Behaviour.PASSIVE:
			_ai_passive(dist, delta)
		MobData.Behaviour.AGGRESSIVE:
			_ai_aggressive(dist, dist_sq, speed_val, delta)
		MobData.Behaviour.PASSIVE_AGGRESSIVE:
			if _provoked or dist <= provocation_radius:
				_ai_aggressive(dist, dist_sq, speed_val, delta)
			else:
				_ai_idle(delta)
		MobData.Behaviour.NEUTRAL:
			if _provoked and dist <= detection_radius:
				_ai_aggressive(dist, dist_sq, speed_val, delta)
			else:
				_ai_idle(delta)

func _ai_passive(dist: float, delta: float) -> void:
	if dist < flee_radius:
		var away := (global_position - _player.global_position).normalized()
		away.y = 0
		velocity.x = away.x * (mob_data.speed if mob_data else 4.0)
		velocity.z = away.z * (mob_data.speed if mob_data else 4.0)
	else:
		velocity.x = move_toward(velocity.x, 0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 8.0 * delta)

func _ai_aggressive(dist: float, dist_sq: float, speed_val: float, delta: float) -> void:
	if dist <= attack_radius and _attack_cooldown <= 0:
		_try_attack_player()
		_attack_cooldown = attack_cooldown_time
		velocity.x = 0
		velocity.z = 0
	elif dist_sq <= detection_radius * detection_radius:
		var dir := (_player.global_position - global_position).normalized()
		dir.y = 0
		velocity.x = dir.x * speed_val
		velocity.z = dir.z * speed_val
		look_at(global_position + Vector3(dir.x, 0, dir.z))
	else:
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)

func _ai_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)

func _try_attack_player() -> void:
	if not is_instance_valid(_player):
		return
	_set_animation(_ANIM_ATTACK)
	_is_playing_attack_anim = true
	_attack_anim_end_time = Time.get_ticks_msec() / 1000.0 + attack_anim_duration
	if _player.has_method("take_damage"):
		var dmg := mob_data.damage if mob_data else 10.0
		_player.take_damage(dmg, 0.0, self)

func _set_animation(anim_name: String) -> void:
	if _current_anim_name == anim_name:
		return
	_current_anim_name = anim_name
	if _animation_tree:
		var playback = _animation_tree.get("parameters/playback")
		if playback:
			playback.travel(anim_name)
	elif _animation_player:
		if _animation_player.has_animation(anim_name):
			_animation_player.play(anim_name)

func _update_animation(delta: float) -> void:
	if _health_component and _health_component.is_dead:
		return
	if _is_playing_attack_anim:
		if Time.get_ticks_msec() / 1000.0 >= _attack_anim_end_time:
			_is_playing_attack_anim = false
		return
	var horiz := Vector2(velocity.x, velocity.z).length()
	if horiz > 0.5:
		if mob_data and horiz >= (mob_data.speed * 0.9):
			_set_animation(_ANIM_RUN)
		else:
			_set_animation(_ANIM_WALK)
	else:
		_set_animation(_ANIM_IDLE)
