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
var is_attacking: bool = false

# Coleta (E em recurso): machado/picareta aplicam dano em intervalo até o recurso morrer
var is_harvesting: bool = false
var harvest_target: Node = null
var harvest_timer: float = 0.0
var harvest_start_position: Vector3 = Vector3.ZERO
## Distância máxima em metros que o jogador pode se mover durante a coleta; além disso cancela.
@export var harvest_move_cancel_distance: float = 0.2

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
	# Atualiza após inventário e tool estarem prontos (dois frames).
	call_deferred("_update_slot_displays")
	await get_tree().process_frame
	await get_tree().process_frame
	_update_slot_displays()

# ================= EQUIPAR / DESEQUIPAR =================

## Equipa uma arma
func equip(weapon: Weapon) -> void:
	if weapon == null:
		unequip()
		return

	unequip()  # Garante que desequipa antes (limpa modelo anterior)
	equipped_weapon = weapon
	_load_weapon_model()
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
	if resource_node == null or not resource_node.has_method("take_hit"):
		return
	_stop_harvesting()
	harvest_target = resource_node
	is_harvesting = true
	harvest_timer = 0.0
	var player = get_parent() as Node3D
	harvest_start_position = player.global_position if player else Vector3.ZERO
	if resource_node is ResourceNode and not resource_node.depleted.is_connected(_on_harvest_target_depleted):
		resource_node.depleted.connect(_on_harvest_target_depleted)
	player = get_parent()
	if player.has_method("play_attack_animation"):
		player.play_attack_animation("Attack")

func _on_harvest_target_depleted() -> void:
	_stop_harvesting()

func _stop_harvesting() -> void:
	if harvest_target != null and is_instance_valid(harvest_target) and harvest_target is ResourceNode:
		if harvest_target.depleted.is_connected(_on_harvest_target_depleted):
			harvest_target.depleted.disconnect(_on_harvest_target_depleted)
	is_harvesting = false
	harvest_target = null
	harvest_timer = 0.0
	var player = get_parent()
	if player.has_method("stop_attack_animation"):
		player.stop_attack_animation()

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

# ================= ATAQUE =================

func _physics_process(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	# Loop de coleta (E em árvore/pedra): aplica dano a cada attack_speed até o recurso morrer
	if is_harvesting and harvest_target != null:
		if not is_instance_valid(harvest_target):
			_stop_harvesting()
		else:
			# Cancelar se o jogador se moveu (saiu do lugar)
			var player_node := get_parent() as Node3D
			if player_node and (player_node.global_position - harvest_start_position).length() > harvest_move_cancel_distance:
				_stop_harvesting()
				return
			harvest_timer += delta
			if equipped_weapon != null and harvest_timer >= equipped_weapon.attack_speed:
				harvest_timer = 0.0
				var player = get_parent()
				if player.has_method("play_attack_animation"):
					player.play_attack_animation("Attack")
				if harvest_target.has_method("take_hit"):
					harvest_target.take_hit(equipped_weapon.damage)
				# Para assim que o recurso acaba (health <= 0), sem esperar queue_free()
				if harvest_target is ResourceNode and harvest_target.health <= 0:
					_stop_harvesting()
				elif not is_instance_valid(harvest_target):
					_stop_harvesting()
		return

	if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("mb1"):
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

	# Notifica o Player: ferramentas (mineração) usam "Work", armas usam "Attack"
	var player = get_parent()
	if player.has_method("play_attack_animation"):
		var anim_name := "Attack" if not equipped_weapon.can_mine() else "Attack"
		player.play_attack_animation(anim_name)

	# Toca o som do ataque
	_play_attack_sound()

	# Roteia para melee ou ranged
	match equipped_weapon.weapon_type:
		Weapon.WeaponType.MELEE:
			_attack_melee()
		Weapon.WeaponType.RANGED:
			_attack_ranged()

# ================= SWING =================

# ================= MELEE (por área — estilo roguelike) =================

func _attack_melee() -> void:

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

## Retorna lista de corpos na área de melee (inimigos + árvores/recursos na frente do player)
## Se attack_area estiver atribuído, usa get_overlapping_bodies(); senão usa hitbox em código.
func _get_melee_overlap_targets() -> Array:
	# Prioridade: Area3D (AttackArea)
	if attack_area != null:
		var targets: Array = []
		for body in attack_area.get_overlapping_bodies():
			if is_instance_valid(body) and (_is_enemy(body) or body.has_method("take_hit")):
				targets.append(body)
		return targets

	# Fallback: hitbox em código
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

	# Caixa na frente do player (centro um pouco à frente para acertar melhor)
	var origin = player.global_position + Vector3(0.0, 1.0, 0.0) + forward * (melee_range * 0.6)
	var basis := Basis.looking_at(forward, Vector3.UP)
	var shape_transform := Transform3D(basis, origin)

	var box := BoxShape3D.new()
	box.size = melee_half_extents * 2.0

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
	# Magia selecionada na hotbar (modo cajado): 1-9 selecionam, clique dispara
	var spell: Spell = SpellManager.get_selected_spell() if SpellManager else null
	var proj_scene: PackedScene = equipped_weapon.projectile_scene
	if spell and spell.projectile_scene != null:
		proj_scene = spell.projectile_scene
	if proj_scene == null:
		push_warning("WeaponHandler: Staff sem projectile_scene assignada!")
		return

	var projectile = proj_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	var player = get_parent()
	var cam = camera_node if camera_node != null else player.get_node_or_null("Camera3D") as Node3D
	if cam == null:
		push_warning("WeaponHandler: câmera não definida. Defina camera_node no Inspector.")
		return
	# Usar o mesmo centro da tela que o raycast (InteractionManager) para mira e projétil alinhados
	var vp := cam.get_viewport()
	var center := vp.get_visible_rect().size / 2
	var direction := (cam as Camera3D).project_ray_normal(center).normalized()

	projectile.global_position = cam.global_position
	var ptype: int = equipped_weapon.projectile_type
	if spell:
		ptype = spell.projectile_type

	if projectile.has_method("setup"):
		projectile.setup(
			direction,
			equipped_weapon.projectile_speed,
			equipped_weapon.damage,
			ptype
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
