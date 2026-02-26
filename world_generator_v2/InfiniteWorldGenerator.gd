extends Node3D
class_name InfiniteWorldGenerator

## Sistema de mundo infinito otimizado — gera chunks ao redor do jogador dinamicamente.
## Estrutura: geração de mundo (terreno/chunks) | POIs (POIManager) | Spawners (SpawnerManager).
## v2 — Otimizações: time-budget por frame, cache de alturas, geração em lotes,
##       fila com Set para O(1), colisão diferida, vegetação assíncrona.

const POIManagerScript = preload("res://world_generator_v2/poi/POIManager.gd")
const SpawnerManagerScript = preload("res://world_generator_v2/spawners/SpawnerManager.gd")
const ChunkAmbientParticlesScene = preload("res://effects/AmbientParticles.tscn")
const TerrainHeightModuleScript = preload("res://world_generator_v2/WorldGeneratorTerrainHeight.gd")

# =============================================================================
# CONFIGURAÇÃO GERAL
# =============================================================================

@export var auto_start: bool = false
@export var debug_log: bool = false
@export var chunk_size: int = 100
@export var view_distance: int = 3
@export var generation_margin: int = 2
@export var world_seed: int = 12345

@export_group("🎨 Tema do Mundo")
@export var world_theme: WorldTheme
@export var show_layer_debug: bool = false

@export_group("O que gerar")
@export var enable_terrain_collision: bool = true ## Colisão do terreno (desmarque = mais rápido; jogador atravessa o chão)
@export var enable_vegetation: bool = true ## Árvores, grama, pedras do bioma
@export var enable_rock_layer: bool = true ## Camada visual de rocha em altitude
@export var enable_snow_layer: bool = true ## Camada visual de neve
@export var enable_water: bool = true ## Plano de água
@export var enable_pois: bool = true ## Pontos de interesse (estruturas, etc.)
@export var enable_spawners: bool = true ## Spawners de animais/inimigos

@export_group("Otimização")
@export var chunks_per_frame: int = 4 ## ⚡ Chunks por frame (4 = bom equilíbrio com HeightMap)
@export var unload_distance: int = 5

@export_subgroup("Precisão (mundo infinito longe da origem)")
@export var enable_origin_rebase: bool = true ## Rebasa o mundo quando o jogador PARADO se afasta; evita colisão imprecisa sem tremor
@export var origin_rebase_threshold: float = 400.0 ## Distância XZ a partir da qual considerar rebase
@export var origin_rebase_idle_seconds: float = 0.8 ## Só rebasa após o jogador parado por este tempo (evita tremor)

@export_subgroup("Colisão do Terreno")
@export var enable_collision_lod: bool = true
@export var collision_lod_near: int = 2
@export var collision_lod_far: int = 4
@export var enable_visual_lod: bool = false
@export var visual_lod_near: int = 2
@export var visual_lod_far: int = 4
@export var use_shared_material: bool = true
@export var async_generation: bool = true
@export_range(4.0, 16.0, 0.5) var frame_time_budget_ms: float = 8.0 ## ⏱️ Tempo máximo (ms) gasto por frame gerando terreno. 8 = 60fps suave, 12 = mais rápido mas pode engasgar

@export_group("Terreno")
@export var noise_frequency: float = 0.002
@export var noise_amplitude: float = 25.0
@export var octaves: int = 5
@export var persistence: float = 0.45
@export var lacunarity: float = 2.0
@export var height_redistribution: float = 1.8
@export var terrain_subdivisions: int = 20
@export var reduce_near_subdivisions: bool = false
@export var near_subdivisions_factor: float = 0.6

@export_group("🌊 Níveis de Camadas")
@export var water_level: float = -8.0
@export var water_depth_limit: float = 10.0
@export var beach_level: float = -6.0
@export var grass_level: float = 2.0

@export_group("🪨 Camadas de Altitude")
@export var rock_start_height: float = 18.0
@export var rock_thickness: float = 12.0
@export var snow_start_height: float = -1.0
@export var snow_transition: float = 5.0

@export_group("Vegetação")
@export var spawn_spacing: float = 5.0
@export var biomes: Array[BiomeData] = []
@export_range(0.002, 0.04, 0.001) var biome_noise_frequency: float = 0.008 ## Densidade de biomas: menor = regiões maiores; maior = regiões menores (mais misturado)
@export var biome_transition_distance: float = 200.0
@export var max_vegetation_points_per_chunk: int = 150 ## 0 = ilimitado; ~150 acelera muito o carregamento
@export var enable_ambient_particles: bool = true ## Partículas ambientais (poeira/pólen) por chunk; descarregam com o chunk

@export_subgroup("Grama MultiMesh (estilo Muck: círculo ao redor do jogador)")
@export var enable_grass_multimesh: bool = true ## Grama em círculo ao redor do jogador, spawn gradual com fade-in
@export var grass_mesh: Mesh = null ## Mesh da grama (ex.: res://gress.tres); vazio = desativa grama
@export var grass_circle_radius: float = 18.0 ## Raio do círculo de grama ao redor do jogador
@export var grass_circle_count: int = 2500 ## Número de tufos no pool (reutilizados ao andar)
@export var grass_spawn_per_frame: int = 8 ## Quantos tufos novos por frame (spawn suave)
@export var grass_with_animation: = true

@export_range(0.3, 0.95, 0.05) var grass_spawn_min_ratio: float = 0.5 ## Grama nova só aparece entre este % e 100% do raio (evita spawn perto do jogador)
@export var grass_min_scale: float = 2.0
@export var grass_max_scale: float = 4.0
@export var grass_wind_strength: float = 0.05
@export var grass_wind_speed: float = 2.0
@export var grass_max_height: float = 25.0 ## Não coloca grama acima desta altura

@export_group("Água")
@export var water_size: float = 10000.0
## Plano fixo na origem (não segue o jogador). Tamanho em X e Z; 10000 = água “infinita”.

@export_group("Pontos de Interesse (POIs)")
@export var poi_check_interval: float = 300.0
@export var poi_min_spacing: float = 200.0
@export var poi_per_area_chance: float = 0.3
@export var pois: Array[POIData] = []

@export_group("Spawners de Animais")
@export var spawner_check_interval: float = 150.0
@export var spawner_min_spacing: float = 80.0
@export var spawner_per_area_chance: float = 0.5
@export var animal_spawners: Array[AnimalSpawnerData] = []

@export_group("🎮 Instanciação")
@export var player_scene: PackedScene
@export var player_spawn_position: Vector3 = Vector3.ZERO

# =============================================================================
# SISTEMA DE PROGRESSO
# =============================================================================
enum GenerationStage {
	IDLE, TERRAIN, COLLISION, VEGETATION, PLAYER, MOBS, COMPLETE
}

var current_stage: GenerationStage = GenerationStage.IDLE
var generation_progress: float = 0.0
var stage_progress: float = 0.0

signal progress_updated(percent: float, stage: GenerationStage, message: String)
signal stage_changed(stage: GenerationStage, message: String)
signal generation_complete()

# Dicionários de chunks
var loaded_chunks: Dictionary = {} ## {Vector2i: ChunkData}
var _chunk_queue: Array[Vector2i] = [] ## Fila ordenada por distância
var _chunk_queue_set: Dictionary = {} ## Set para lookup O(1)
var chunks_generating: Dictionary = {}
var chunks_with_collision: Dictionary = {}
var initial_chunks_needed: int = 0
var initial_chunks_loaded: int = 0
var initial_chunks_with_collision: int = 0
var mobs_instantiation_attempts: int = 0
var terrain_complete_transition_attempted: bool = false
var collision_complete_transition_attempted: bool = false

# Rebase da origem: só quando jogador parado (evita tremor de câmera)
var _origin_rebase_idle_timer: float = 0.0

# Noises
var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var temperature_noise: FastNoiseLite

# Player tracking
var player: Node3D
var last_player_chunk: Vector2i = Vector2i(999999, 999999)

# Water
var water_mesh: MeshInstance3D

# Módulos opcionais
var poi_manager: Node
var spawner_manager: Node

# Otimizações: Material compartilhado
var shared_terrain_material: Material
# Fallback quando um material não tem textura (1x1 branco). Usado por TerrainMeshBuilder.
var _terrain_white_fallback: Texture2D = null

# Time-slicing: geração de terreno com budget de tempo
var _terrain_build_queue: Array[Dictionary] = [] ## Fila interna de builds parciais
var _is_processing_queue: bool = false

# Vegetação em segundo plano: chunks enfileirados para preencher depois (não trava o carregamento)
var _vegetation_queue: Array[Vector2i] = []
var _vegetation_queue_set: Dictionary = {}
const VEGETATION_CHUNKS_PER_FRAME := 1 ## Quantos chunks de vegetação por frame (evita hitch)

# Colisão em segundo plano: chunks enfileirados para criar HeightMapShape3D depois (não trava o carregamento)
var _collision_queue: Array[Vector2i] = []
var _collision_queue_set: Dictionary = {}
const COLLISION_CHUNKS_PER_FRAME := 2 ## Quantos chunks de colisão por frame

# Módulo de altura/cor do terreno (cache e cálculos pesados)
var _terrain_height_module: Node = null
## Reaplicar posição de spawn por alguns frames para sobrescrever qualquer reset para (0,0,0)
var _pending_spawn_position: Vector3 = Vector3.ZERO
var _spawn_reapply_frames: int = 0

# =============================================================================
# ESTADO INTERNO
# =============================================================================

class ChunkData:
	var chunk_pos: Vector2i
	var terrain_mesh: MeshInstance3D
	var terrain_collision: StaticBody3D
	var objects: Array[Node3D] = []
	var is_loaded: bool = false
	var collision_lod_level: int = 0
	## Alturas do grid (subs+1)*(subs+1) para colisão HeightMapShape3D
	var heights: PackedFloat32Array = PackedFloat32Array()
	var terrain_subs: int = 0

# =============================================================================
# INICIALIZAÇÃO
# =============================================================================

func _log(msg: String, arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null, arg6 = null, arg7 = null, arg8 = null) -> void:
	if not debug_log:
		return
	var s := str(msg)
	for a in [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8]:
		if a != null:
			s += str(a)
	print(s)

func _ready():
	_log("🎬 InfiniteWorldGenerator._ready()")
	setup_noise()
	_terrain_height_module = TerrainHeightModuleScript.new()
	_terrain_height_module.name = "TerrainHeightModule"
	add_child(_terrain_height_module)
	add_to_group("world_generator")

	if use_shared_material:
		shared_terrain_material = TerrainMeshBuilder.create_terrain_material(self)

	if enable_water:
		water_mesh = WaterHelper.create_water(self)

	player = get_tree().get_first_node_in_group("player")

	var grass_mgr := GrassCircleManager.new()
	grass_mgr.name = "GrassCircleManager"
	add_child(grass_mgr)

	poi_manager = POIManagerScript.new()
	poi_manager.name = "POIManager"
	add_child(poi_manager)
	spawner_manager = SpawnerManagerScript.new()
	spawner_manager.name = "SpawnerManager"
	add_child(spawner_manager)

	set_process(true)
	set_physics_process(true)
	call_deferred("_setup_after_scene_load")

func _setup_after_scene_load():
	await get_tree().process_frame
	await get_tree().process_frame

	var loading_screen = get_tree().root.get_node_or_null("LoadingScreen")

	if loading_screen:
		loading_screen.visible = true
		if loading_screen.has_method("update_progress"):
			loading_screen.update_progress(0.0, "Iniciando geração do mundo...")

		if has_signal("progress_updated") and not progress_updated.is_connected(_on_direct_progress_update):
			progress_updated.connect(_on_direct_progress_update.bind(loading_screen))
		if has_signal("generation_complete") and not generation_complete.is_connected(_on_direct_generation_complete):
			generation_complete.connect(_on_direct_generation_complete.bind(loading_screen))

		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if not game_manager:
			game_manager = get_node_or_null("/root/GameManager")

		if game_manager:
			if game_manager.has_method("set_world_generator"):
				game_manager.set_world_generator(self)
			if game_manager.has_method("set_loading_screen"):
				game_manager.set_loading_screen(loading_screen)

		start_world_generation()
	elif auto_start:
		start_world_generation()

func _on_direct_progress_update(percent: float, _stage: GenerationStage, message: String, loading_screen: Control):
	if loading_screen and loading_screen.has_method("update_progress"):
		loading_screen.update_progress(percent, message)

func _on_direct_generation_complete(loading_screen: Control):
	if loading_screen and loading_screen.has_method("hide_loading"):
		loading_screen.hide_loading()

# =============================================================================
# START / ESTADO
# =============================================================================

func start_world_generation(player_to_instantiate: Node3D = null) -> bool:
	current_stage = GenerationStage.TERRAIN
	generation_progress = 0.0
	stage_progress = 0.0
	initial_chunks_loaded = 0
	initial_chunks_with_collision = 0
	mobs_instantiation_attempts = 0
	terrain_complete_transition_attempted = false
	collision_complete_transition_attempted = false
	chunks_with_collision.clear()
	_chunk_queue.clear()
	_chunk_queue_set.clear()
	chunks_generating.clear()
	_terrain_build_queue.clear()
	_is_processing_queue = false
	_origin_rebase_idle_timer = 0.0
	if _terrain_height_module and _terrain_height_module.has_method("clear_height_cache_if_needed"):
		_terrain_height_module.clear_height_cache_if_needed()
	_vegetation_queue.clear()
	_vegetation_queue_set.clear()
	_collision_queue.clear()
	_collision_queue_set.clear()
	if _terrain_height_module and _terrain_height_module.has_method("clear_height_cache_if_needed"):
		_terrain_height_module.clear_height_cache_if_needed()

	if player_to_instantiate:
		player = player_to_instantiate
	elif not player:
		player = get_tree().get_first_node_in_group("player")

	initial_chunks_needed = (view_distance * 2 + 1) * (view_distance * 2 + 1)
	_log("🌍 Chunks necessários: ", initial_chunks_needed)

	emit_signal("stage_changed", GenerationStage.TERRAIN, "Gerando terreno...")
	emit_signal("progress_updated", 0.0, GenerationStage.TERRAIN, "Iniciando geração do mundo...")

	set_process(true)
	set_physics_process(true)
	_enqueue_chunks_around(get_player_or_spawn_chunk(), view_distance)
	_log("✅ Fila tem ", _chunk_queue.size(), " chunks")
	return true

func get_loaded_chunks_count() -> int:
	return loaded_chunks.size()

func get_total_chunks_needed() -> int:
	return (view_distance * 2 + 1) * (view_distance * 2 + 1)

func is_initial_load_complete() -> bool:
	return initial_chunks_loaded >= int(initial_chunks_needed * 0.8)

func is_world_complete() -> bool:
	return current_stage == GenerationStage.COMPLETE

func get_player_or_spawn_chunk() -> Vector2i:
	if player:
		return world_to_chunk(player.global_position)
	return world_to_chunk(player_spawn_position)

func get_initial_chunk_positions() -> Array[Vector2i]:
	var center := get_player_or_spawn_chunk()
	var out: Array[Vector2i] = []
	for x in range(-view_distance, view_distance + 1):
		for z in range(-view_distance, view_distance + 1):
			out.append(center + Vector2i(x, z))
	return out

func count_loaded_chunks_in_initial_area() -> int:
	var count := 0
	for chunk_pos in get_initial_chunk_positions():
		if loaded_chunks.has(chunk_pos):
			count += 1
	return count

func count_collisions_ready_in_initial_area() -> int:
	var count := 0
	for chunk_pos in get_initial_chunk_positions():
		if loaded_chunks.has(chunk_pos):
			var cd = loaded_chunks[chunk_pos]
			if cd and cd.terrain_collision != null:
				count += 1
	return count

# =============================================================================
# FILA DE CHUNKS (O(1) lookup com Set)
# =============================================================================

## Adiciona chunks ao redor de `center` na fila, ordenados por distância (espiral)
func _enqueue_chunks_around(center: Vector2i, radius: int):
	var new_positions: Array[Vector2i] = []
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			var pos = center + Vector2i(x, z)
			if loaded_chunks.has(pos) or _chunk_queue_set.has(pos) or chunks_generating.has(pos):
				continue
			new_positions.append(pos)

	# Ordenar por distância ao centro (gera do centro para fora = menos pop-in)
	new_positions.sort_custom(func(a, b):
		var da = (a - center).length_squared()
		var db = (b - center).length_squared()
		return da < db
	)

	for pos in new_positions:
		_chunk_queue.append(pos)
		_chunk_queue_set[pos] = true

## Remove e retorna o próximo chunk da fila
func _dequeue_chunk() -> Vector2i:
	var pos = _chunk_queue.pop_front()
	_chunk_queue_set.erase(pos)
	return pos

# =============================================================================
# LOOP PRINCIPAL (_process) — Time-budget driven
# =============================================================================

func _process(_delta: float):
	# Reaplicar posição de spawn por alguns frames (evita player voltar a 0,0,0)
	if _spawn_reapply_frames > 0 and player and is_instance_valid(player) and player.is_inside_tree():
		player.global_position = _pending_spawn_position
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		_spawn_reapply_frames -= 1

	# Pós-carregamento: mundo infinito
	if current_stage >= GenerationStage.COMPLETE:
		if player:
			var current_chunk = world_to_chunk(player.global_position)
			if current_chunk != last_player_chunk:
				last_player_chunk = current_chunk
				_enqueue_chunks_around(current_chunk, view_distance + generation_margin)
				_unload_far_chunks(current_chunk)
			if _chunk_queue.size() > 0:
				_process_chunk_queue()
		_process_vegetation_queue()
		_process_collision_queue()
		if enable_pois and poi_manager:
			poi_manager.check_and_spawn_pois(self)
		if enable_spawners and spawner_manager:
			spawner_manager.check_and_spawn_spawners(self)
		return

	# Durante carregamento inicial: verificações de segurança e progresso
	_check_stage_transitions()

	# Processar fila de chunks com budget de tempo
	if _chunk_queue.size() > 0:
		_process_chunk_queue()
	else:
		# Re-enfileirar se faltam chunks
		_reenqueue_missing_initial_chunks()

	# Vegetação e colisão em segundo plano (já podem ir preenchendo durante/após carregamento)
	if current_stage >= GenerationStage.VEGETATION:
		_process_vegetation_queue()
	if current_stage >= GenerationStage.COLLISION:
		_process_collision_queue()

	# Tracking do player
	if not player:
		return

	if enable_origin_rebase:
		_tick_origin_rebase_when_idle(_delta)

	var current_chunk = world_to_chunk(player.global_position)
	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		if current_stage < GenerationStage.COMPLETE:
			_enqueue_chunks_around(current_chunk, view_distance)

	if enable_pois and poi_manager:
		poi_manager.check_and_spawn_pois(self)
	if enable_spawners and spawner_manager:
		spawner_manager.check_and_spawn_spawners(self)

## Verifica se as transições de estágio (TERRAIN→COLLISION→VEGETATION) devem ocorrer
func _check_stage_transitions():
	if current_stage == GenerationStage.TERRAIN and initial_chunks_needed > 0:
		var real = count_loaded_chunks_in_initial_area()
		if real >= initial_chunks_needed and not terrain_complete_transition_attempted:
			initial_chunks_loaded = real
			terrain_complete_transition_attempted = true
			update_terrain_progress()
			if current_stage == GenerationStage.TERRAIN:
				call_deferred("_advance_to_collision_stage")

	elif current_stage == GenerationStage.COLLISION and initial_chunks_needed > 0:
		var real = count_collisions_ready_in_initial_area()
		if real >= initial_chunks_needed and initial_chunks_with_collision < initial_chunks_needed:
			initial_chunks_with_collision = real
			update_collision_progress()

## Re-enfileira chunks iniciais faltantes
func _reenqueue_missing_initial_chunks():
	if current_stage >= GenerationStage.COMPLETE or initial_chunks_needed <= 0:
		return
	var real = count_loaded_chunks_in_initial_area()
	if real >= initial_chunks_needed:
		return
	for chunk_pos in get_initial_chunk_positions():
		if not loaded_chunks.has(chunk_pos) and not chunks_generating.has(chunk_pos) and not _chunk_queue_set.has(chunk_pos):
			_chunk_queue.append(chunk_pos)
			_chunk_queue_set[chunk_pos] = true

# =============================================================================
# PROCESSAMENTO DE FILA — Time-budget (gera o máximo possível dentro do budget)
# =============================================================================

func _process_chunk_queue():
	if _chunk_queue.size() == 0 or _is_processing_queue:
		return
	_is_processing_queue = true

	var frame_start_us := Time.get_ticks_usec()
	# Colisão e vegetação são em segundo plano — terreno sempre usa budget/chunks de modo rápido
	var budget_ms := maxf(frame_time_budget_ms, 25.0)
	var budget_us := int(budget_ms * 1000.0)
	var generated := 0

	var max_chunks := chunks_per_frame
	if current_stage <= GenerationStage.COLLISION and initial_chunks_needed > 0:
		max_chunks = maxi(chunks_per_frame, 8)
	max_chunks = maxi(max_chunks, 24)

	while generated < max_chunks and _chunk_queue.size() > 0:
		var elapsed := Time.get_ticks_usec() - frame_start_us
		if generated > 0 and elapsed >= budget_us:
			break # Budget esgotado

		var chunk_pos := _dequeue_chunk()

		if loaded_chunks.has(chunk_pos):
			chunks_generating.erase(chunk_pos)
			continue
		if chunks_generating.has(chunk_pos):
			chunks_generating.erase(chunk_pos)
			continue

		chunks_generating[chunk_pos] = true
		_generate_chunk_sync(chunk_pos)
		chunks_generating.erase(chunk_pos)
		generated += 1

	_is_processing_queue = false

## Processa até VEGETATION_CHUNKS_PER_FRAME chunks da fila de vegetação (não trava o frame)
func _process_vegetation_queue():
	if not enable_vegetation or _vegetation_queue.size() == 0:
		return
	var processed := 0
	while processed < VEGETATION_CHUNKS_PER_FRAME and _vegetation_queue.size() > 0:
		var chunk_pos: Vector2i = _vegetation_queue.pop_front()
		_vegetation_queue_set.erase(chunk_pos)
		if not loaded_chunks.has(chunk_pos):
			continue
		var chunk_data := loaded_chunks[chunk_pos] as ChunkData
		if not chunk_data or not chunk_data.terrain_mesh:
			continue
		var world_pos := chunk_to_world(chunk_pos)
		VegetationBuilder.create_chunk_vegetation(self, chunk_data, world_pos)
		processed += 1

## Espera o chunk de spawn (e 4 vizinhos) ter colisão na árvore e a física processar antes de posicionar o player
func _wait_for_spawn_collision_ready() -> void:
	if not enable_terrain_collision:
		await get_tree().physics_frame
		await get_tree().physics_frame
		return
	var spawn_chunk: Vector2i = world_to_chunk(player_spawn_position) if player_spawn_position != Vector3.ZERO else Vector2i(0, 0)
	var to_wait: Array[Vector2i] = [
		spawn_chunk,
		spawn_chunk + Vector2i(-1, 0), spawn_chunk + Vector2i(1, 0),
		spawn_chunk + Vector2i(0, -1), spawn_chunk + Vector2i(0, 1)
	]
	var max_attempts := 60
	for attempt in max_attempts:
		_ensure_spawn_area_has_collision()
		var all_have_collision := true
		for cp in to_wait:
			if not loaded_chunks.has(cp):
				all_have_collision = false
				break
			var chunk_data = loaded_chunks[cp] as ChunkData
			if not chunk_data or chunk_data.terrain_collision == null or not is_instance_valid(chunk_data.terrain_collision) or not chunk_data.terrain_collision.is_inside_tree():
				all_have_collision = false
				break
		if all_have_collision:
			break
		await get_tree().create_timer(0.05).timeout
	# Dar tempo à física para registrar as colisões antes de posicionar o player
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

## Garante que o chunk de spawn e os 4 vizinhos tenham colisão antes de posicionar o player (evita chão bugado)
func _ensure_spawn_area_has_collision():
	if not enable_terrain_collision:
		return
	var spawn_chunk: Vector2i
	if player and player.is_inside_tree() and player.global_position.length_squared() > 0.01:
		spawn_chunk = world_to_chunk(player.global_position)
	else:
		spawn_chunk = world_to_chunk(player_spawn_position) if player_spawn_position != Vector3.ZERO else Vector2i(0, 0)
	var to_ensure: Array[Vector2i] = [
		spawn_chunk,
		spawn_chunk + Vector2i(-1, 0),
		spawn_chunk + Vector2i(1, 0),
		spawn_chunk + Vector2i(0, -1),
		spawn_chunk + Vector2i(0, 1)
	]
	for cp in to_ensure:
		if not _collision_queue_set.has(cp):
			continue
		var idx := _collision_queue.find(cp)
		if idx < 0:
			continue
		_collision_queue.remove_at(idx)
		_collision_queue_set.erase(cp)
		if not loaded_chunks.has(cp):
			continue
		var chunk_data := loaded_chunks[cp] as ChunkData
		if not chunk_data or not chunk_data.terrain_mesh or chunk_data.terrain_collision != null:
			continue
		var world_pos := chunk_to_world(cp)
		var static_body := ChunkCollisionBuilder.create_chunk_collision(self, chunk_data, world_pos)
		if static_body:
			add_child(static_body)
			chunk_data.terrain_collision = static_body
			if not chunks_with_collision.has(cp):
				chunks_with_collision[cp] = true
				if initial_chunks_needed > 0 and current_stage <= GenerationStage.COLLISION:
					var pc = get_player_or_spawn_chunk()
					if abs(cp.x - pc.x) <= view_distance and abs(cp.y - pc.y) <= view_distance:
						if initial_chunks_with_collision < initial_chunks_needed:
							initial_chunks_with_collision += 1
							if current_stage == GenerationStage.COLLISION:
								update_collision_progress()

## Processa até COLLISION_CHUNKS_PER_FRAME chunks da fila de colisão (prioridade: mais perto do player)
func _process_collision_queue():
	if not enable_terrain_collision or _collision_queue.size() == 0:
		return
	var processed := 0
	while processed < COLLISION_CHUNKS_PER_FRAME and _collision_queue.size() > 0:
		# Escolher o chunk mais próximo do player para reduzir queda no vazio
		var best_idx := 0
		var best_dist := get_chunk_distance_to_player(_collision_queue[0])
		for j in range(1, _collision_queue.size()):
			var d := get_chunk_distance_to_player(_collision_queue[j])
			if d < best_dist:
				best_dist = d
				best_idx = j
		var chunk_pos: Vector2i = _collision_queue[best_idx]
		_collision_queue.remove_at(best_idx)
		_collision_queue_set.erase(chunk_pos)
		if not loaded_chunks.has(chunk_pos):
			continue
		var chunk_data := loaded_chunks[chunk_pos] as ChunkData
		if not chunk_data or not chunk_data.terrain_mesh:
			continue
		var world_pos := chunk_to_world(chunk_pos)
		var static_body := ChunkCollisionBuilder.create_chunk_collision(self, chunk_data, world_pos)
		if static_body:
			add_child(static_body)
			chunk_data.terrain_collision = static_body
			if not chunks_with_collision.has(chunk_pos):
				chunks_with_collision[chunk_pos] = true
				if initial_chunks_needed > 0 and current_stage <= GenerationStage.COLLISION:
					var pc = get_player_or_spawn_chunk()
					if abs(chunk_pos.x - pc.x) <= view_distance and abs(chunk_pos.y - pc.y) <= view_distance:
						if initial_chunks_with_collision < initial_chunks_needed:
							initial_chunks_with_collision += 1
							if current_stage == GenerationStage.COLLISION:
								update_collision_progress()
		processed += 1

# =============================================================================
# GERAÇÃO DE CHUNK — Síncrona otimizada (sem await, máxima velocidade)
# =============================================================================

func _generate_chunk_sync(chunk_pos: Vector2i) -> void:
	if loaded_chunks.has(chunk_pos):
		return

	var chunk_data = ChunkData.new()
	chunk_data.chunk_pos = chunk_pos
	var world_pos = chunk_to_world(chunk_pos)

	# Terreno (mesh) — colisão e vegetação em segundo plano
	TerrainMeshBuilder.build_terrain_mesh(self, chunk_data, world_pos)

	# Contar para progresso se é chunk inicial
	if initial_chunks_needed > 0 and current_stage <= GenerationStage.TERRAIN:
		var pc = get_player_or_spawn_chunk()
		if abs(chunk_pos.x - pc.x) <= view_distance and abs(chunk_pos.y - pc.y) <= view_distance:
			if initial_chunks_loaded < initial_chunks_needed:
				initial_chunks_loaded += 1
				update_terrain_progress()

	# Vegetação: em segundo plano (não trava carregamento) — enfileira para processar depois
	if enable_vegetation:
		if not _vegetation_queue_set.has(chunk_pos):
			_vegetation_queue.append(chunk_pos)
			_vegetation_queue_set[chunk_pos] = true

	# Colisão: em segundo plano (não trava carregamento) — enfileira para processar depois
	if enable_terrain_collision:
		if not _collision_queue_set.has(chunk_pos):
			_collision_queue.append(chunk_pos)
			_collision_queue_set[chunk_pos] = true

	chunk_data.is_loaded = true
	loaded_chunks[chunk_pos] = chunk_data

# =============================================================================
# SISTEMA DE PROGRESSO
# =============================================================================

func update_terrain_progress():
	if current_stage != GenerationStage.TERRAIN or initial_chunks_needed <= 0:
		return
	initial_chunks_loaded = mini(initial_chunks_loaded, initial_chunks_needed)
	stage_progress = float(initial_chunks_loaded) / float(initial_chunks_needed)
	generation_progress = stage_progress * 20.0
	emit_signal("progress_updated", generation_progress, GenerationStage.TERRAIN,
		"Gerando terreno... (%d/%d)" % [initial_chunks_loaded, initial_chunks_needed])

	if initial_chunks_loaded >= initial_chunks_needed and not terrain_complete_transition_attempted:
		terrain_complete_transition_attempted = true
		call_deferred("_advance_to_collision_stage")

func _advance_to_collision_stage():
	if current_stage != GenerationStage.TERRAIN:
		return
	current_stage = GenerationStage.COLLISION
	emit_signal("stage_changed", GenerationStage.COLLISION, "Criando colisões...")

	# Colisão é preenchida em segundo plano; não esperar — avançar direto para vegetação
	initial_chunks_with_collision = initial_chunks_needed
	collision_complete_transition_attempted = true
	call_deferred("_advance_to_vegetation_stage")

func update_collision_progress():
	if current_stage != GenerationStage.COLLISION or initial_chunks_needed <= 0:
		return

	# Contar colisões reais
	var pc := get_player_or_spawn_chunk()
	var real := 0
	var missing: Array[Vector2i] = []
	for x in range(-view_distance, view_distance + 1):
		for z in range(-view_distance, view_distance + 1):
			var cp := pc + Vector2i(x, z)
			if loaded_chunks.has(cp):
				var cd = loaded_chunks[cp]
				if cd and cd.terrain_collision != null:
					if not chunks_with_collision.has(cp):
						chunks_with_collision[cp] = true
					real += 1
				elif cd and cd.terrain_mesh and cd.terrain_collision == null:
					missing.append(cp)

	# Criar colisões faltantes (HeightMapShape3D quando há alturas, senão fallback)
	for cp in missing:
		if missing.size() > 5:
			break
		var cd = loaded_chunks[cp]
		if not cd or not cd.terrain_mesh:
			continue
		var wp := chunk_to_world(cp)
		var res := ChunkCollisionBuilder.create_heightmap_shape(cd, cd.collision_lod_level, chunk_size)
		if not res.is_empty():
			var sb := StaticBody3D.new()
			sb.position = wp + Vector3(chunk_size * 0.5, 0.0, chunk_size * 0.5)
			var s: float = res.get("scale", 1.0)
			sb.scale = Vector3(s, s, s)
			var col := CollisionShape3D.new()
			var shape_val: Shape3D = res.get("shape", null)
			col.shape = shape_val
			sb.add_child(col)
			add_child(sb)
			cd.terrain_collision = sb
			chunks_with_collision[cp] = true
			real += 1

	initial_chunks_with_collision = mini(real, initial_chunks_needed)
	stage_progress = float(initial_chunks_with_collision) / float(initial_chunks_needed)
	generation_progress = 20.0 + stage_progress * 30.0
	emit_signal("progress_updated", generation_progress, GenerationStage.COLLISION,
		"Criando colisões... (%d/%d)" % [initial_chunks_with_collision, initial_chunks_needed])

	if initial_chunks_with_collision >= initial_chunks_needed and not collision_complete_transition_attempted:
		if current_stage == GenerationStage.COLLISION:
			collision_complete_transition_attempted = true
			call_deferred("_advance_to_vegetation_stage")

func _advance_to_vegetation_stage():
	if current_stage != GenerationStage.COLLISION:
		return

	# Colisão é preenchida em segundo plano; não exige colisões prontas para avançar

	current_stage = GenerationStage.VEGETATION
	emit_signal("stage_changed", GenerationStage.VEGETATION, "Gerando vegetação...")
	generation_progress = 50.0
	emit_signal("progress_updated", 50.0, GenerationStage.VEGETATION, "Gerando vegetação...")

	call_deferred("_advance_to_player_after_vegetation")

func _advance_to_player_after_vegetation():
	if current_stage != GenerationStage.VEGETATION:
		return
	# Vegetação é preenchida em segundo plano; não esperar — ir direto ao player
	if current_stage == GenerationStage.VEGETATION:
		start_player_instantiation()

# =============================================================================
# PLAYER
# =============================================================================

func start_player_instantiation():
	if current_stage >= GenerationStage.PLAYER:
		return

	var all_ready := initial_chunks_with_collision >= initial_chunks_needed and initial_chunks_loaded >= initial_chunks_needed
	if not all_ready:
		await get_tree().create_timer(0.3).timeout
		if current_stage < GenerationStage.PLAYER:
			start_player_instantiation()
		return

	current_stage = GenerationStage.PLAYER
	generation_progress = 70.0
	emit_signal("stage_changed", GenerationStage.PLAYER, "Instanciando player...")
	emit_signal("progress_updated", 70.0, GenerationStage.PLAYER, "Instanciando player...")

	# Garantir colisão na área de spawn e esperar a física processar antes de posicionar o player
	await _wait_for_spawn_collision_ready()

	if not player and player_scene:
		await instantiate_player()
	elif player:
		_disable_player()
		await get_tree().process_frame
		position_player_on_terrain()

	await get_tree().process_frame
	start_mobs_instantiation()

func _disable_player():
	if not player:
		return
	if player.has_method("set_process"):
		player.set_process(false)
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	if player.has_method("set_process_mode"):
		player.set_process_mode(Node.PROCESS_MODE_DISABLED)

func _enable_player():
	if not player:
		return
	if player.has_method("set_process"):
		player.set_process(true)
	if player.has_method("set_physics_process"):
		player.set_physics_process(true)
	if player.has_method("set_process_mode"):
		player.set_process_mode(Node.PROCESS_MODE_INHERIT)

func instantiate_player():
	if not player_scene:
		push_error("❌ player_scene não configurado!")
		return

	player = player_scene.instantiate()
	_disable_player()
	player.add_to_group("player")
	# Colocar na raiz para global_position funcionar; Level1 está em (0,0,0) então mundo = mesmo espaço
	get_tree().root.add_child(player)
	var spawn_xz := player_spawn_position
	if spawn_xz == Vector3.ZERO:
		spawn_xz = chunk_to_world(Vector2i(0, 0))
	var target_pos := Vector3(spawn_xz.x, 200.0, spawn_xz.z)

	await get_tree().physics_frame
	# Aplicar em deferred para a física não sobrescrever
	player.call_deferred("set", "global_position", target_pos)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	await get_tree().physics_frame
	player.global_position = target_pos
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO

	generation_progress = 70.0
	emit_signal("progress_updated", 70.0, GenerationStage.PLAYER, "Player instanciado!")

func position_player_on_terrain():
	if not player or not player.is_inside_tree():
		return

	# Garantir colisão na área de spawn antes de posicionar
	_ensure_spawn_area_has_collision()

	# Sempre usar o ponto de spawn exportado para XZ (evita usar 0,0,0 do player antes de ser movido)
	var spawn_pos := player_spawn_position
	if spawn_pos == Vector3.ZERO:
		spawn_pos = chunk_to_world(Vector2i(0, 0))

	# Altura = superfície do terreno + offset; nunca abaixo de 2 para evitar nascer no chão
	var terrain_y := get_terrain_height(spawn_pos.x, spawn_pos.z)
	spawn_pos.y = maxf(terrain_y + 2.0, 2.0)

	if player.has_method("position_on_terrain"):
		player.position_on_terrain(spawn_pos)
	else:
		player.global_position = spawn_pos
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	# Forçar reaplicação por vários frames para não ser sobrescrito por (0,0,0)
	_pending_spawn_position = spawn_pos
	_spawn_reapply_frames = 8

# =============================================================================
# MOBS
# =============================================================================

func start_mobs_instantiation():
	mobs_instantiation_attempts += 1
	if mobs_instantiation_attempts > 10:
		push_error("❌ Muitas tentativas de instanciar mobs! Forçando conclusão...")
		_finalize_world()
		return

	if current_stage < GenerationStage.MOBS:
		current_stage = GenerationStage.MOBS
		generation_progress = 85.0
		emit_signal("stage_changed", GenerationStage.MOBS, "Finalizando...")
		emit_signal("progress_updated", 85.0, GenerationStage.MOBS, "Finalizando...")

		await get_tree().process_frame
		await get_tree().process_frame

		var all_ready := initial_chunks_loaded >= initial_chunks_needed and initial_chunks_with_collision >= initial_chunks_needed and player != null
		if not all_ready:
			await get_tree().create_timer(0.3).timeout
			if current_stage == GenerationStage.MOBS:
				start_mobs_instantiation()
			return

		# Só posicionar e habilitar o player depois da colisão do spawn estar ativa na física
		await _wait_for_spawn_collision_ready()
		if player:
			position_player_on_terrain()
		_enable_player()

		_finalize_world()

func _finalize_world():
	current_stage = GenerationStage.COMPLETE
	generation_progress = 100.0
	emit_signal("stage_changed", GenerationStage.COMPLETE, "Mundo gerado!")
	emit_signal("progress_updated", 100.0, GenerationStage.COMPLETE, "Mundo gerado!")
	emit_signal("generation_complete")
	_log("✅ Geração do mundo completa!")

# =============================================================================
# DESCARREGAR CHUNKS DISTANTES
# =============================================================================

func _unload_far_chunks(player_chunk: Vector2i):
	var to_unload: Array[Vector2i] = []
	for chunk_pos in loaded_chunks.keys():
		var dist := maxi(abs(chunk_pos.x - player_chunk.x), abs(chunk_pos.y - player_chunk.y))
		if dist > unload_distance:
			to_unload.append(chunk_pos)

	for chunk_pos in to_unload:
		unload_chunk(chunk_pos)

	if poi_manager and poi_manager.has_method("unload_far"):
		poi_manager.unload_far(self)
	if spawner_manager and spawner_manager.has_method("unload_far"):
		spawner_manager.unload_far(self)

	if enable_collision_lod:
		update_collision_lod(player_chunk)

func unload_chunk(chunk_pos: Vector2i):
	if not loaded_chunks.has(chunk_pos):
		return

	var chunk_data = loaded_chunks[chunk_pos]

	if chunk_data.terrain_mesh:
		chunk_data.terrain_mesh.queue_free()
	if chunk_data.terrain_collision:
		chunk_data.terrain_collision.queue_free()

	for obj in chunk_data.objects:
		if is_instance_valid(obj):
			obj.queue_free()

	loaded_chunks.erase(chunk_pos)
	chunks_with_collision.erase(chunk_pos)
	_vegetation_queue_set.erase(chunk_pos)
	_collision_queue_set.erase(chunk_pos)

	if _terrain_height_module and _terrain_height_module.has_method("clear_height_cache_if_needed"):
		_terrain_height_module.clear_height_cache_if_needed()

# =============================================================================
# LOD DE COLISÃO DINÂMICO
# =============================================================================

func update_collision_lod(player_chunk: Vector2i):
	if not enable_collision_lod:
		return

	var updated := 0
	for chunk_pos in loaded_chunks.keys():
		if updated >= 2:
			break

		var chunk_data = loaded_chunks[chunk_pos]
		if not chunk_data or not chunk_data.terrain_collision:
			continue

		var dist := get_chunk_distance_to_player(chunk_pos)
		var new_lod := 0
		if dist <= collision_lod_near:
			new_lod = 0
		elif dist <= collision_lod_far:
			new_lod = 1
		else:
			new_lod = 2

		if chunk_data.collision_lod_level != new_lod:
			var wp := chunk_to_world(chunk_pos)
			chunk_data.terrain_collision.queue_free()
			chunk_data.collision_lod_level = new_lod

			var res := ChunkCollisionBuilder.create_heightmap_shape(chunk_data, new_lod, chunk_size)
			if not res.is_empty():
				var sb := StaticBody3D.new()
				sb.position = wp + Vector3(chunk_size * 0.5, 0.0, chunk_size * 0.5)
				var s: float = res.get("scale", 1.0)
				sb.scale = Vector3(s, s, s)
				var col := CollisionShape3D.new()
				var shape_val: Shape3D = res.get("shape", null)
				col.shape = shape_val
				sb.add_child(col)
				add_child(sb)
				chunk_data.terrain_collision = sb
			updated += 1

# =============================================================================
# RUÍDO E ÁGUA
# =============================================================================

func setup_noise():
	seed(world_seed)

	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = persistence

	biome_noise = FastNoiseLite.new()
	biome_noise.seed = world_seed + 1000
	biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_noise.frequency = biome_noise_frequency

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = world_seed + 2000
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = 0.015

	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = world_seed + 3000
	temperature_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	temperature_noise.frequency = 0.012

func get_liquid_name(type: WorldTheme.LiquidType) -> String:
	return WaterHelper.get_liquid_name(type)

# =============================================================================
# COORDENADAS E REBASE DA ORIGEM (só quando parado)
# =============================================================================

## Rebasa o mundo só quando o jogador está parado há um tempo; evita tremor e bug ao mover rápido.
func _tick_origin_rebase_when_idle(delta: float) -> void:
	if not player or not is_inside_tree():
		_origin_rebase_idle_timer = 0.0
		return
	var xz := Vector2(player.global_position.x, player.global_position.z)
	if xz.length_squared() <= origin_rebase_threshold * origin_rebase_threshold:
		_origin_rebase_idle_timer = 0.0
		return
	var vel := player.get("velocity") as Vector3
	if vel == null:
		vel = Vector3.ZERO
	var speed_xz := Vector2(vel.x, vel.z).length()
	if speed_xz > 2.0:
		_origin_rebase_idle_timer = 0.0
		return
	_origin_rebase_idle_timer += delta
	if _origin_rebase_idle_timer < origin_rebase_idle_seconds:
		return
	_origin_rebase_idle_timer = 0.0
	var offset := Vector3(player.global_position.x, 0.0, player.global_position.z)
	global_position -= offset
	player.global_position = Vector3(0.0, player.global_position.y, 0.0)

func world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / chunk_size)), int(floor(world_pos.z / chunk_size)))

func chunk_to_world(chunk_pos: Vector2i) -> Vector3:
	return Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)

func get_chunk_distance_to_player(chunk_pos: Vector2i) -> int:
	if not player:
		return 0
	var pc := world_to_chunk(player.global_position)
	return maxi(abs(chunk_pos.x - pc.x), abs(chunk_pos.y - pc.y))

# =============================================================================
# ALTURA DO TERRENO (com cache)
# =============================================================================

func get_terrain_height(x: float, z: float) -> float:
	if _terrain_height_module and _terrain_height_module.has_method("get_terrain_height"):
		return _terrain_height_module.get_terrain_height(x, z)
	return 0.0

func get_terrain_color(x: float, z: float, height: float) -> Color:
	if _terrain_height_module and _terrain_height_module.has_method("get_terrain_color"):
		return _terrain_height_module.get_terrain_color(x, z, height)
	return Color.GRAY

# =============================================================================
# BIOMAS E DIFICULDADE
# =============================================================================

func get_biome_at_position(x: float, z: float, height: float) -> BiomeData:
	var moisture := (moisture_noise.get_noise_2d(x, z) + 1.0) * 0.5
	var temperature := (temperature_noise.get_noise_2d(x, z) + 1.0) * 0.5
	var biome_value := (biome_noise.get_noise_2d(x, z) + 1.0) * 0.5
	var distance_from_spawn := Vector2(x, z).length()
	var current_tier := calculate_difficulty_tier(distance_from_spawn)

	var best_biome: BiomeData = null
	var best_score := -999999.0

	for biome in biomes:
		if not biome:
			continue
		if height < biome.min_height or height > biome.max_height:
			continue
		if biome.difficulty_tier > current_tier:
			continue
		if randf() > biome.biome_rarity:
			continue

		var score = -(abs(moisture - biome.preferred_moisture) + abs(temperature - biome.preferred_temperature) + abs(biome_value - biome.biome_noise_value))
		score += biome.difficulty_tier * 0.1

		if score > best_score:
			best_score = score
			best_biome = biome

	return best_biome

func calculate_difficulty_tier(distance: float) -> int:
	if distance < 500: return 1
	elif distance < 1500: return 2
	elif distance < 3000: return 3
	elif distance < 5000: return 4
	else: return 5

func get_tier_name(tier: int) -> String:
	match tier:
		1: return "Tier 1 - Iniciante"
		2: return "Tier 2 - Intermediário"
		3: return "Tier 3 - Avançado"
		4: return "Tier 4 - Difícil"
		5: return "Tier 5 - Extremo"
		_: return "Tier " + str(tier)
