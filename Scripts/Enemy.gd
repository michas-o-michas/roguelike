extends CharacterBody3D

@export var speed := 4.0
@export var max_health := 5
@export var gravity := 18.0
@export var knockback_force := 8.0

@export var attack_range := 2.2
@export var attack_damage := 1
@export var attack_cooldown := 1.2

@export var stop_distance := 1.8

@export var regen_delay := 2.0
@export var regen_amount := 1

var current_health: int
var player

var knockback_dir: Vector3 = Vector3.ZERO
var last_damage_time := 0.0
var last_attack_time := 0.0

var is_attacking := false
var is_dead := false

@onready var texture_progress_bar: TextureProgressBar = $SubViewport/TextureProgressBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready():
	# Adiciona ao grupo "enemies" — necessário pra o weapon_handler reconhecer como alvo
	add_to_group("enemies")

	player = get_tree().get_first_node_in_group("player")
	current_health = max_health
	update_health_bar()

	animation_player.play("CharacterArmature|Walk")


func _physics_process(delta):

	if is_dead:
		return

	# --------- GRAVIDADE ---------
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0


	# --------- KNOCKBACK ---------
	if knockback_dir != Vector3.ZERO:
		velocity += knockback_dir * knockback_force * delta
		knockback_dir = knockback_dir.lerp(Vector3.ZERO, 5.0 * delta)


	# --------- REGENERAÇÃO ---------
	if current_health < max_health:
		var now = Time.get_ticks_msec() / 1000.0

		if now - last_damage_time > regen_delay:
			current_health += regen_amount * delta
			current_health = int(current_health)
			update_health_bar()


	# --------- LÓGICA DE IA ---------
	if player:
		var distance = global_position.distance_to(player.global_position)

		# Sempre olhar pro player
		look_at(player.global_position, Vector3.UP)
		rotation_degrees.x = 0
		rotation_degrees.z = 0


		# ---- ATACAR ----
		if distance <= attack_range:
			try_attack()

			# parar quando perto
			velocity.x = 0
			velocity.z = 0

		# ---- PERSEGUIR ----
		elif distance > stop_distance:
			chase_player(delta)

		else:
			velocity.x = 0
			velocity.z = 0


	move_and_slide()



# ===========================
#   PERSEGUIÇÃO MELHORADA
# ===========================

func chase_player(delta):

	if is_attacking:
		return

	var dir = global_position.direction_to(player.global_position)
	dir.y = 0
	dir = dir.normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if animation_player.current_animation != "CharacterArmature|Walk":
		animation_player.play("CharacterArmature|Walk")



# ===========================
#   SISTEMA DE ATAQUE
# ===========================

func try_attack():

	var now = Time.get_ticks_msec() / 1000.0

	if now - last_attack_time < attack_cooldown:
		return

	last_attack_time = now
	is_attacking = true

	animation_player.play("CharacterArmature|Punch")

	apply_damage_to_player()

	await get_tree().create_timer(0.4).timeout

	is_attacking = false



func apply_damage_to_player():

	if not player:
		return

	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

	print("Inimigo atacou o player!")



# ===========================
#   RECEBER DANO
# ===========================

func take_damage(amount: int, damage_dir: Vector3 = Vector3.ZERO):

	if is_dead:
		return

	last_damage_time = Time.get_ticks_msec() / 1000.0

	current_health -= amount
	update_health_bar()

	if current_health <= 0:
		die()
		return

	# Knockback opcional
	if damage_dir != Vector3.ZERO:
		knockback_dir = damage_dir.normalized()

	animation_player.play("CharacterArmature|HitReact")

	print("Inimigo tomou dano:", amount, "vida restante:", current_health)

	damage_flash()



func damage_flash():

	var mesh = get_node_or_null("MeshInstance3D")

	if mesh and mesh.material_override:
		var mat = mesh.material_override.duplicate()
		mat.albedo_color = Color.RED
		mesh.material_override = mat

		await get_tree().create_timer(0.1).timeout
		mesh.material_override = null



# ===========================
#   MORTE
# ===========================

func die():

	is_dead = true
	velocity = Vector3.ZERO

	# Dropa itens quando morre (se tiver EnemyDrop como filho)
	if has_node("EnemyDrop"):
		$EnemyDrop.drop()

	if animation_player.has_animation("CharacterArmature|Death"):
		animation_player.play("CharacterArmature|Death")
		await animation_player.animation_finished

	queue_free()



# ===========================
#   BARRA DE VIDA
# ===========================

func update_health_bar():
	texture_progress_bar.value = (float(current_health) / max_health) * 100.0
