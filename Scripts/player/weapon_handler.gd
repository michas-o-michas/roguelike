# weapon_handler.gd
# Attach diretamente no seu Player (CharacterBody3D).
# Gerencia: arma equipada, ataques melee (por ÁREA — estilo roguelike), projéteis e efeitos.
#
# Melee: usa um "arco" na frente do personagem (overlap), não RayCast — mais perdoável
# e combina melhor com jogos de ação/roguelike. Mineração continua opcional com RayCast.
#
# Como usar:
#   1. Seleciona o Player no editor
#   2. Attach script > seleciona weapon_handler.gd
#   3. No Inspector: hand_marker = nó da mão (ex: Character/CharacterArmature/Skeleton3D/HandMarker); attack_raycast = opcional
#   4. Equipa uma arma via código: $WeaponHandler.equip(sword)

extends Node3D

# ================= SINAIS =================
signal weapon_equipped(weapon: Weapon)
signal weapon_unequipped
signal attack_hit(target: Node3D, damage: int)

# ================= EXPORTS =================
@export var hand_marker: Node3D  # Onde a arma aparece (ex: Character/CharacterArmature/Skeleton3D/HandMarker)
@export var weapon_display_scale: float = 0.01  # Escala do modelo na mão (muitos .glb vêm gigantes; 0.01 = 1%)

@export_group("Melee (arco na frente — estilo roguelike)")
@export var attack_area: Area3D = null            # AttackArea com CollisionShape3D — arraste aqui (prioridade)
@export var melee_range: float = 2.0              # Usado só se attack_area estiver vazio
@export var melee_half_extents: Vector3 = Vector3(0.7, 0.5, 0.6)  # Idem: fallback em código

@export_group("Mineração (opcional)")
@export var attack_raycast: RayCast3D = null      # Só para minerar: mirar em rocha/árvore (deixe vazio se não usar)

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
	if hand_marker == null:
		hand_marker = get_node_or_null("../Character/CharacterArmature/Skeleton3D/HandMarker") as Node3D
		if hand_marker == null:
			push_warning("WeaponHandler: hand_marker não encontrado. Armas não aparecerão na mão.")
	if attack_area != null:
		attack_area.monitoring = true

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
	if equipped_weapon == null:
		return
	if hand_marker == null:
		push_warning("WeaponHandler: hand_marker é null. Defina no Inspector (Character/.../HandMarker).")
		return
	if equipped_weapon.model_scene != null:
		weapon_model = equipped_weapon.model_scene.instantiate()
		weapon_model.scale = Vector3(weapon_display_scale, weapon_display_scale, weapon_display_scale)
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
	print("attacando")

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

# ================= MELEE (por área — estilo roguelike) =================

func _attack_melee() -> void:
	_start_swing()

	# Hitbox em arco na frente do personagem (não depende de mira com RayCast)
	var hit_targets = _get_melee_overlap_targets()
	for target in hit_targets:
		if is_instance_valid(target) and _is_enemy(target):
			_apply_damage(target)
			_apply_melee_effect(target)

	# Mineração: opcional, só se tiver RayCast (mirar em rocha/árvore)
	if equipped_weapon.can_mine() and attack_raycast != null:
		attack_raycast.force_raycast_update()
		if attack_raycast.is_colliding():
			var collider = attack_raycast.get_collider()
			if collider != null and collider.is_in_group("minable"):
				_try_mine_target(collider)

## True se o nó é considerado inimigo (grupo "enemy" ou "enemies" — lobo usa "enemy")
func _is_enemy(node: Node) -> bool:
	return node.is_in_group("enemy") or node.is_in_group("enemies")

## Retorna lista de corpos na área de melee (inimigos no "arco" na frente do player)
## Se attack_area estiver atribuído, usa get_overlapping_bodies(); senão usa hitbox em código.
func _get_melee_overlap_targets() -> Array:
	# Prioridade: Area3D (AttackArea) que você ajustou no editor
	if attack_area != null:
		var targets: Array = []
		for body in attack_area.get_overlapping_bodies():
			if is_instance_valid(body) and _is_enemy(body):
				targets.append(body)
		return targets

	# Fallback: hitbox gerado em código (quando não tem AttackArea na cena)
	var player = get_parent() as Node3D
	if player == null:
		return []

	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return []

	var forward = -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.length_squared() < 0.01:
		forward = -player.global_transform.basis.z.normalized()

	var origin = player.global_position + Vector3(0.0, 1.0, 0.0) + forward * melee_range
	var basis := Basis.looking_at(forward, Vector3.UP)
	var shape_transform := Transform3D(basis, origin)

	var box := BoxShape3D.new()
	box.size = melee_half_extents * 2.0

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.transform = shape_transform
	if player is PhysicsBody3D:
		params.exclude = [player.get_rid()]

	var results = space_state.intersect_shape(params)
	var targets: Array = []
	for dict in results:
		var collider = dict.get("collider", null)
		if collider != null and _is_enemy(collider):
			targets.append(collider)
	return targets

## Aplica dano ao inimigo
func _apply_damage(target: Node3D) -> void:
	var damage = equipped_weapon.damage
	var player = get_parent()

	if target.has_method("take_damage"):
		target.take_damage(damage, player)
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

## Dano em área ao redor do ponto de impacto (inimigos no raio)
func _apply_aoe_damage(center: Vector3) -> void:
	var aoe_radius := 3.0
	var aoe_damage := int(equipped_weapon.damage * 0.5)  # 50% do dano principal

	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = aoe_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, center)

	var player = get_parent()
	var results = space_state.intersect_shape(params)
	for dict in results:
		var target = dict.get("collider", null)
		if target != null and _is_enemy(target) and target.has_method("take_damage"):
			target.take_damage(aoe_damage, player)

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
func _spawn_hit_effect(pos: Vector3) -> void:
	match equipped_weapon.effect:
		Weapon.AttackEffect.SPARKS:
			_spawn_particles(pos, "res://effects/particles_sparks.tres")
		Weapon.AttackEffect.DARK_AURA:
			_spawn_particles(pos, "res://effects/particles_dark.tres")
		Weapon.AttackEffect.STUN_LONG_AOE:
			_spawn_particles(pos, "res://effects/particles_shockwave.tres")
		Weapon.AttackEffect.MINE_EXPLODE:
			_spawn_particles(pos, "res://effects/particles_explosion.tres")

func _spawn_particles(pos: Vector3, particles_path: String) -> void:
	# Verifica se o arquivo existe antes de tentar carregar
	if not ResourceLoader.exists(particles_path):
		return

	var particles_scene = load(particles_path)
	if particles_scene == null:
		return

	var particles = particles_scene.instantiate()
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos

	# Auto-remove após a animação terminar (ajuste o tempo se precisar)
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	particles.add_child(timer)
	timer.timeout.connect(particles.queue_free)
	timer.start()
