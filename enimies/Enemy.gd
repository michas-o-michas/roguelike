extends CharacterBody3D
class_name Enemy

# ========================================
# CONFIGURAÇÕES BÁSICAS
# ========================================

@export var audio_stream_player_3d: AudioStreamPlayer3D 

@export_group("🎯 Identificação")
@export var enemy_name: String = "Lobo"
@export var enemy_level: int = 1

@export_group("❤️ Stats")
@export var max_health: float = 100.0
@export var damage: float = 10.0
@export var defense: float = 5.0

@export_group("⚔️ Combate")
@export var attack_range: float = 2.0
@export var stop_attack_range: float = 3.0
@export var attack_cooldown: float = 2.0
@export var distance_tolerance: float = 0.2

@export_group("🏃 Movimento")
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var flee_speed: float = 8.0
@export var rotation_speed: float = 5.0
@export var chase_range: float = 15.0
@export var lose_target_distance: float = 25.0

@export_group("😱 Fuga")
@export var enable_flee: bool = true
@export var flee_health_percent: float = 0.25
@export var flee_duration: float = 5.0

@export_group("🧠 IA")
@export var idle_wander_radius: float = 10.0
@export var idle_wander_interval: float = 5.0

@export_group("🎨 Visual")
@export var mesh_instance: MeshInstance3D

@export_group("🎵 Animações")
@export var animation_tree: AnimationTree

@export_group("🌎 Física")
@export var gravity: float = 22.0

@export_group("❤️ Vida")
@export var health_component: HealthComponent


# ========================================
# VARIÁVEIS INTERNAS
# ========================================

enum State {
	IDLE,
	CHASE,
	ATTACK,
	HIT,
	FLEE,
	DEATH
}

var current_state: State = State.IDLE
var player: Node3D = null

var idle_timer: float = 0.0
var wander_destination: Vector3
var attack_timer: float = 0.0
var is_attacking: bool = false
var is_dead: bool = false

var flee_timer: float = 0.0


# ========================================
# INICIALIZAÇÃO
# ========================================

func _ready():
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	change_state(State.IDLE)

	# Se não tiver HealthComponent configurado, criar
	if not health_component:
		health_component = HealthComponent.new()
		health_component.max_health = max_health
		add_child(health_component)

	# Conectar sinais do HealthComponent
	health_component.damage_taken.connect(_on_damage_taken)
	health_component.died.connect(_on_died)
	health_component.health_changed.connect(_on_health_changed)


# ========================================
# LOOP PRINCIPAL
# ========================================

func _physics_process(delta):
	if is_dead:
		return

	velocity.y -= gravity * delta

	idle_timer += delta
	attack_timer += delta

	if current_state == State.FLEE:
		flee_timer += delta

	match current_state:
		State.IDLE:
			process_idle(delta)
		State.CHASE:
			process_chase(delta)
		State.ATTACK:
			process_attack(delta)
		State.HIT:
			process_hit(delta)
		State.FLEE:
			process_flee(delta)

	move_and_slide()


# ========================================
# UTILIDADES
# ========================================

func get_flat_distance_to_player() -> float:
	if not player:
		return INF

	var my_pos = global_position
	var player_pos = player.global_position

	my_pos.y = 0
	player_pos.y = 0

	return my_pos.distance_to(player_pos)


# ========================================
# IA – ESTADOS
# ========================================

func process_idle(delta):

	if player and can_see_target(player):
		change_state(State.CHASE)
		return

	if idle_timer >= idle_wander_interval:
		idle_timer = 0.0
		wander_destination = global_position + Vector3(
			randf_range(-idle_wander_radius, idle_wander_radius),
			0,
			randf_range(-idle_wander_radius, idle_wander_radius)
		)

	var dir = (wander_destination - global_position)

	if dir.length() > 1.0:
		velocity.x = dir.normalized().x * walk_speed
		velocity.z = dir.normalized().z * walk_speed
		look_at_target(wander_destination, delta)
		set_animation("Walk")
	else:
		velocity.x = 0
		velocity.z = 0
		set_animation("Idle")


func process_chase(delta):

	if not player:
		change_state(State.IDLE)
		return

	var distance = get_flat_distance_to_player()

	if enable_flee and health_component.current_health <= max_health * flee_health_percent:
		change_state(State.FLEE)
		return

	if distance > lose_target_distance:
		change_state(State.IDLE)
		return

	if distance <= attack_range + distance_tolerance:
		change_state(State.ATTACK)
		return

	var direction = (player.global_position - global_position).normalized()
	velocity.x = direction.x * run_speed
	velocity.z = direction.z * run_speed

	set_animation("Run")

	look_at_target(player.global_position, delta)


func process_attack(delta):

	if not player:
		change_state(State.IDLE)
		return

	var distance = get_flat_distance_to_player()

	if enable_flee and health_component.current_health <= max_health * flee_health_percent:
		change_state(State.FLEE)
		return

	if distance > stop_attack_range:
		change_state(State.CHASE)
		return

	velocity.x = 0
	velocity.z = 0

	look_at_target(player.global_position, delta)

	if attack_timer >= attack_cooldown and not is_attacking:
		perform_attack()
	else:
		set_animation("Idle")


func process_flee(delta):

	if not player:
		change_state(State.IDLE)
		return

	if flee_timer >= flee_duration:
		flee_timer = 0
		change_state(State.CHASE)
		return

	var direction = (global_position - player.global_position).normalized()

	velocity.x = direction.x * flee_speed
	velocity.z = direction.z * flee_speed

	set_animation("Run")

	look_at_target(global_position + direction, delta)


func process_hit(delta):

	velocity.x = 0
	velocity.z = 0
	set_animation("Idle")

	await get_tree().create_timer(0.5).timeout

	if not is_dead:
		change_state(State.CHASE)


# ========================================
# COMBATE
# ========================================

func perform_attack():

	is_attacking = true
	attack_timer = 0.0

	set_animation("Attack")

	if audio_stream_player_3d:
		audio_stream_player_3d.play()

	await get_tree().create_timer(0.5).timeout

	if player and get_flat_distance_to_player() <= attack_range + distance_tolerance:
		deal_damage_to_player()

	await get_tree().create_timer(0.5).timeout

	is_attacking = false


func deal_damage_to_player():
	if player.has_method("take_damage"):
		player.take_damage(damage)


func take_damage(amount: float, attacker: Node3D = null):

	if is_dead:
		return

	if health_component:
		health_component.take_damage(amount)


# ========================================
# SINAIS DO HEALTH COMPONENT
# ========================================

func _on_damage_taken(amount: float):
	if not is_dead:
		change_state(State.HIT)


func _on_health_changed(old_value: float, new_value: float):

	if enable_flee and new_value <= max_health * flee_health_percent:
		change_state(State.FLEE)


func _on_died():

	is_dead = true
	current_state = State.DEATH

	velocity = Vector3.ZERO

	set_animation("Death")

	await get_tree().create_timer(3.0).timeout

	queue_free()


# ========================================
# DETECÇÃO
# ========================================

func can_see_target(target_node: Node3D) -> bool:
	return get_flat_distance_to_player() <= chase_range


# ========================================
# UTILITÁRIOS
# ========================================

func look_at_target(target_pos: Vector3, delta: float):

	var direction = (target_pos - global_position).normalized()

	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_K:
			health_component.take_damage(10)

func change_state(new_state: State):

	if current_state == new_state:
		return

	current_state = new_state

	if new_state != State.FLEE:
		flee_timer = 0


func set_animation(anim_name: String):

	if not animation_tree:
		return

	var playback = animation_tree.get("parameters/playback")

	if playback:
		playback.travel(anim_name)
