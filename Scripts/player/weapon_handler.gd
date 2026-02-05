# weapon_handler.gd
# Attach diretamente no seu Player (CharacterBody3D).
# Gerencia: arma equipada, ataques melee, projétis e efeitos.
#
# Como usar:
#   1. Seleciona o Player no editor
#   2. Attach script > seleciona weapon_handler.gd
#   3. No Inspector, arrasta o RayCast3D que você já tem no campo "attack_raycast"
#   4. Equipa uma arma via código:
#        var sword = preload("res://items/weapons/iron_sword.tres")
#        $WeaponHandler.equip(sword)
#
# IMPORTANTE:
#   Seu Player precisa ter um nó "WeaponHandler" ou você pode dar extend
#   diretamente no player. Abaixo vai como standalone (nó filho do Player).

extends Node3D

# ================= SINAIS =================
signal weapon_equipped(weapon: Weapon)
signal weapon_unequipped
signal attack_hit(target: Node3D, damage: int)

# ================= EXPORTS =================
@export var attack_raycast: RayCast3D   # Arrasta o RayCast3D que você já tem no Player
@export var hand_marker: Marker3D       # Arrasta o Marker3D que é o ponto da mão (veja abaixo como criar)

# ================= ESTADO =================
var equipped_weapon: Weapon = null
var weapon_model: Node3D = null         # Referência ao modelo 3D instanciado
var attack_cooldown_timer: float = 0.0
var is_attacking: bool = false

# ================= SWING (animação de ataque) =================
var swing_progress: float = 0.0         # 0.0 = posição de repouso, 1.0 = fim do swing
var is_swinging: bool = false
@export var swing_angle: float = -90.0  # Ângulo do swing em graus (negativo = pra frente)
@export var swing_duration: float = 0.15 # Tempo do swing ida (rápido)
@export var swing_return_duration: float = 0.25 # Tempo da volta (mais lento, com easing)

# ================= ÁUDIO =================
@onready var audio_player: AudioStreamPlayer3D = $AttackAudio

# ================= INICIALIZAÇÃO =================
func _ready():
	# Garante que o raycast existe
	if attack_raycast == null:
		push_warning("WeaponHandler: RayCast3D não assignado no Inspector!")

# ================= EQUIPAR / DESEQUIPAR =================

## Equipa uma arma
func equip(weapon: Weapon) -> void:
	if weapon == null:
		unequip()
		return

	unequip()  # Garante que desequipa antes (limpa modelo anterior)
	equipped_weapon = weapon
	_load_weapon_model()
	emit_signal("weapon_equipped", weapon)

## Desequipa a arma atual
func unequip() -> void:
	equipped_weapon = null
	_remove_weapon_model()
	emit_signal("weapon_unequipped")

# ================= MODELO VISUAL =================

## Carrega o modelo 3D da arma no Marker3D (mão do player)
func _load_weapon_model() -> void:
	if equipped_weapon == null or hand_marker == null:
		return

	# A arma precisa ter um @export "model_scene: PackedScene" no weapon.gd
	# apontando pra uma .tscn que contém o .glb
	if equipped_weapon.model_scene != null:
		weapon_model = equipped_weapon.model_scene.instantiate()
		hand_marker.add_child(weapon_model)
	else:
		push_warning("Arma '%s' não tem model_scene definido no .tres" % equipped_weapon.item_name)

## Remove o modelo 3D atual
func _remove_weapon_model() -> void:
	if weapon_model != null:
		weapon_model.queue_free()
		weapon_model = null

## Retorna a arma equipada atual (ou null)
func get_equipped() -> Weapon:
	return equipped_weapon

# ================= ATAQUE =================

func _physics_process(delta):
	# Countdown do cooldown entre ataques
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	# Atualiza a animação de swing todo frame
	_update_swing(delta)

	# Verifica input de ataque
	if Input.is_action_just_pressed("attack"):
		_try_attack()

## Tenta realizar um ataque
func _try_attack() -> void:
	# Sem arma equipada — não faz nada
	if equipped_weapon == null:
		return

	# Ainda no cooldown — não faz nada
	if attack_cooldown_timer > 0:
		return

	# Seta o cooldown baseado na velocidade da arma
	attack_cooldown_timer = equipped_weapon.attack_speed

	# Toca o som do ataque
	_play_attack_sound()

	# Roteia para melee ou ranged
	match equipped_weapon.weapon_type:
		Weapon.WeaponType.MELEE:
			_attack_melee()
		Weapon.WeaponType.RANGED:
			_attack_ranged()

# ================= SWING =================

## Inicia o swing quando ataca
func _start_swing() -> void:
	if weapon_model == null:
		return
	is_swinging = true
	swing_progress = 0.0

## Atualiza a rotação do modelo todo frame
func _update_swing(delta: float) -> void:
	if not is_swinging or weapon_model == null:
		return

	swing_progress += delta

	# --- FASE 1: ida (rápida, até swing_duration) ---
	if swing_progress <= swing_duration:
		var t = swing_progress / swing_duration
		# Easing out cubic — começa rápido, desacelera no fim
		var ease_t = 1.0 - pow(1.0 - t, 3.0)
		weapon_model.rotation_degrees.z = swing_angle * ease_t

	# --- FASE 2: volta (mais lenta, com easing suave) ---
	else:
		var return_progress = swing_progress - swing_duration
		if return_progress >= swing_return_duration:
			# Voltou completamente — reseta
			weapon_model.rotation_degrees.z = 0.0
			is_swinging = false
			swing_progress = 0.0
		else:
			var t = return_progress / swing_return_duration
			# Easing out quart — volta suave
			var ease_t = 1.0 - pow(1.0 - t, 4.0)
			weapon_model.rotation_degrees.z = swing_angle * (1.0 - ease_t)

# ================= MELEE =================

func _attack_melee() -> void:
	_start_swing()

	if attack_raycast == null:
		return

	# Força o raycast a atualizar agora (pra pegar colisão atual)
	attack_raycast.force_raycast_update()

	if not attack_raycast.is_colliding():
		# Não acertou nada — mas pode estar minerando
		if equipped_weapon.can_mine():
			_try_mine()
		return

	var target = attack_raycast.get_collider()

	# --- Mineração (bloco/recurso no mundo) ---
	if target.is_in_group("minable") and equipped_weapon.can_mine():
		_try_mine_target(target)
		return

	# --- Combate (inimigo) ---
	if target.is_in_group("enemies"):
		_apply_damage(target)
		_apply_melee_effect(target)

## Aplica dano ao inimigo
func _apply_damage(target: Node3D) -> void:
	var damage = equipped_weapon.damage

	# Direção do dano: do player pra o inimigo (usado pra knockback)
	var player = get_parent()
	var damage_dir = (target.global_position - player.global_position).normalized()

	if target.has_method("take_damage"):
		target.take_damage(damage, damage_dir)
		emit_signal("attack_hit", target, damage)

## Aplica efeitos específicos do ataque melee (stun, knockback, etc.)
func _apply_melee_effect(target: Node3D) -> void:
	var effect = equipped_weapon.effect

	# --- Knockback ---
	if equipped_weapon.knockback_force > 0 and target is CharacterBody3D:
		var direction = (target.global_position - get_parent().global_position).normalized()
		target.velocity += direction * equipped_weapon.knockback_force

	# --- Stun ---
	if equipped_weapon.has_stun():
		if target.has_method("apply_stun"):
			target.apply_stun(equipped_weapon.get_stun_duration())

	# --- AoE (área) ---
	if equipped_weapon.is_aoe():
		_apply_aoe_damage(target.global_position)

	# --- Efeitos visuais (partículas) ---
	_spawn_hit_effect(target.global_position)

## Dano em área ao redor do ponto de impacto
func _apply_aoe_damage(center: Vector3) -> void:
	var aoe_radius = 3.0
	var aoe_damage = int(equipped_weapon.damage * 0.5)  # 50% do dano principal

	# Pega todos os inimigos na área usando ShapeCast ou overlap
	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsPointQueryParameters3D.new()
	query.position = center
	query.collision_mask = 0b0010  # Ajuste o layer dos inimigos aqui

	var results = space_state.query_point(query)
	for result in results:
		var target = result["collider"]
		if target.is_in_group("enemies") and target.has_method("take_damage"):
			target.take_damage(aoe_damage)

# ================= MINERAÇÃO =================

## Tenta minerar o alvo do raycast
func _try_mine() -> void:
	if attack_raycast == null or not attack_raycast.is_colliding():
		return
	var target = attack_raycast.get_collider()
	if target.is_in_group("minable"):
		_try_mine_target(target)

## Mineração em um alvo específico
func _try_mine_target(target: Node3D) -> void:
	if target.has_method("mine"):
		target.mine(equipped_weapon.damage)

# ================= RANGED (PROJÉTIL) =================

func _attack_ranged() -> void:
	_start_swing()

	if equipped_weapon.projectile_scene == null:
		push_warning("WeaponHandler: Staff sem projectile_scene assignada!")
		return

	# Instancia o projétil na posição do player
	var projectile = equipped_weapon.projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	# Posiciona na câmera do player
	var player = get_parent()
	var camera = player.get_node("Camera3D")
	projectile.global_position = camera.global_position

	# Direção: pra onde a câmera tá apontando
	var direction = -camera.global_transform.basis.z.normalized()

	# Passa os dados necessários pro projétil
	if projectile.has_method("setup"):
		projectile.setup(
			direction,
			equipped_weapon.projectile_speed,
			equipped_weapon.damage,
			equipped_weapon.projectile_type
		)

# ================= SOM =================

func _play_attack_sound() -> void:
	if equipped_weapon.attack_sound == null:
		return
	if audio_player == null:
		return
	audio_player.stream = equipped_weapon.attack_sound
	audio_player.play()

# ================= EFEITOS VISUAIS =================

## Instancia partículas no ponto de impacto
## Ajuste o caminho do .tres de partículas conforme seu projeto
func _spawn_hit_effect(position: Vector3) -> void:
	match equipped_weapon.effect:
		Weapon.AttackEffect.SPARKS:
			_spawn_particles(position, "res://effects/particles_sparks.tres")
		Weapon.AttackEffect.DARK_AURA:
			_spawn_particles(position, "res://effects/particles_dark.tres")
		Weapon.AttackEffect.STUN_LONG_AOE:
			_spawn_particles(position, "res://effects/particles_shockwave.tres")
		Weapon.AttackEffect.MINE_EXPLODE:
			_spawn_particles(position, "res://effects/particles_explosion.tres")

func _spawn_particles(position: Vector3, particles_path: String) -> void:
	# Verifica se o arquivo existe antes de tentar carregar
	if not ResourceLoader.exists(particles_path):
		return

	var particles_scene = load(particles_path)
	if particles_scene == null:
		return

	var particles = particles_scene.instantiate()
	get_tree().current_scene.add_child(particles)
	particles.global_position = position

	# Auto-remove após a animação terminar (ajuste o tempo se precisar)
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	particles.add_child(timer)
	timer.timeout.connect(particles.queue_free)
	timer.start()
