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

@export_group("Referências")
@export var camera_node: Node3D = null            # Câmera do player (para projéteis). Se vazio, tenta "Camera3D".

@export_group("Slots no corpo (BoneAttachment/Pivot)")
## Pivot (Node3D) onde fica o modelo da arma do inventário quando não está na mão.
@export var slot_display_melee: NodePath = NodePath("")
@export var slot_display_staff: NodePath = NodePath("")
@export var slot_display_axe: NodePath = NodePath("")
@export var slot_display_pickaxe: NodePath = NodePath("")
## Escala do modelo no corpo (nas costas/quadril). Ajuste se ficar grande ou pequeno.
@export var slot_model_scale: float = 0.5

# ================= ESTADO =================
var equipped_weapon: Weapon = null
var weapon_model: Node3D = null         # Referência ao modelo 3D na mão
var _slot_models: Dictionary = {}       # Weapon.ToolSlot (int) -> Node3D (modelo instanciado no pivot)
var attack_cooldown_timer: float = 0.0
var _attack_done_this_frame: bool = false  # Evita som/ataque duplicado no mesmo frame (ex.: "attack" e "mb1" juntos)
var is_attacking: bool = false
## Direção do último ataque melee (trava o hit ao pressionar ataque — não segue o movimento).
var _melee_attack_forward: Vector3 = Vector3.FORWARD

## Distância máxima em metros que o jogador pode se mover durante a coleta; além disso cancela.
@export var harvest_move_cancel_distance: float = 0.2

# ================= SWING (animação de ataque) =================
var swing_progress: float = 0.0         # 0.0 = posição de repouso, 1.0 = fim do swing
var is_swinging: bool = false
@export var swing_angle: float = -90.0  # Ângulo do swing em graus (negativo = pra frente)
@export var swing_duration: float = 0.15 # Tempo do swing ida (rápido)
@export var swing_return_duration: float = 0.25 # Tempo da volta (mais lento, com easing)

# ================= MÓDULOS (harvest e projéteis) =================
var _harvest_controller: Node = null
var _projectile_launcher: Node = null

# ================= RASTRO DA ESPADA =================
var _sword_trail: Node = null
@onready var audio_player: AudioStreamPlayer3D = $AttackAudio

func _setup_sword_trail() -> void:
	if hand_marker == null:
		return
	var trail_script := load("res://Scripts/player/SwordTrail.gd") as GDScript
	if trail_script == null:
		return
	_sword_trail = Node3D.new()
	_sword_trail.set_script(trail_script)
	_sword_trail.name = "SwordTrail"
	add_child(_sword_trail)
	_sword_trail.set_tip_source(hand_marker)

func _apply_weapon_trail_settings(weapon: Weapon) -> void:
	if _sword_trail == null or not weapon:
		return
	_sword_trail.tip_offset = weapon.trail_tip_offset
	_sword_trail.trail_color = weapon.trail_color
	_sword_trail.ribbon_width = weapon.trail_ribbon_width
	_sword_trail.trail_duration = weapon.trail_duration
	_sword_trail.point_lifetime = weapon.trail_point_lifetime

# ================= INICIALIZAÇÃO =================
func _ready():
	if _harvest_controller == null:
		_harvest_controller = preload("res://Scripts/player/HarvestController.gd").new()
		_harvest_controller.name = "HarvestController"
		add_child(_harvest_controller)
	if _projectile_launcher == null:
		_projectile_launcher = preload("res://Scripts/player/ProjectileLauncher.gd").new()
		_projectile_launcher.name = "ProjectileLauncher"
		add_child(_projectile_launcher)
	if hand_marker == null:
		hand_marker = get_node_or_null("../Character/CharacterArmature/Skeleton3D/HandMarker") as Node3D
		if hand_marker == null:
			hand_marker = get_node_or_null("../Char/Skeleton/BoneAttachment3D/hand_marker") as Node3D
		if hand_marker == null:
			push_warning("WeaponHandler: hand_marker não encontrado. Armas não aparecerão na mão.")
	# AttackArea é irmão do WeaponHandler (filho do player); pega automaticamente se não atribuído
	if attack_area == null:
		attack_area = get_parent().get_node_or_null("AttackArea") as Area3D
	if attack_area != null:
		attack_area.monitoring = true
		attack_area.collision_mask = 1  # layer 1 = personagens/inimigos
	if camera_node == null:
		camera_node = get_parent().get_node_or_null("Camera3D") as Node3D
	if ToolSelectionManager:
		ToolSelectionManager.tool_changed.connect(_update_slot_displays)
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_update_slot_displays)
	if audio_player:
		audio_player.bus = &"SFX"
	# Rastro na ponta da espada (efeito vento ao atacar)
	_setup_sword_trail()
	# Atualiza após inventário e tool estarem prontos (dois frames).
	call_deferred("_update_slot_displays")
	await get_tree().process_frame
	await get_tree().process_frame
	_update_slot_displays()
	# Aplica o rastro da arma equipada inicialmente (se houver)
	if equipped_weapon:
		_apply_weapon_trail_settings(equipped_weapon)

# ================= EQUIPAR / DESEQUIPAR =================

## Equipa uma arma
func equip(weapon: Weapon) -> void:
	if weapon == null:
		unequip()
		return

	unequip()  # Garante que desequipa antes (limpa modelo anterior)
	equipped_weapon = weapon
	_load_weapon_model()
	_apply_weapon_trail_settings(weapon)
	_update_slot_displays()
	emit_signal("weapon_equipped", weapon)

## Desequipa a arma atual
func unequip() -> void:
	equipped_weapon = null
	_remove_weapon_model()
	_update_slot_displays()
	emit_signal("weapon_unequipped")

## Inicia modo coleta: aplica dano ao recurso a cada attack_speed até morrer. Chamado após E em árvore/pedra.
func start_harvesting(resource_node: Node) -> void:
	if _harvest_controller and _harvest_controller.has_method("start_harvesting"):
		_harvest_controller.start_harvesting(resource_node)

func _stop_harvesting() -> void:
	if _harvest_controller and _harvest_controller.has_method("stop_harvesting"):
		_harvest_controller.stop_harvesting()

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

## Retorna o pivot (Node3D) para o slot; usa export path ou fallback pelo nome no skeleton.
func _get_pivot_for_slot(tool_slot: int) -> Node3D:
	var path: NodePath
	match tool_slot:
		Weapon.ToolSlot.MELEE:   path = slot_display_melee
		Weapon.ToolSlot.STAFF:   path = slot_display_staff
		Weapon.ToolSlot.AXE:     path = slot_display_axe
		Weapon.ToolSlot.PICKAXE: path = slot_display_pickaxe
		_: return null
	if not path.is_empty():
		var n: Node = get_node_or_null(path)
		if n is Node3D:
			return n as Node3D
	# Fallback: buscar pelo skeleton no player
	var player: Node = get_parent()
	if not player:
		return null
	var skeleton: Node = player.get_node_or_null("UAL2_Standard/Armature/Skeleton")
	if not skeleton:
		return null
	var attach_name: String
	match tool_slot:
		Weapon.ToolSlot.MELEE:   attach_name = "AttachmentMelee/Node3D"
		Weapon.ToolSlot.STAFF:   attach_name = "AttachmentStaff/Node3D"
		Weapon.ToolSlot.AXE:     attach_name = "AttachmentAxe/Node3D"
		Weapon.ToolSlot.PICKAXE: attach_name = "AttachmentPickaxe/Node3D"
		_: return null
	var pivot: Node = skeleton.get_node_or_null(attach_name)
	return pivot as Node3D if pivot is Node3D else null

## Mostra no pivot o modelo da arma equipada no inventário; some quando está em uso (na mão).
## Não altera transform do pivot — posição/rotação ficam só na cena do player.
## Pode ser chamada pelo sinal tool_changed(active_slot: int); o argumento é ignorado.
func _update_slot_displays(_new_slot: int = -1) -> void:
	if not ToolSelectionManager or not InventoryManager:
		return
	var active: int = ToolSelectionManager.active_tool_slot
	for tool_slot in [Weapon.ToolSlot.MELEE, Weapon.ToolSlot.STAFF, Weapon.ToolSlot.AXE, Weapon.ToolSlot.PICKAXE]:
		# Remove modelo antigo desse slot
		if _slot_models.has(tool_slot):
			var old: Node = _slot_models[tool_slot]
			_slot_models.erase(tool_slot)
			if is_instance_valid(old):
				old.queue_free()
		var pivot: Node3D = _get_pivot_for_slot(tool_slot)
		if not pivot:
			continue
		var w: Weapon = InventoryManager.get_equipped_weapon(tool_slot)
		var should_show: bool = (w != null) and (active != tool_slot)
		if not should_show:
			continue
		if w.model_scene == null:
			push_warning("WeaponHandler: '%s' não tem model_scene." % w.item_name)
			continue
		# Limpa filhos antigos do pivot (modelo anterior ou cena estática)
		for child in pivot.get_children():
			if is_instance_valid(child):
				child.queue_free()
		var model: Node3D = w.model_scene.instantiate() as Node3D
		if not model:
			continue
		model.scale = Vector3(slot_model_scale, slot_model_scale, slot_model_scale)
		pivot.add_child(model)
		_slot_models[tool_slot] = model

## Retorna a arma equipada atual (ou null)
func get_equipped() -> Weapon:
	return equipped_weapon

## Retorna o progresso do cooldown de ataque: 0 = acabou de atacar, 1 = pronto. Para barra na UI.
func get_attack_cooldown_progress() -> float:
	if equipped_weapon == null:
		return 1.0
	if equipped_weapon.attack_speed <= 0.0:
		return 1.0
	return clampf(1.0 - (attack_cooldown_timer / equipped_weapon.attack_speed), 0.0, 1.0)

# ================= ATAQUE =================

func _physics_process(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	_attack_done_this_frame = false

	if _harvest_controller and _harvest_controller.has_method("tick") and _harvest_controller.tick(delta):
		return

	if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("mb1"):
		_try_attack()

## Tenta realizar um ataque
func _try_attack() -> void:
	# Só um ataque por frame (evita som duplo quando "attack" e "mb1" disparam juntos)
	if _attack_done_this_frame:
		return
	# Sem arma equipada — não faz nada
	if equipped_weapon == null:
		return
	# Ainda no cooldown — não ataca nem toca som
	if attack_cooldown_timer > 0.001:
		return

	_attack_done_this_frame = true
	# Seta o cooldown baseado na velocidade da arma
	attack_cooldown_timer = equipped_weapon.attack_speed

	var player = get_parent() as Node3D
	# Trava a direção do ataque na direção da câmera; só vira o personagem se estiver muito desalinhado (evita câmera “pulando”)
	if camera_node and is_instance_valid(camera_node):
		var cam_fwd := -camera_node.global_transform.basis.z
		cam_fwd.y = 0
		if cam_fwd.length_squared() > 0.01:
			cam_fwd = cam_fwd.normalized()
			_melee_attack_forward = cam_fwd
			# Só faz look_at se o personagem estiver bem desviado da mira (evita snap da câmera a cada golpe)
			if player:
				var cur_fwd = -player.global_transform.basis.z
				cur_fwd.y = 0
				if cur_fwd.length_squared() > 0.01:
					cur_fwd = cur_fwd.normalized()
					if cur_fwd.dot(cam_fwd) < 0.92:
						player.look_at(player.global_position + cam_fwd)
	else:
		_melee_attack_forward = -player.global_transform.basis.z if player else Vector3.FORWARD
		_melee_attack_forward.y = 0
		if _melee_attack_forward.length_squared() > 0.01:
			_melee_attack_forward = _melee_attack_forward.normalized()

	# Notifica o Player: animação de ataque e som sempre ao atacar
	if player and player.has_method("play_attack_animation"):
		var anim_name := "Attack" if not equipped_weapon.can_mine() else "Work"
		player.play_attack_animation(anim_name)

	_play_attack_sound()
	_play_viewmodel_swing()

	# Roteia para melee ou ranged
	match equipped_weapon.weapon_type:
		Weapon.WeaponType.MELEE:
			_attack_melee()
		Weapon.WeaponType.RANGED:
			_attack_ranged()

# ================= SWING =================

# ================= MELEE (por área — estilo roguelike) =================

func _attack_melee() -> void:
	# Rastro na ponta da espada (configurado por arma: cor, largura, etc.)
	if _sword_trail and _sword_trail.has_method("start_trail") and equipped_weapon and equipped_weapon.trail_enabled and not equipped_weapon.can_mine():
		_apply_weapon_trail_settings(equipped_weapon)
		_sword_trail.start_trail()

	var hit_targets = _get_melee_overlap_targets()
	for target in hit_targets:
		if not is_instance_valid(target):
			continue
		if _is_enemy(target):
			_apply_damage(target)
			_apply_melee_effect(target)
		elif target.has_method("take_hit"):
			# Árvore, pedra, etc. (ResourceNode)
			target.take_hit(equipped_weapon.damage)
			emit_signal("attack_hit", target, equipped_weapon.damage)

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

## Retorna lista de alvos do melee usando a direção TRAVADA no momento do ataque (não segue o movimento).
## Usa shape query na direção _melee_attack_forward para combate mais dinâmico e acertos consistentes.
func _get_melee_overlap_targets() -> Array:
	var player = get_parent() as Node3D
	if player == null:
		return []

	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return []

	var forward := _melee_attack_forward
	if forward.length_squared() < 0.01:
		forward = -player.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()

	# Caixa na frente na direção do ataque (alcance um pouco maior para combate mais frenético)
	var range_mult := 1.15
	var origin = player.global_position + Vector3(0.0, 1.0, 0.0) + forward * (melee_range * 0.5 * range_mult)
	var basis := Basis.looking_at(forward, Vector3.UP)
	var shape_transform := Transform3D(basis, origin)

	var box := BoxShape3D.new()
	box.size = Vector3(melee_half_extents.x * 2.2, melee_half_extents.y * 2.0, melee_range * range_mult)

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.transform = shape_transform
	params.collide_with_bodies = true
	params.collide_with_areas = false
	if player is PhysicsBody3D:
		params.exclude = [player.get_rid()]

	var results = space_state.intersect_shape(params)
	var targets: Array = []
	for dict in results:
		var collider = dict.get("collider", null)
		if collider != null and (_is_enemy(collider) or collider.has_method("take_hit")):
			targets.append(collider)
	return targets

## Aplica dano ao inimigo
func _apply_damage(target: Node3D) -> void:
	var damage = equipped_weapon.damage
	var player = get_parent()
	var knockback := equipped_weapon.knockback_force if equipped_weapon else 0.0

	if target.has_method("take_damage"):
		target.take_damage(damage, player, knockback)
		emit_signal("attack_hit", target, damage)

## Aplica efeitos específicos do ataque melee (stun, knockback, etc.)
func _apply_melee_effect(target: Node3D) -> void:
	var effect = equipped_weapon.effect

	# Knockback é aplicado no próprio mob em take_damage (persiste e não é sobrescrito pela AI)

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
	if _projectile_launcher and _projectile_launcher.has_method("launch"):
		_projectile_launcher.launch()

# ================= ANIMAÇÃO VIEWMODEL (FPS) =================

## Dispara o swing visual da arma no ViewModelPivot (primeiro pessoa).
func _play_viewmodel_swing() -> void:
	if camera_node == null:
		return
	var vmp := camera_node.get_node_or_null("ViewModelPivot") as Node3D
	if vmp and vmp.has_method("play_swing"):
		vmp.play_swing()

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
