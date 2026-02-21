extends CharacterBody3D
# Player: movimento, câmera, animação, vida (via HealthComponent).
# Nós esperados: HealthComponent, WeaponHandler, Camera3D, AttackArea, StepAudio, RayCast3D.

# ================= MOVIMENTO =================
@export var speed := 8.0
@export var sprint_speed := 14.0
@export var jump_force := 9.0
@export var gravity := 22.0

@export var accel := 18.0
@export var deaccel := 22.0

@export var air_accel := 6.0
@export var air_deaccel := 2.0

# ================= DASH =================
@export var dash_force := 24.0
@export var dash_time := 0.18
@export var dash_cooldown := 0.7

var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var is_dashing := false

# ================= PULO AVANÇADO =================
@export var max_jumps := 1
var jumps_left := 1

@export var coyote_time := 0.12
var coyote_timer := 0.0

@export var jump_buffer_time := 0.12
var jump_buffer_timer := 0.0
var jump_buffered := false

# ================= CÂMERA (terceira pessoa — órbita no personagem) =================
@export var mouse_sensitivity := 0.10
@export var cam_follow_speed := 12.0
@export var cam_pivot_height := 1.15 ## Centro da órbita = costas/ombros (não os pés)
@export var cam_distance := 5.2
@export var cam_height_offset := 0.35 ## Altura da câmera em relação ao pivot (acima/abaixo)
@export var cam_pitch_min := -50.0
@export var cam_pitch_max := 60.0

var rotation_x := 0.0

# ================= VIDA E DANO (HealthComponent) =================
@export var base_health := 100
@export var invincibility_duration_after_hit := 0.8
var _invincibility_timer := 0.0

## Usados por SkillManager (buffs). Movimento usa speed/sprint_speed; dano real vem da arma (weapon_handler).
var base_speed := 8.0
var damage := 0
var base_damage := 0
var attack_speed := 1.0
var base_attack_speed := 1.0
var base_max_jumps := 1

# ================= PASSOS =================
var step_timer := 0.0
@export var step_interval := 0.6
@export var step_interval_sprint := 0.4
@onready var step_audio: AudioStreamPlayer3D = $StepAudio

# ================= ANIMAÇÕES (AnimationTree — travel por nome de estado) =================
@export var animation_tree_path: NodePath = NodePath("AnimationTree")
@onready var animation_tree: AnimationTree = get_node_or_null(animation_tree_path) as AnimationTree
@export var attack_anim_duration := 0.5
var is_attacking := false
var _attack_end_time := 0.0

# ================= MODO CRIATIVO (VOAR) =================
@export var fly_speed := 12.0
@export var fly_sprint_speed := 500.0

@export var creative_mode := false
var flying := false

## Teleporte: definido por pads/portais; aplicado no início do próximo _physics_process.
var _pending_teleport: Vector3 = Vector3.INF

## Offset em metros acima do ponto de colisão ao fazer snap no chão (evita enterrar).
@export var ground_snap_height_offset: float = 0.05

@onready var _health_component: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent

func request_teleport(global_pos: Vector3) -> void:
	_pending_teleport = global_pos

## Chamado pelo gerador de mundo (ou outro sistema) para posicionar o jogador em cima do terreno.
## Define a posição e ativa o RayCast para, no próximo frame, ajustar à superfície real.
func position_on_terrain(global_pos: Vector3) -> void:
	global_position = global_pos
	velocity = Vector3.ZERO
	var ray := get_node_or_null("RayCast3D") as RayCast3D
	if ray:
		ray.enabled = true

func _ready():
	base_speed = speed
	base_max_jumps = max_jumps
	if _health_component:
		_health_component.max_health = base_health
		_health_component.current_health = base_health
		_health_component.died.connect(_on_died)
	else:
		push_warning("Player: HealthComponent não encontrado. Adicione o nó HealthComponent como filho do Player para vida/dano.")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")
	if animation_tree:
		animation_tree.active = true
		set_animation("Idle")

func set_animation(anim_name: String) -> void:
	if not animation_tree:
		return
	var playback = animation_tree.get("parameters/playback")
	if playback:
		playback.travel(anim_name)

## Chamado ao atacar (weapon_handler) — evita que Idle/Walk/Run sobrescrevam a animação
func play_attack_animation(anim_state_name: String = "Attack") -> void:
	set_animation(anim_state_name)
	is_attacking = true
	_attack_end_time = Time.get_ticks_msec() / 1000.0 + attack_anim_duration

## Chamado pelo SkillManager após aplicar bônus da skill (ex.: para UI ou efeitos).
func apply_skill(_skill) -> void:
	pass

## Retorna o HealthComponent (para SkillManager e UI). Retorna null se não houver.
func get_health_component() -> HealthComponent:
	return _health_component

## Recebe dano. Delega ao HealthComponent; ativa i-frames após o hit.
func take_damage(amount: float, armor_piercing: float = 0.0, _attacker: Node = null) -> float:
	if _health_component == null:
		return 0.0
	var taken := _health_component.take_damage(amount, armor_piercing, _attacker)
	if taken > 0:
		_health_component.is_invincible = true
		_invincibility_timer = invincibility_duration_after_hit
	return taken

## Cura o jogador. Delega ao HealthComponent.
func heal(amount: float) -> float:
	if _health_component == null:
		return 0.0
	return _health_component.heal(amount)

func _is_dead() -> bool:
	return _health_component != null and _health_component.is_dead

func _on_died() -> void:
	set_animation("Death")

func _set(property, value):
	if property == "creative_mode":
		creative_mode = value
		if not creative_mode:
			flying = false
	return true


func _input(event):

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, cam_pitch_min, cam_pitch_max)

func _get_camera_target_position() -> Vector3:
	# Órbita em volta do pivot (costas/ombros), não dos pés
	var pivot := Vector3(0.0, cam_pivot_height, 0.0)
	var offset := Vector3(0.0, cam_height_offset, cam_distance)
	offset = offset.rotated(Vector3.RIGHT, deg_to_rad(rotation_x))
	return pivot + offset

func _get_pivot_global() -> Vector3:
	return global_position + Vector3(0.0, cam_pivot_height, 0.0)

## Usado pelo script ThirdPersonCamera.gd para posição suave em terceira pessoa.
func get_camera_pivot_global() -> Vector3:
	return _get_pivot_global()

func get_camera_target_global_position() -> Vector3:
	return global_position + transform.basis * _get_camera_target_position()

## Usa o RayCast3D para colar os pés na superfície (ponto de colisão, não a posição do corpo rígido).
func _try_snap_to_ground_surface() -> void:
	var ray := get_node_or_null("RayCast3D") as RayCast3D
	if not ray or not ray.enabled or not ray.is_colliding():
		return
	var hit_point: Vector3 = ray.get_collision_point()
	global_position = hit_point + Vector3(0.0, ground_snap_height_offset, 0.0)
	velocity = Vector3.ZERO
	ray.enabled = false

func _physics_process(delta):
	_try_snap_to_ground_surface()
	# Aplicar teleporte pendente antes de qualquer movimento (evita ser sobrescrito)
	if _pending_teleport != Vector3.INF:
		global_position = _pending_teleport
		velocity = Vector3.ZERO
		_pending_teleport = Vector3.INF
		return

	if _is_dead():
		set_animation("Death")
		velocity.x = move_toward(velocity.x, 0, deaccel * delta)
		velocity.z = move_toward(velocity.z, 0, deaccel * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	var input_dir = Input.get_vector("a", "d", "w", "s")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()


	# ============== MODO CRIATIVO / VOO ==============
	if creative_mode:

		# Alterna voo com o botão de pulo
		if Input.is_action_just_pressed("jump"):
			flying = !flying



		if flying:
			var current_fly_speed = fly_speed

			if Input.is_action_pressed("sprint"):
				current_fly_speed = fly_sprint_speed

			# Movimento livre no ar
			velocity.x = direction.x * current_fly_speed
			velocity.z = direction.z * current_fly_speed

			# Subir e descer
			if Input.is_action_pressed("jump"):
				velocity.y = current_fly_speed
			elif Input.is_action_pressed("crouch"):
				velocity.y = -current_fly_speed
			else:
				velocity.y = 0

			move_and_slide()
			return

	# ============== FÍSICA NORMAL ==============

	if not is_on_floor():
		coyote_timer = max(coyote_timer - delta, 0.0)
	else:
		coyote_timer = coyote_time
		jumps_left = max_jumps

	if jump_buffered:
		jump_buffer_timer -= delta
		if jump_buffer_timer <= 0:
			jump_buffered = false

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0:
			velocity.y = 0

	# I-frames: após levar dano, invencibilidade por um curto tempo
	if _invincibility_timer > 0:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0 and _health_component:
			_health_component.is_invincible = false

	var current_speed := speed
	var step_current := step_interval
	if Input.is_action_pressed("sprint"):
		current_speed = sprint_speed
		step_current = step_interval_sprint

	if Input.is_action_just_pressed("jump"):
		jump_buffered = true
		jump_buffer_timer = jump_buffer_time
		if not is_dashing:
			set_animation("Jump")

	if jump_buffered:
		var can_jump := false
		if is_on_floor():
			can_jump = true
		elif coyote_timer > 0:
			can_jump = true
		elif jumps_left > 0:
			can_jump = true
		if can_jump:
			velocity.y = jump_force
			jump_buffered = false
			jumps_left -= 1
			if not is_dashing:
				set_animation("Jump")

	handle_dash(delta, direction)

	if not is_dashing:
		if direction != Vector3.ZERO:
			var target = direction * current_speed
			var used_accel = accel if is_on_floor() else air_accel
			velocity.x = lerp(velocity.x, target.x, used_accel * delta)
			velocity.z = lerp(velocity.z, target.z, used_accel * delta)
		else:
			var used_deaccel = deaccel if is_on_floor() else air_deaccel
			velocity.x = lerp(velocity.x, 0.0, used_deaccel * delta)
			velocity.z = lerp(velocity.z, 0.0, used_deaccel * delta)

	# Não sobrescrever animação durante o ataque nem durante o dash
	if is_attacking:
		if Time.get_ticks_msec() / 1000.0 >= _attack_end_time:
			is_attacking = false
	elif _is_dead():
		set_animation("Death")
	elif is_dashing:
		set_animation("Dash")
	elif not is_on_floor():
		set_animation("Jump")
	elif direction.length_squared() > 0.01:
		if current_speed >= sprint_speed * 0.9:
			set_animation("Run")
		else:
			set_animation("Walk")
	else:
		set_animation("Idle")

	if is_on_floor() and direction.length() > 0 and not is_dashing:
		step_timer -= delta
		if step_timer <= 0:
			step_audio.play()
			step_timer = step_current
	else:
		step_timer = 0

	move_and_slide()


func handle_dash(delta, direction):

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
		return

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		set_animation("Dash")
		if direction == Vector3.ZERO:
			direction = -transform.basis.z

		velocity += direction * dash_force

		is_dashing = true
		dash_timer = dash_time
		dash_cooldown_timer = dash_cooldown
