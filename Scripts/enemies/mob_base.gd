extends CharacterBody3D
## Base genérica para todos os mobs: lobo, vaca, coelho, zumbi, atirador, etc.
## Usa HealthComponent; stats e comportamento vêm do MobData que o SPAWNER seta ao instanciar.
## Não preencha mob_data na cena — o spawner chama set_mob_data() ao spawne. Preencha só para testar a cena sozinha no editor.

## Opcional na cena. No jogo o spawner sempre seta ao instanciar. Use só para testar esta cena no editor.
@export var mob_data: MobData

var _health_component: HealthComponent
var _player: Node3D
var _provoked: bool = false
var _attack_cooldown: float = 0.0

@export_group("AI")
## Raio em que o mob detecta o jogador (persegue/ataca). Spawner coloca mobs ~50–80 m do jogador; use ≥ 25 para reagir ao se aproximar.
@export var detection_radius: float = 30.0
## Alcance do golpe (distância ao jogador para iniciar ataque). Pode ser sobrescrito por MobData.attack_radius.
@export var attack_radius: float = 2.0
@export var attack_cooldown_time: float = 1.2
## Atraso em segundos do início da animação até o momento em que o dano é aplicado (telegrafado).
@export var attack_hit_delay: float = 0.25
## Area3D opcional: se definido, o dano só é aplicado se o jogador estiver dentro da área no momento do hit.
@export var attack_area_path: NodePath = NodePath("")
@export var provocation_radius: float = 4.0
@export var flee_radius: float = 8.0
## NEUTRAL: raio máximo de perseguição quando provocado (evita perseguir longe).
@export var neutral_chase_radius: float = 12.0
@export var gravity: float = 22.0
## Quando longe do jogador: velocidade de vaguear = speed * este valor (ex.: 0.35).
@export var wander_speed_ratio: float = 0.35
## Duração de cada “passada” de vaguear (segundos), antes de escolher nova direção.
@export var wander_duration_min: float = 1.5
@export var wander_duration_max: float = 4.0
## Chance 0–1 de ficar parado um ciclo em vez de andar (ex.: 0.2 = 20%).
@export var wander_idle_chance: float = 0.15
## Se true, no primeiro frame faz raycast para colar os pés no chão (evita nascer embaixo do terreno)
@export var snap_to_ground_on_spawn: bool = true

@export_group("Animações")
## Deixe vazio para usar o nó "AnimationTree" da cena (padrão do lobo e da maioria dos mobs).
@export var animation_tree_path: NodePath = NodePath("")
## Deixe vazio para usar o nó "AnimationPlayer" da cena. Só usado se não houver AnimationTree.
@export var animation_player_path: NodePath = NodePath("")
## Duração da animação de ataque (segundos).
@export var attack_anim_duration: float = 0.5
## Logs de AI/dano no console (debug).
@export var debug_log: bool = false
## Desenha a área de ataque (esfera) para visualizar no jogo. Desligue para melhor performance com muitos inimigos.
@export var draw_attack_area: bool = false
## Ao morrer, usa shader de decomposição antes de remover (requer DissolutionHelper no autoload).
@export var use_dissolution_on_death: bool = true

@export_group("Barra de vida")
## Cores da barra de vida (borda, fundo, vida, dano). Customize por mob na cena do inimigo.
@export var health_bar_border_color: Color = Color(0.93, 0.79, 0, 1)
@export var health_bar_bg_color: Color = Color(0, 0, 0, 0.59)
@export var health_bar_fill_color: Color = Color(0.22, 0.52, 0.28, 1)
@export var health_bar_damage_color: Color = Color(0.59, 0, 0, 1)

const FLOOR_SNAP_LENGTH := 0.2
const GROUND_CLEARANCE := 0.15
const MOB_HEALTH_BAR_SCENE := preload("res://Componentes/MobHealthBar.tscn")
const FLOATING_DAMAGE_SCENE := preload("res://Componentes/DamageNumber.tscn")
const PICKUP_SCENE := preload("res://pickup.tscn")

var _animation_tree: AnimationTree
var _animation_player: AnimationPlayer
var _is_playing_attack_anim: bool = false
var _attack_anim_end_time: float = 0.0
var _current_anim_name: String = ""
var _last_log_chase_time: float = -999.0
var _logged_no_mob_data: bool = false
## Ataque telegrafado: momento em que o dano é aplicado
var _attack_pending_hit_time: float = -1.0
var _attack_damage_pending: bool = false
var _pending_damage: float = 0.0
var _pending_armor_piercing: float = 0.0
var _attack_area: Area3D = null
## Se true, no próximo frame aplicamos o dano (após Area3D atualizar overlapping)
var _attack_hit_window_active: bool = false
## Posição em que morreu; usada para congelar o corpo no lugar (evita afundar sem colisão)
var _death_position: Vector3 = Vector3.ZERO
## Knockback recebido (empurrão ao levar dano); somado à velocity e decai a cada frame.
var _knockback_remaining: Vector3 = Vector3.ZERO
## Vaguear: tempo restante na direção atual; quando ≤ 0, escolhe nova direção
var _wander_timer: float = 0.0
var _wander_direction: Vector2 = Vector2.ZERO
## Para performance: inimigos longe do jogador atualizam AI em frames alternados.
var _ai_tick: int = 0
const _AI_SKIP_FRAMES_WHEN_FAR := 3
const _ANIM_IDLE := "Idle"
const _ANIM_WALK := "Walk"
const _ANIM_RUN := "Run"
const _ANIM_ATTACK := "Attack"
const _ANIM_DEATH := "Death"
## Nomes alternativos por estado (minúscula / variações) para fallback
const _ANIM_ALIASES: Dictionary = {
	"Idle": ["Idle", "idle", "IDLE"],
	"Walk": ["Walk", "walk", "Walking", "walking"],
	"Run": ["Run", "run", "Running", "running"],
	"Attack": ["Attack", "attack", "Attacking"],
	"Death": ["Death", "death", "Dead", "dead"]
}
var _logged_no_anim: bool = false

func _ready() -> void:
	if debug_log:
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

	if attack_area_path:
		_attack_area = get_node_or_null(attack_area_path) as Area3D
		if _attack_area:
			_attack_area.monitoring = false
			_attack_area.monitorable = false
			if draw_attack_area:
				_create_attack_area_visual()

	# Animações: paths vazios = usar nós padrão "AnimationTree" e "AnimationPlayer" (ex.: lobo).
	# Só preencher animation_tree_path / animation_player_path no Inspector se os nós tiverem outro nome ou estiverem em outro nó.
	var tree_path: NodePath = animation_tree_path
	var player_path: NodePath = animation_player_path
	if tree_path.is_empty():
		tree_path = NodePath("AnimationTree")
	if player_path.is_empty():
		player_path = NodePath("AnimationPlayer")

	if tree_path:
		_animation_tree = get_node_or_null(tree_path) as AnimationTree
		if _animation_tree:
			_animation_tree.active = true
			call_deferred("_set_animation", _ANIM_IDLE)
	if not _animation_tree and player_path:
		_animation_player = get_node_or_null(player_path) as AnimationPlayer
		if _animation_player:
			_set_animation(_ANIM_IDLE)
	if not _animation_tree and not _animation_player and not _logged_no_anim:
		_logged_no_anim = true
		push_warning("MobBase: nenhum AnimationTree nem AnimationPlayer em '%s'. Defina animation_tree_path/animation_player_path ou use nós 'AnimationTree'/'AnimationPlayer'." % name)

	# Barra de vida flutuante ligada ao HealthComponent (mostra HP e atualiza ao tomar dano)
	_setup_floating_health_bar()

	# Garantir que o mob está na layer 1 para a AttackArea do player detectar (melee)
	collision_layer = 1
	collision_mask = 1

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
	if mob_data.attack_radius > 0:
		attack_radius = mob_data.attack_radius
	if mob_data.attack_cooldown > 0:
		attack_cooldown_time = mob_data.attack_cooldown
	if mob_data.neutral_chase_radius > 0:
		neutral_chase_radius = mob_data.neutral_chase_radius

	if mob_data.animation_tree_path_override:
		animation_tree_path = mob_data.animation_tree_path_override
	if mob_data.animation_player_path_override:
		animation_player_path = mob_data.animation_player_path_override

	if mob_data.is_hostile():
		add_to_group("enemy")

func take_damage(amount: float, attacker: Node = null, knockback_strength: float = 0.0) -> float:
	if not _health_component:
		return 0.0
	if mob_data and mob_data.behaviour == MobData.Behaviour.PASSIVE_AGGRESSIVE and attacker != null:
		_provoked = true
	if mob_data and mob_data.behaviour == MobData.Behaviour.NEUTRAL and attacker != null:
		_provoked = true
	if knockback_strength > 0.0 and attacker is Node3D:
		var dir := (global_position - (attacker as Node3D).global_position).normalized()
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			dir = dir.normalized()
			_knockback_remaining += dir * knockback_strength
	var taken := _health_component.take_damage(amount, 0.0, attacker)
	if taken > 0:
		_spawn_floating_damage(taken)
	if debug_log and taken > 0:
		var name_str = mob_data.display_name if mob_data else name
		print("[MobBase] take_damage: '%s' recebeu %.1f (vida %.1f/%.1f)" % [
			name_str, taken, _health_component.current_health, _health_component.max_health
		])
	SoundManager.play("enimy-hit")
	return taken

func _spawn_floating_damage(amount: float) -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var floating := FLOATING_DAMAGE_SCENE.instantiate()
	tree.current_scene.add_child(floating)
	floating.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	if floating.has_method("set_value"):
		floating.set_value(amount)

func _on_died() -> void:
	remove_from_group("enemy")
	# Congela o corpo na posição atual (evita afundar quando desligamos a colisão)
	_death_position = global_position
	_set_animation(_ANIM_DEATH)
	# Desabilita colisão para o corpo não bloquear o jogador nem projéteis
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	# Drop de moeda (quantidade por mob_data ou padrão)
	_drop_coins()
	if debug_log:
		var name_str = mob_data.display_name if mob_data else name
		print("[MobBase] _on_died: '%s' morreu" % name_str)
	if use_dissolution_on_death and has_node("/root/DissolutionHelper"):
		DissolutionHelper.run(self, 5.0)
	else:
		await get_tree().create_timer(2.0).timeout
		queue_free()

func _drop_coins() -> void:
	# Quantidade de moedas: mob_data pode ter loot_table no futuro; por ora valor por difficulty_tier
	var amount := 1
	if mob_data:
		amount = maxi(1, mob_data.difficulty_tier)
	var pickup := PICKUP_SCENE.instantiate()
	if pickup.has_method("setup"):
		pickup.setup(null, amount)  # null = moeda
	var parent := get_parent()
	if parent:
		parent.add_child(pickup)
	else:
		get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector3(0, 0.5, 0)

func _setup_floating_health_bar() -> void:
	if not _health_component:
		return
	var control: Control = null
	# Se a cena já tem MobHealthBar (ex.: lobo), só conecta ao alvo
	var existing := get_node_or_null("MobHealthBar")
	if existing:
		control = existing.get_child(0) as Control
		control.set_target(self)
	else:
		# Cria a barra por código (outros mobs)
		var bar_root = MOB_HEALTH_BAR_SCENE.instantiate()
		control = bar_root.get_child(0) as Control
		add_child(bar_root)
		control.set_target(self)
	# Aplica as cores definidas neste mob (customização por inimigo)
	if control and control.has_method("set_colors"):
		control.set_colors(health_bar_border_color, health_bar_bg_color, health_bar_fill_color, health_bar_damage_color)

func _create_attack_area_visual() -> void:
	if not _attack_area:
		return
	var col_shape: CollisionShape3D = null
	for child in _attack_area.get_children():
		if child is CollisionShape3D:
			col_shape = child as CollisionShape3D
			break
	if not col_shape or not col_shape.shape:
		return
	var radius := 1.0
	if col_shape.shape is SphereShape3D:
		radius = (col_shape.shape as SphereShape3D).radius
	else:
		return
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = col_shape.transform
	mi.name = "AttackAreaVisual"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.25, 0.1, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	_attack_area.add_child(mi)

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
	# Morto: congela na posição da morte (corpo não afunda sem colisão)
	if _health_component and _health_component.is_dead:
		if _death_position == Vector3.ZERO:
			_death_position = global_position
		global_position = _death_position
		velocity = Vector3.ZERO
		return
	if _attack_cooldown > 0:
		_attack_cooldown -= delta

	# Ataque telegrafado: aplicar dano no momento certo (após attack_hit_delay)
	var now := Time.get_ticks_msec() / 1000.0
	if _attack_damage_pending and now >= _attack_pending_hit_time:
		if _attack_area and not _attack_hit_window_active:
			_attack_area.monitoring = true
			_attack_area.monitorable = false
			_attack_hit_window_active = true
		else:
			_apply_pending_attack()
			_attack_damage_pending = false
			_attack_hit_window_active = false
			if _attack_area:
				_attack_area.monitoring = false
				_attack_area.monitorable = false
	elif _attack_hit_window_active:
		_apply_pending_attack()
		_attack_damage_pending = false
		_attack_hit_window_active = false
		if _attack_area:
			_attack_area.monitoring = false
			_attack_area.monitorable = false

	if not is_instance_valid(_player):
		_player = _get_player()
	if not is_instance_valid(_player):
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	else:
		# Inimigos muito longe: rodar AI só a cada N frames (reduz lag com muitos mobs)
		var dist_sq_to_player := global_position.distance_squared_to(_player.global_position)
		var far_threshold_sq := detection_radius * detection_radius * 1.5
		if dist_sq_to_player > far_threshold_sq:
			_ai_tick += 1
			if _ai_tick % _AI_SKIP_FRAMES_WHEN_FAR != 0:
				# Mantém velocidade atual (não recalcula AI este frame)
				pass
			else:
				_run_ai(delta)
		else:
			_run_ai(delta)
		if debug_log:
			var dist := global_position.distance_to(_player.global_position)
			if dist <= detection_radius and Time.get_ticks_msec() / 1000.0 - _last_log_chase_time > 3.0:
				_last_log_chase_time = Time.get_ticks_msec() / 1000.0
				var name_str = mob_data.display_name if mob_data else name
				print("[MobBase] AI: '%s' perseguindo jogador (dist=%.1f m, vel=%.1f)" % [
					name_str, dist, Vector2(velocity.x, velocity.z).length()
				])

	if not is_on_floor():
		velocity.y -= gravity * delta
	# Aplicar knockback por cima da AI (e decair) para o empurrão ser visível
	velocity += _knockback_remaining
	_knockback_remaining = _knockback_remaining.lerp(Vector3.ZERO, delta * 4.0)
	move_and_slide()
	_update_animation(delta)

## Comportamentos básicos por tipo (MobData.Behaviour):
## PASSIVE: nunca ataca; foge se jogador dentro de flee_radius, senão idle.
## AGGRESSIVE: detecta em detection_radius, persegue e ataca em attack_radius.
## PASSIVE_AGGRESSIVE: idle até jogador entrar em provocation_radius ou atacar o mob; depois = aggressive.
## NEUTRAL: idle até ser atacado (provoked); quando provocado, persegue só até neutral_chase_radius e ataca.
func _run_ai(delta: float) -> void:
	if not mob_data:
		_ai_idle(delta)
		if debug_log and not _logged_no_mob_data:
			_logged_no_mob_data = true
			print("[MobBase] _run_ai: mob_data é null, AI em idle. Nome: ", name)
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
				_ai_wander(delta)
		MobData.Behaviour.NEUTRAL:
			if _provoked:
				_ai_neutral_provoked(dist, dist_sq, speed_val, delta)
			else:
				_ai_wander(delta)

func _ai_passive(dist: float, delta: float) -> void:
	# PASSIVE: nunca ataca; foge se jogador perto, senão fica parado
	if dist < flee_radius:
		var away := (global_position - _player.global_position).normalized()
		away.y = 0
		var flee_speed := mob_data.speed * 0.85 if mob_data else 4.0
		velocity.x = away.x * flee_speed
		velocity.z = away.z * flee_speed
		if away.length_squared() > 0.01:
			look_at(global_position + Vector3(away.x, 0, away.z))
			rotate_y(PI)
	else:
		_ai_wander(delta)

func _ai_neutral_provoked(dist: float, dist_sq: float, speed_val: float, delta: float) -> void:
	# NEUTRAL provocado: ataca só dentro de neutral_chase_radius (não persegue longe)
	var chase_radius_sq := neutral_chase_radius * neutral_chase_radius
	if dist_sq > chase_radius_sq:
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
		return
	_ai_aggressive(dist, dist_sq, speed_val, delta)

func _ai_aggressive(dist: float, dist_sq: float, speed_val: float, delta: float) -> void:
	# Durante a animação de ataque: fica parado até terminar
	if _is_playing_attack_anim:
		velocity.x = move_toward(velocity.x, 0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 15.0 * delta)
		return
	if dist <= attack_radius and _attack_cooldown <= 0:
		_try_attack_player()
		_attack_cooldown = attack_cooldown_time
		velocity.x = 0
		velocity.z = 0
	elif dist <= attack_radius:
		# No alcance mas em cooldown: para e encara o jogador (não fica andando em círculo)
		velocity.x = move_toward(velocity.x, 0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 15.0 * delta)
		var dir := (_player.global_position - global_position).normalized()
		dir.y = 0
		if dir.length_squared() > 0.01:
			look_at(global_position + Vector3(dir.x, 0, dir.z))
			rotate_y(PI)
	elif dist_sq <= detection_radius * detection_radius:
		var dir := (_player.global_position - global_position).normalized()
		dir.y = 0
		velocity.x = dir.x * speed_val
		velocity.z = dir.z * speed_val
		look_at(global_position + Vector3(dir.x, 0, dir.z))
		rotate_y(PI)
	else:
		_ai_wander(delta)

func _ai_wander(delta: float) -> void:
	var speed_val := mob_data.speed if mob_data else 5.0
	var wander_speed := speed_val * wander_speed_ratio
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(wander_duration_min, wander_duration_max)
		if randf() < wander_idle_chance:
			_wander_direction = Vector2.ZERO
		else:
			var angle := randf() * TAU
			_wander_direction = Vector2(cos(angle), sin(angle))
	if _wander_direction.length_squared() < 0.01:
		velocity.x = move_toward(velocity.x, 0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 8.0 * delta)
		return
	velocity.x = _wander_direction.x * wander_speed
	velocity.z = _wander_direction.y * wander_speed
	var dir3 := Vector3(_wander_direction.x, 0, _wander_direction.y)
	if dir3.length_squared() > 0.01:
		look_at(global_position + dir3)
		rotate_y(PI)

func _ai_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)

func _apply_pending_attack() -> void:
	if not is_instance_valid(_player) or not _player.has_method("take_damage"):
		return
	var do_damage := false
	# Área: tenta detectar jogador na Area3D (pode falhar por timing/layers)
	if _attack_area:
		_attack_area.monitoring = true
		_attack_area.monitorable = false
		for body in _attack_area.get_overlapping_bodies():
			if body == _player or body.is_in_group("player"):
				do_damage = true
				break
		_attack_area.monitoring = false
		_attack_area.monitorable = false
	# Fallback confiável: distância + jogador na frente do mob (evita hit pelas costas)
	if not do_damage:
		var dist := global_position.distance_to(_player.global_position)
		var effective_radius := maxf(attack_radius * 1.25, 2.6)
		if dist <= effective_radius:
			var to_player := (_player.global_position - global_position).normalized()
			to_player.y = 0
			var fwd := -global_transform.basis.z
			fwd.y = 0
			fwd = fwd.normalized()
			if fwd.length_squared() > 0.01 and to_player.dot(fwd) > 0.3:
				do_damage = true
	if do_damage:
		_player.take_damage(_pending_damage, _pending_armor_piercing, self)
		if debug_log:
			var name_str = mob_data.display_name if mob_data else name
			print("[MobBase] hit: '%s' aplicou %.1f de dano" % [name_str, _pending_damage])

func _try_attack_player() -> void:
	if not is_instance_valid(_player):
		return
	_set_animation(_ANIM_ATTACK)
	_is_playing_attack_anim = true
	_attack_anim_end_time = Time.get_ticks_msec() / 1000.0 + attack_anim_duration
	# Dano aplicado após attack_hit_delay (ataque telegrafado)
	_pending_damage = mob_data.damage if mob_data else 10.0
	_pending_armor_piercing = mob_data.armor_piercing if mob_data else 0.0
	_attack_pending_hit_time = Time.get_ticks_msec() / 1000.0 + attack_hit_delay
	_attack_damage_pending = true

func _set_animation(anim_name: String) -> void:
	if _current_anim_name == anim_name:
		return
	_current_anim_name = anim_name
	if _animation_tree:
		var to_play: String = _resolve_anim_name(anim_name, true)
		var state: String = to_play if not to_play.is_empty() else anim_name
		_try_tree_animation(state)
	elif _animation_player:
		var to_play: String = _resolve_anim_name(anim_name, false)
		if not to_play.is_empty():
			_animation_player.play(to_play)
		elif _animation_player.has_animation(anim_name):
			_animation_player.play(anim_name)

func _resolve_anim_name(anim_name: String, for_tree: bool) -> String:
	var aliases: Array = _ANIM_ALIASES.get(anim_name, [anim_name])
	for a in aliases:
		if a is String:
			if for_tree:
				return a as String
			if _animation_player and _animation_player.has_animation(a):
				return a as String
	return "" if _animation_player else anim_name

func _try_tree_animation(state: String) -> void:
	var playback = _animation_tree.get("parameters/playback")
	if not playback:
		return
	# Usar travel() para trocar de estado (funciona com o state machine do lobo).
	playback.travel(state)

func _update_animation(delta: float) -> void:
	if _health_component and _health_component.is_dead:
		return
	# Longe do jogador: atualiza animação só a cada 4 frames (reduz custo com muitos mobs)
	if is_instance_valid(_player):
		var dist_sq := global_position.distance_squared_to(_player.global_position)
		if dist_sq > detection_radius * detection_radius * 1.8:
			if Engine.get_physics_frames() % 4 != 0:
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
