extends Node3D
class_name EnemySpawner

## 🐾 Spawner de Inimigos
## Spawna inimigos em área ao redor, respeitando variantes e raridade

@export_group("🎯 Spawn")
@export var enemy_scene: PackedScene ## Cena do inimigo base (ex: res://enemies/wolf.tscn)
@export var variants: Array[EnemyVariant] = [] ## Variantes possíveis
@export var spawn_radius: float = 10.0 ## Raio de spawn ao redor do spawner
@export var max_enemies: int = 5 ## Máximo de inimigos vivos simultaneamente
@export var spawn_interval: float = 10.0 ## Intervalo entre spawns (segundos)

@export_group("🌍 Spawn por Tier")
@export var only_spawn_by_tier: bool = true ## Só spawnar variantes do tier atual
@export var current_difficulty_tier: int = 1 ## Tier atual (calculado pela distância do spawn)

@export_group("⚙️ Comportamento")
@export var auto_start: bool = true ## Iniciar spawns automaticamente
@export var spawn_on_ready: bool = false ## Spawnar inimigos imediatamente
@export var despawn_on_far: bool = true ## Despawnar inimigos muito longe
@export var despawn_distance: float = 100.0 ## Distância para despawnar

@export_group("🎲 Randomização")
@export var use_random_variants: bool = true ## Usar sistema de raridade
@export var force_variant_index: int = -1 ## Forçar variante específica (-1 = aleatório)

# Controle interno
var spawned_enemies: Array[Enemy] = []
var spawn_timer: float = 0.0
var is_spawning: bool = false

func _ready():
	# Validar
	if not enemy_scene:
		push_error("❌ EnemySpawner sem enemy_scene definido!")
		return
	
	# Iniciar
	if auto_start:
		start_spawning()
	
	if spawn_on_ready:
		spawn_enemy()

func _process(delta):
	if not is_spawning:
		return
	
	# Timer de spawn
	spawn_timer += delta
	
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		
		# Verificar se pode spawnar
		if get_alive_count() < max_enemies:
			spawn_enemy()
	
	# Despawnar inimigos muito longe
	if despawn_on_far:
		check_despawn()

# ========================================
# SPAWN
# ========================================

func spawn_enemy() -> Enemy:
	if not enemy_scene:
		return null
	
	# Instanciar
	var enemy = enemy_scene.instantiate() as Enemy
	if not enemy:
		push_error("❌ Cena não é um Enemy!")
		return null
	
	# Posição aleatória no raio
	var angle = randf() * TAU
	var distance = randf_range(0.0, spawn_radius)
	var offset = Vector3(
		cos(angle) * distance,
		0.0,
		sin(angle) * distance
	)
	
	enemy.position = global_position + offset
	
	# Ajustar Y para ficar no chão (raycast)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		enemy.position + Vector3(0, 10, 0),
		enemy.position + Vector3(0, -100, 0)
	)
	var result = space_state.intersect_ray(query)
	
	if result:
		enemy.position.y = result.position.y
	
	# Aplicar variante
	var variant = select_variant()
	if variant:
		apply_variant_to_enemy(enemy, variant)
		print("🐺 Spawned: ", variant.variant_name, " (", variant.get_rarity_color(), ")")
	
	# Adicionar ao mundo
	get_tree().root.add_child(enemy)
	spawned_enemies.append(enemy)
	
	# Conectar sinal de morte (se existir)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	
	return enemy

func select_variant() -> EnemyVariant:
	# Sem variantes? Retornar null
	if variants.is_empty():
		return null
	
	# Forçar variante específica
	if force_variant_index >= 0 and force_variant_index < variants.size():
		return variants[force_variant_index]
	
	# Filtrar por tier se ativado
	var valid_variants = variants
	if only_spawn_by_tier:
		valid_variants = variants.filter(func(v): return v.difficulty_tier <= current_difficulty_tier)
		
		if valid_variants.is_empty():
			valid_variants = variants  # Fallback
	
	# Sistema de raridade
	if use_random_variants:
		return select_variant_by_rarity(valid_variants)
	else:
		# Aleatório simples
		return valid_variants[randi() % valid_variants.size()]

func select_variant_by_rarity(valid_variants: Array) -> EnemyVariant:
	# Calcular peso total
	var total_weight = 0.0
	for variant in valid_variants:
		total_weight += variant.spawn_weight
	
	# Sortear
	var roll = randf() * total_weight
	var current_weight = 0.0
	
	for variant in valid_variants:
		current_weight += variant.spawn_weight
		if roll <= current_weight:
			return variant
	
	# Fallback
	return valid_variants[0]

func apply_variant_to_enemy(enemy: Enemy, variant: EnemyVariant):
	# Desabilitar cor aleatória do inimigo
	enemy.use_random_color = false
	
	# Aplicar variante
	variant.apply_to_enemy(enemy)
	
	# Atualizar nome
	enemy.enemy_name = variant.variant_name

# ========================================
# CONTROLE
# ========================================

func start_spawning():
	is_spawning = true
	spawn_timer = 0.0

func stop_spawning():
	is_spawning = false

func despawn_all():
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()

func get_alive_count() -> int:
	# Remover inimigos mortos/inválidos
	spawned_enemies = spawned_enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	return spawned_enemies.size()

func check_despawn():
	for enemy in spawned_enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance > despawn_distance:
			print("👋 Despawned: ", enemy.enemy_name, " (muito longe)")
			enemy.queue_free()

func _on_enemy_died(enemy: Enemy):
	spawned_enemies.erase(enemy)

# ========================================
# FUNÇÕES PÚBLICAS
# ========================================

func set_difficulty_tier(tier: int):
	current_difficulty_tier = tier

func spawn_specific_variant(variant_index: int) -> Enemy:
	if variant_index < 0 or variant_index >= variants.size():
		push_error("❌ Índice de variante inválido: ", variant_index)
		return null
	
	var old_force = force_variant_index
	force_variant_index = variant_index
	
	var enemy = spawn_enemy()
	
	force_variant_index = old_force
	return enemy
