extends Node3D
class_name InfiniteWorldGenerator

## Sistema de mundo infinito otimizado — gera chunks ao redor do jogador dinamicamente.
## Estrutura: geração de mundo (terreno/chunks) | POIs (POIManager) | Spawners (SpawnerManager).
## v2 — Otimizações: time-budget por frame, cache de alturas, geração em lotes,
##       fila com Set para O(1), colisão diferida, vegetação assíncrona.

const POIManagerScript = preload("res://world_generator_v2/poi/POIManager.gd")
const SpawnerManagerScript = preload("res://world_generator_v2/spawners/SpawnerManager.gd")
const ChunkAmbientParticlesScene = preload("res://effects/AmbientParticles.tscn")

# Constantes de suavização do terreno (get_terrain_height)
const TERRAIN_BEACH_ZONE_TOP := 15.0
const TERRAIN_DEEP_THRESHOLD := -5.0
const TERRAIN_BEACH_SMOOTH_DIST := 12.0
const TERRAIN_RAMP_FACTOR_ABOVE := 0.2
const TERRAIN_SMOOTH_STRENGTH_MAX := 0.7
const TERRAIN_FINAL_TRANSITION_ZONE := 10.0
const TERRAIN_FINAL_RAMP := 0.25
const TERRAIN_BOTTOM_SMOOTH_ZONE := 3.0

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
# Grama MultiMesh: material com shader de vento (compartilhado)
var _grass_wind_material: ShaderMaterial
# Grama em círculo (estilo Muck): segue o jogador, spawn gradual
var _grass_circle_mi: MultiMeshInstance3D
# Posições de mundo de cada slot (para checar distância sem ler Transform3D)
var _grass_positions: PackedVector3Array = PackedVector3Array()
# Slots livres (escondidos, prontos para reposicionar)
var _grass_free_slots: Array[int] = []
# Última posição do jogador usada para reciclar (evita recalcular quando parado)
var _grass_last_player_pos: Vector3 = Vector3(0, -9999, 0)
# Fallback quando um material não tem textura (1x1 branco)
var _terrain_white_fallback: Texture2D

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

# Cache de alturas — evita recalcular get_terrain_height para o mesmo ponto
# Limpa chunks antigos no unload. Chave = Vector2i(floor(x), floor(z)), valor = float
var _height_cache: Dictionary = {}
const HEIGHT_CACHE_MAX_SIZE := 500000 ## Limpar se exceder (evita uso excessivo de RAM)

# Precalc para cor do terreno (evita recalcular a cada vértice)
var _rock_start_cached: float = 99999.0
var _rock_end_cached: float = 99999.0
var _snow_start_cached: float = 99999.0

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
	_cache_terrain_layer_values()
	add_to_group("world_generator")

	if use_shared_material:
		shared_terrain_material = _create_terrain_material()

	if enable_water:
		create_water()

	player = get_tree().get_first_node_in_group("player")

	poi_manager = POIManagerScript.new()
	poi_manager.name = "POIManager"
	add_child(poi_manager)
	spawner_manager = SpawnerManagerScript.new()
	spawner_manager.name = "SpawnerManager"
	add_child(spawner_manager)

	set_process(true)
	set_physics_process(true)
	call_deferred("_setup_after_scene_load")

## Precalcula valores de camadas do terreno para evitar recalcular em cada vértice
func _cache_terrain_layer_values():
	_rock_start_cached = rock_start_height if enable_rock_layer else 99999.0
	_rock_end_cached = _rock_start_cached + rock_thickness if enable_rock_layer else 99999.0
	if enable_snow_layer:
		_snow_start_cached = (rock_start_height + rock_thickness) if snow_start_height < 0 else snow_start_height
	else:
		_snow_start_cached = 99999.0

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
		if not game_manager:
			var GameManagerScript = load("res://Scripts/GameManager.gd")
			if GameManagerScript:
				game_manager = GameManagerScript.new()
				game_manager.name = "GameManager"
				get_tree().root.add_child(game_manager)
				game_manager.add_to_group("game_manager")

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
	_height_cache.clear()
	_vegetation_queue.clear()
	_vegetation_queue_set.clear()
	_collision_queue.clear()
	_collision_queue_set.clear()

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

func _process(delta: float):
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
			_process_grass_circle(delta)
		_process_vegetation_queue()
		_process_collision_queue()
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
		_tick_origin_rebase_when_idle(delta)

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
		_create_chunk_vegetation(chunk_data, world_pos)
		processed += 1

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
		_create_chunk_collision(chunk_data, world_pos)

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
		_create_chunk_collision(chunk_data, world_pos)
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

	# Terreno (mesh + colisão) — tudo de uma vez, sem time-slicing por linhas
	_build_terrain_mesh(chunk_data, world_pos)

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

## Constrói mesh do terreno em uma única passada otimizada (colisão/vegetação em segundo plano)
func _build_terrain_mesh(chunk_data: ChunkData, start_pos: Vector3):
	# Sempre mesh rápido (12 subs): colisão e vegetação são preenchidos em background
	var subs := mini(terrain_subdivisions, 12)
	var step := float(chunk_size) / subs
	var vert_count := (subs + 1) * (subs + 1)

	# Arrays tipados para performance
	var vertices := PackedVector3Array()
	vertices.resize(vert_count)
	var colors := PackedColorArray()
	colors.resize(vert_count)
	chunk_data.heights.resize(vert_count)
	chunk_data.terrain_subs = subs

	# Vértices em ESPAÇO LOCAL do chunk (0..chunk_size em XZ) e position do nó = start_pos
	# assim a mesh e a colisão usam o mesmo referencial e ficam alinhadas
	var idx := 0
	for z in range(subs + 1):
		var pos_z_world := start_pos.z + z * step
		var local_z := snappedf(z * step, 0.001)
		for x in range(subs + 1):
			var pos_x_world := start_pos.x + x * step
			var local_x := snappedf(x * step, 0.001)
			var h := get_terrain_height(pos_x_world, pos_z_world)
			chunk_data.heights[idx] = h
			vertices[idx] = Vector3(local_x, h, local_z)
			colors[idx] = get_terrain_color(pos_x_world, pos_z_world, h)
			idx += 1

	# Montar mesh com SurfaceTool
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var row_width := subs + 1
	for z in range(subs):
		var row_base := z * row_width
		for x in range(subs):
			var i := row_base + x
			var i1 := i + 1
			var i_next := i + row_width
			var i_next1 := i_next + 1

			# Triângulo 1
			st.set_color(colors[i])
			st.add_vertex(vertices[i])
			st.set_color(colors[i1])
			st.add_vertex(vertices[i1])
			st.set_color(colors[i_next])
			st.add_vertex(vertices[i_next])

			# Triângulo 2
			st.set_color(colors[i1])
			st.add_vertex(vertices[i1])
			st.set_color(colors[i_next1])
			st.add_vertex(vertices[i_next1])
			st.set_color(colors[i_next])
			st.add_vertex(vertices[i_next])

	st.generate_normals()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()

	if use_shared_material and shared_terrain_material:
		mesh_instance.material_override = shared_terrain_material
	else:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		mesh_instance.material_override = mat

	mesh_instance.position = start_pos
	add_child(mesh_instance)
	chunk_data.terrain_mesh = mesh_instance

	# Colisão é criada em segundo plano via _collision_queue (não aqui)

## Cria Shape3D de heightmap a partir das alturas do chunk (muito mais rápido que trimesh).
## Retorna { "shape": Shape3D, "scale": float } para aplicar no StaticBody3D.
func _create_heightmap_shape(chunk_data: ChunkData, lod_level: int) -> Dictionary:
	if chunk_data.heights.is_empty() or chunk_data.terrain_subs <= 0:
		return {}
	var full_size := chunk_data.terrain_subs + 1
	var step := 1
	match lod_level:
		1: step = 2
		2: step = 4
	var w := int((float(chunk_data.terrain_subs) / float(step)) + 1.0)
	var d := w
	var n := w * d
	var map_data := PackedFloat32Array()
	map_data.resize(n)
	var shape_scale := float(chunk_size) / float(w - 1) if w > 1 else 1.0
	var inv_scale := 1.0 / shape_scale if shape_scale > 0.001 else 1.0
	var idx := 0
	for z in range(0, full_size, step):
		for x in range(0, full_size, step):
			var src_idx := z * full_size + x
			map_data[idx] = chunk_data.heights[src_idx] * inv_scale
			idx += 1
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = map_data
	return { "shape": shape, "scale": shape_scale }

## Cria colisão com HeightMapShape3D (muito mais rápido que trimesh) e LOD por downsampling
func _create_chunk_collision(chunk_data: ChunkData, start_pos: Vector3):
	var lod_level := 0
	if enable_collision_lod and player:
		var dist := get_chunk_distance_to_player(chunk_data.chunk_pos)
		if dist <= collision_lod_near:
			lod_level = 0
		elif dist <= collision_lod_far:
			lod_level = 1
		else:
			lod_level = 2

	chunk_data.collision_lod_level = lod_level

	var result := _create_heightmap_shape(chunk_data, lod_level)
	if result.is_empty():
		return
	var static_body := StaticBody3D.new()
	# HeightMapShape3D é centralizado na origem; posicionar no centro do chunk
	static_body.position = start_pos + Vector3(chunk_size * 0.5, 0.0, chunk_size * 0.5)
	var s: float = result.get("scale", 1.0)
	static_body.scale = Vector3(s, s, s)
	var collision := CollisionShape3D.new()
	var shape_res: Shape3D = result.get("shape", null)
	collision.shape = shape_res
	static_body.add_child(collision)
	add_child(static_body)
	chunk_data.terrain_collision = static_body

	# Marcar colisão pronta
	if not chunks_with_collision.has(chunk_data.chunk_pos):
		chunks_with_collision[chunk_data.chunk_pos] = true
		if initial_chunks_needed > 0 and current_stage <= GenerationStage.COLLISION:
			var pc = get_player_or_spawn_chunk()
			if abs(chunk_data.chunk_pos.x - pc.x) <= view_distance and abs(chunk_data.chunk_pos.y - pc.y) <= view_distance:
				if initial_chunks_with_collision < initial_chunks_needed:
					initial_chunks_with_collision += 1
					if current_stage == GenerationStage.COLLISION:
						update_collision_progress()

func _create_simplified_collision(start_pos: Vector3, subdivisions: int) -> Shape3D:
	var step := float(chunk_size) / subdivisions
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := PackedVector3Array()
	verts.resize((subdivisions + 1) * (subdivisions + 1))
	var idx := 0
	for z in range(subdivisions + 1):
		for x in range(subdivisions + 1):
			var px := start_pos.x + x * step
			var pz := start_pos.z + z * step
			verts[idx] = Vector3(px, get_terrain_height(px, pz), pz)
			idx += 1
	var row_w := subdivisions + 1
	for z in range(subdivisions):
		var row_base := z * row_w
		for x in range(subdivisions):
			var i := row_base + x
			st.set_uv(Vector2.ZERO)
			st.add_vertex(verts[i])
			st.set_uv(Vector2.RIGHT)
			st.add_vertex(verts[i + 1])
			st.set_uv(Vector2.DOWN)
			st.add_vertex(verts[i + row_w])
			st.set_uv(Vector2.RIGHT)
			st.add_vertex(verts[i + 1])
			st.set_uv(Vector2.ONE)
			st.add_vertex(verts[i + row_w + 1])
			st.set_uv(Vector2.DOWN)
			st.add_vertex(verts[i + row_w])
	st.generate_normals()
	return st.commit().create_trimesh_shape()

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
		var res := _create_heightmap_shape(cd, cd.collision_lod_level)
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

	# Garantir colisão na área de spawn antes de posicionar o player (evita nascer no chão bugado)
	_ensure_spawn_area_has_collision()

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

	if not player and player_scene:
		instantiate_player()
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

	# Garantir colisão na área de spawn para o raycast acertar o chão
	_ensure_spawn_area_has_collision()

	var spawn_pos := player_spawn_position
	if spawn_pos == Vector3.ZERO:
		spawn_pos = chunk_to_world(Vector2i(0, 0))

	if player.is_inside_tree():
		var cp := player.global_position
		if cp != Vector3.ZERO and cp.length() > 0.1:
			spawn_pos.x = cp.x
			spawn_pos.z = cp.z

	spawn_pos.y = 200.0
	player.call_deferred("set", "global_position", spawn_pos)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO

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

		if player:
			position_player_on_terrain()
		_enable_player()

		if spawner_manager:
			spawner_manager.activate_all_enemy_spawners(self)

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

	# Limpar cache de alturas na região do chunk
	# (Não vale iterar todo o cache; fazemos flush periódico se ficar grande)
	if _height_cache.size() > HEIGHT_CACHE_MAX_SIZE:
		_height_cache.clear()

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

			var res := _create_heightmap_shape(chunk_data, new_lod)
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

## Extrai a textura de albedo de um Material (StandardMaterial3D). Retorna null se não houver.
func _get_albedo_texture_from_material(m: Material) -> Texture2D:
	if m is StandardMaterial3D:
		var std := m as StandardMaterial3D
		if std.albedo_texture:
			return std.albedo_texture
	return null

## Retorna textura de albedo do material ou fallback 1x1 branco (evita shader quebrado).
func _get_terrain_layer_texture(m: Material) -> Texture2D:
	var tex := _get_albedo_texture_from_material(m)
	if tex:
		return tex
	if not _terrain_white_fallback:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_terrain_white_fallback = ImageTexture.create_from_image(img)
	return _terrain_white_fallback

## Cria o material do terreno: com materiais por camada (se WorldTheme tiver) ou só cor por vértice.
func _create_terrain_material() -> Material:
	if world_theme and world_theme.use_terrain_textures:
		var has_any := (
			world_theme.material_sand != null or world_theme.material_grass != null
			or world_theme.material_rock != null or world_theme.material_snow != null
		)
		if has_any:
			var shader_path := "res://world_generator_v2/shader/terrain_textured.gdshader"
			if not ResourceLoader.exists(shader_path):
				shader_path = "res://shaders/terrain_textured.gdshader"
			var shader_res := load(shader_path) as Shader
			if shader_res:
				var mat := ShaderMaterial.new()
				mat.shader = shader_res
				mat.set_shader_parameter("texture_sand", _get_terrain_layer_texture(world_theme.material_sand))
				mat.set_shader_parameter("texture_grass", _get_terrain_layer_texture(world_theme.material_grass))
				mat.set_shader_parameter("texture_rock", _get_terrain_layer_texture(world_theme.material_rock))
				mat.set_shader_parameter("texture_snow", _get_terrain_layer_texture(world_theme.material_snow))
				mat.set_shader_parameter("water_level", water_level)
				mat.set_shader_parameter("beach_level", beach_level + 3.0)
				mat.set_shader_parameter("grass_level", grass_level)
				mat.set_shader_parameter("rock_start", rock_start_height)
				mat.set_shader_parameter("rock_end", rock_start_height + rock_thickness)
				var snow_start_val := (rock_start_height + rock_thickness) if snow_start_height < 0 else snow_start_height
				mat.set_shader_parameter("snow_start", snow_start_val)
				mat.set_shader_parameter("transition_width", maxf(world_theme.transition_width, 2.0))
				var softness := 2.0
				if "transition_softness" in world_theme:
					softness = world_theme.transition_softness
				var noise_amt := 2.0
				if "transition_noise" in world_theme:
					noise_amt = world_theme.transition_noise
				mat.set_shader_parameter("transition_softness", clampf(softness, 0.5, 3.0))
				mat.set_shader_parameter("transition_noise", clampf(noise_amt, 0.0, 5.0))
				mat.set_shader_parameter("texture_scale_uv", world_theme.texture_scale if world_theme.texture_scale > 0 else 0.05)
				mat.set_shader_parameter("use_vertex_cwolor_tint", true)
				_log("🖼️ Terreno usando materiais do WorldTheme (transições suaves por altura)")
				return mat
			else:
				push_warning("Shader de terreno não encontrado, usando cor por vértice.")
		elif debug_log:
			_log("⚠️ use_terrain_textures ativo mas nenhum material atribuído, usando cor por vértice")

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	return mat

func create_water():
	if world_theme and world_theme.liquid_type == WorldTheme.LiquidType.NONE:
		return

	water_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(water_size, water_size)
	plane.subdivide_width = 50
	plane.subdivide_depth = 50
	water_mesh.mesh = plane

	var liquid_level := water_level
	if world_theme and world_theme.use_custom_levels:
		liquid_level = world_theme.custom_water_level
	# Offset maior + sem receber sombras = sombras na água param de tremer
	const WATER_VISUAL_OFFSET := 0.12
	water_mesh.position = Vector3(0.0, liquid_level + WATER_VISUAL_OFFSET, 0.0)

	var water_mat: Material = null
	if world_theme and "water_material" in world_theme and world_theme.water_material:
		water_mat = world_theme.water_material
	else:
		water_mat = load("res://materials/Water.tres") as Material
	if water_mat:
		water_mesh.material_override = water_mat
	else:
		push_warning("Material res://materials/Water.tres não encontrado; água sem aparência.")

	# Não projetar sombra; receber sombras desativado no próprio shader da água (evita tremor)
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_mesh)

	var water_body := StaticBody3D.new()
	var water_collision := CollisionShape3D.new()
	var water_shape := BoxShape3D.new()
	water_shape.size = Vector3(water_size, 0.5, water_size)
	water_collision.shape = water_shape
	water_collision.position.y = liquid_level - 0.25
	water_body.add_child(water_collision)
	add_child(water_body)

func get_liquid_name(type: WorldTheme.LiquidType) -> String:
	match type:
		WorldTheme.LiquidType.WATER: return "Água"
		WorldTheme.LiquidType.LAVA: return "Lava"
		WorldTheme.LiquidType.ACID: return "Ácido"
		WorldTheme.LiquidType.OIL: return "Óleo"
		WorldTheme.LiquidType.BLOOD: return "Sangue"
		WorldTheme.LiquidType.CRYSTAL: return "Cristal Líquido"
		_: return "Desconhecido"

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
	# Cache lookup — chave inteira para agrupar pontos próximos
	var cache_key := Vector2i(int(x * 10.0), int(z * 10.0))
	if _height_cache.has(cache_key):
		return _height_cache[cache_key]

	var h := _compute_terrain_height(x, z)
	_height_cache[cache_key] = h
	return h

## Cálculo real de altura (pesado, por isso cacheamos)
func _compute_terrain_height(x: float, z: float) -> float:
	var noise_value := noise.get_noise_2d(x, z)
	var amplitude := noise_amplitude
	var frequency := 1.0
	var height := noise_value * amplitude

	for i in range(1, octaves):
		frequency *= lacunarity
		amplitude *= persistence
		height += noise.get_noise_2d(x * frequency, z * frequency) * amplitude

	# Redistribuição de altura
	if height > 0:
		var normalized := height / noise_amplitude
		normalized = pow(normalized, height_redistribution)
		height = normalized * noise_amplitude
	else:
		var normalized = abs(height) / noise_amplitude
		normalized = pow(normalized, 1.5)
		height = -normalized * noise_amplitude

	height += 3.0

	# Suavização de água e praia — pular quando água desativada (ganho grande de performance)
	if enable_water:
		var distance_from_water := height - water_level
		var deep_water_zone := -water_depth_limit

		if distance_from_water >= deep_water_zone and distance_from_water <= TERRAIN_BEACH_ZONE_TOP:
			var smooth_distance = abs(distance_from_water)
			if distance_from_water < TERRAIN_DEEP_THRESHOLD:
				var depth_factor := clampf((abs(distance_from_water) - (-TERRAIN_DEEP_THRESHOLD)) / (water_depth_limit - (-TERRAIN_DEEP_THRESHOLD)), 0.0, 1.0)
				depth_factor = depth_factor * depth_factor
				var deep_noise := noise.get_noise_2d(x * 0.0004, z * 0.0004)
				var target_depth := water_level - 4.0 + (deep_noise * 2.0)
				height = lerpf(height, target_depth, depth_factor * 0.8)
			elif distance_from_water >= TERRAIN_DEEP_THRESHOLD and distance_from_water <= TERRAIN_BEACH_ZONE_TOP:
				var smooth_strength := 1.0 - clampf(smooth_distance / TERRAIN_BEACH_SMOOTH_DIST, 0.0, 1.0)
				smooth_strength = smooth_strength * smooth_strength
				var beach_noise := noise.get_noise_2d(x * 0.0006, z * 0.0006)
				var target_height: float
				if distance_from_water > 0:
					target_height = water_level + (distance_from_water * TERRAIN_RAMP_FACTOR_ABOVE) + (beach_noise * 1.2)
				else:
					var depth_t = abs(distance_from_water) / (-TERRAIN_DEEP_THRESHOLD)
					depth_t = depth_t * depth_t
					target_height = lerpf(water_level - 1.0, water_level - 3.0, depth_t) + (beach_noise * 1.2)
				height = lerpf(height, target_height, smooth_strength * TERRAIN_SMOOTH_STRENGTH_MAX)

		var min_height := water_level - water_depth_limit
		if height < min_height:
			height = min_height

		distance_from_water = height - water_level
		if distance_from_water >= -TERRAIN_BOTTOM_SMOOTH_ZONE and distance_from_water <= TERRAIN_FINAL_TRANSITION_ZONE:
			var smooth_noise_val := noise.get_noise_2d(x * 0.0005, z * 0.0005)
			var water_proximity := 1.0 - clampf(abs(distance_from_water) / TERRAIN_FINAL_TRANSITION_ZONE, 0.0, 1.0)
			water_proximity = water_proximity * water_proximity

			var smooth_height: float
			if distance_from_water > 0:
				smooth_height = water_level + (distance_from_water * TERRAIN_FINAL_RAMP) + (smooth_noise_val * 0.8)
			else:
				smooth_height = water_level - 1.5 + (smooth_noise_val * 0.8)
			height = lerpf(height, smooth_height, water_proximity * 0.6)

		if height < water_level - TERRAIN_BOTTOM_SMOOTH_ZONE:
			var depth_noise := noise.get_noise_2d(x * 0.0008, z * 0.0008)
			var depth_factor := clampf((water_level - TERRAIN_BOTTOM_SMOOTH_ZONE - height) / 5.0, 0.0, 1.0)
			var smooth_bottom := water_level - TERRAIN_BOTTOM_SMOOTH_ZONE + (depth_noise * 1.5)
			height = lerpf(height, smooth_bottom, depth_factor * 0.6)

	return height

# =============================================================================
# COR DO TERRENO (usa valores precalculados)
# =============================================================================

func get_terrain_color(x: float, z: float, height: float) -> Color:
	var moisture := (moisture_noise.get_noise_2d(x, z) + 1.0) * 0.5

	var w_level := water_level
	var expanded_beach_level := beach_level + 3.0
	var g_level := grass_level
	var m_level := rock_start_height

	var rock_start := _rock_start_cached
	var rock_end := _rock_end_cached
	var s_start := _snow_start_cached

	# Debug: camadas em cores vivas
	if show_layer_debug:
		if height < w_level: return Color.BLUE
		elif height < expanded_beach_level: return Color.YELLOW
		elif height < g_level: return Color.GREEN
		elif height < rock_start: return Color.DARK_GREEN
		elif height < rock_end: return Color.GRAY
		else: return Color.WHITE

	# Usar tema se disponível
	#if world_theme and world_theme.use_custom_terrain_colors:
		#return world_theme.get_terrain_color_for_height(height, moisture, w_level, expanded_beach_level, g_level, rock_start, rock_end, s_start, snow_transition)

	# Abaixo da água
	if height < w_level:
		var depth := (w_level - height) / water_depth_limit
		depth = clampf(depth, 0.0, 1.0)
		var shallow := Color(0.15, 0.3, 0.5)
		var deep := Color(0.05, 0.1, 0.2)
		return shallow.lerp(deep, depth * depth)

	# Transição água → praia
	if height < expanded_beach_level:
		var t := (height - w_level) / (expanded_beach_level - w_level)
		t = clampf(t, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t) # smoothstep

		var shallow_water := Color(0.15, 0.3, 0.5)
		var wet_sand := Color(0.6, 0.55, 0.45)
		var dry_sand := Color(0.85, 0.8, 0.65)

		if t < 0.3:
			var st := t / 0.3
			st = st * st
			return shallow_water.lerp(wet_sand, st)
		else:
			var st := (t - 0.3) / 0.7
			st = st * st * (3.0 - 2.0 * st)
			return wet_sand.lerp(dry_sand, st)

	# Transição praia → grama
	if height < g_level + 5.0:
		var t := (height - expanded_beach_level) / ((g_level + 5.0) - expanded_beach_level)
		t = clampf(t, 0.0, 1.0)
		t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0) # perlin smoothstep
		var sand := Color(0.85, 0.8, 0.65)
		var grass := Color(0.4, 0.65, 0.35).lerp(Color(0.35, 0.6, 0.3), moisture)
		return sand.lerp(grass, t)

	# Grama baixa
	if height < m_level * 0.4:
		var grass_light := Color(0.35, 0.6, 0.3)
		var grass_dark := Color(0.28, 0.5, 0.25)
		return grass_light.lerp(grass_dark, moisture * 0.5)

	# Grama média
	if height < m_level * 0.7:
		var t := (height - m_level * 0.4) / (m_level * 0.3)
		t = clampf(t, 0.0, 1.0)
		return Color(0.28, 0.5, 0.25).lerp(Color(0.3, 0.48, 0.25), t)

	# Transição grama → rocha
	if height < rock_start:
		var distance_to_rock := rock_start - (m_level * 0.7)
		if distance_to_rock > 0:
			var t := (height - m_level * 0.7) / distance_to_rock
			t = clampf(t, 0.0, 1.0)
			t = t * t
			return Color(0.3, 0.48, 0.25).lerp(Color(0.35, 0.4, 0.3), t)
		return Color(0.3, 0.48, 0.25)

	# Rocha
	if height < rock_end:
		return Color(0.5, 0.5, 0.5)

	# Transição rocha → neve
	if height < s_start + snow_transition:
		var t := (height - rock_end) / snow_transition
		t = clampf(t, 0.0, 1.0)
		t = t * t
		return Color(0.5, 0.5, 0.5).lerp(Color(0.92, 0.92, 0.95), t)

	# Neve
	return Color(0.92, 0.92, 0.95)

# =============================================================================
# VEGETAÇÃO
# =============================================================================

func _create_chunk_vegetation(chunk_data: ChunkData, start_pos: Vector3):
	var vegetation_density := 1.0
	if player:
		var dist := get_chunk_distance_to_player(chunk_data.chunk_pos)
		if dist > visual_lod_far:
			vegetation_density = 0.3
		elif dist > visual_lod_near:
			vegetation_density = 0.6

	var biome_cache := {}
	var end_x := start_pos.x + chunk_size
	var end_z := start_pos.z + chunk_size
	var max_points := max_vegetation_points_per_chunk

	# Montar lista de células do grid e embaralhar para não criar fileiras vazias
	var cells: Array[Vector2] = []
	var x := start_pos.x
	while x < end_x:
		var z := start_pos.z
		while z < end_z:
			cells.append(Vector2(x, z))
			z += spawn_spacing
		x += spawn_spacing
	cells.shuffle()

	var points_done := 0
	for cell in cells:
		if max_points > 0 and points_done >= max_points:
			break
		if vegetation_density < 1.0 and randf() > vegetation_density:
			continue

		var pos_x := cell.x + randf_range(0.0, spawn_spacing)
		var pos_z := cell.y + randf_range(0.0, spawn_spacing)
		var height := get_terrain_height(pos_x, pos_z)

		if height < beach_level + 1.0:
			continue

		var position := Vector3(pos_x, height, pos_z)
		var cache_key := Vector2i(int(pos_x / 20.0), int(pos_z / 20.0))
		var current_biome: BiomeData

		if biome_cache.has(cache_key):
			current_biome = biome_cache[cache_key]
		else:
			current_biome = get_biome_at_position(pos_x, pos_z, height)
			biome_cache[cache_key] = current_biome

		if current_biome:
			_spawn_biome_item(current_biome, position, chunk_data)
		points_done += 1

	# Partículas ambientais fixas no chunk (não seguem o jogador; descarregam com o chunk)
	if enable_ambient_particles and ChunkAmbientParticlesScene:
		var center_x := start_pos.x + chunk_size * 0.5
		var center_z := start_pos.z + chunk_size * 0.5
		var center_y := get_terrain_height(center_x, center_z) + 3.0
		var particles := ChunkAmbientParticlesScene.instantiate()
		particles.position = Vector3(center_x, center_y, center_z)
		add_child(particles)
		chunk_data.objects.append(particles)

func _get_grass_wind_material() -> ShaderMaterial:
	if _grass_wind_material == null and grass_mesh:
		var shader := load("res://world_generator_v2/shader/grass_wind.gdshader") as Shader
		if shader:
			_grass_wind_material = ShaderMaterial.new()
			_grass_wind_material.shader = shader
			_grass_wind_material.set_shader_parameter("wind_strength", grass_wind_strength)
			_grass_wind_material.set_shader_parameter("wind_speed", grass_wind_speed)
			var grass_color := Color(0.25, 0.55, 0.25)
			if world_theme:
				grass_color = world_theme.grass_low_color
			_grass_wind_material.set_shader_parameter("base_color", grass_color)
			# Usar textura e cor do material do mesh da grama (cor natural da grama)
			var tint := grass_color
			var tex: Texture2D = null
			if grass_mesh.get_surface_count() > 0:
				var mat := grass_mesh.surface_get_material(0)
				if mat:
					tex = _get_albedo_texture_from_material(mat)
					if mat is StandardMaterial3D:
						tint = (mat as StandardMaterial3D).albedo_color
			if tex:
				_grass_wind_material.set_shader_parameter("albedo_texture", tex)
			_grass_wind_material.set_shader_parameter("albedo_tint", tint)
	return _grass_wind_material

func _setup_grass_circle():
	if not player or not grass_mesh or _grass_circle_mi != null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = grass_circle_count
	mm.mesh = grass_mesh

	_grass_positions.resize(grass_circle_count)
	_grass_free_slots.clear()

	# Iniciar todos os slots escondidos; o preenchimento é gradual em _process_grass_circle
	# (evita travar: antes fazia milhares de get_terrain_height em um único frame)
	for i in grass_circle_count:
		var tr := Transform3D()
		tr.origin = Vector3(0, -1000, 0)
		tr.basis = Basis().scaled(Vector3(0.001, 0.001, 0.001))
		mm.set_instance_transform(i, tr)
		_grass_positions[i] = Vector3(0, -1000, 0)
		_grass_free_slots.append(i)

	_grass_circle_mi = MultiMeshInstance3D.new()
	_grass_circle_mi.multimesh = mm
	if grass_with_animation:
		var wind_mat := _get_grass_wind_material()
		if wind_mat:
			_grass_circle_mi.material_override = wind_mat
	add_child(_grass_circle_mi)
	_grass_circle_mi.position = Vector3.ZERO
	_grass_last_player_pos = player.global_position

func _process_grass_circle(_delta: float):
	if not enable_grass_multimesh or not grass_mesh or not player:
		return
	if _grass_circle_mi == null:
		_setup_grass_circle()
	if _grass_circle_mi == null:
		return

	var mm: MultiMesh = _grass_circle_mi.multimesh
	if mm == null:
		return

	var player_pos := player.global_position
	var radius_sq := grass_circle_radius * grass_circle_radius

	# --- FASE 1: Coletar slots que saíram do raio ---
	# (Só comparação de distância, muito barato. Thread não vale: o custo pesado é
	# get_terrain_height e set_instance_transform, que têm de rodar na main thread.)
	for i in grass_circle_count:
		var gp := _grass_positions[i]
		if gp.y < -500.0:
			continue  # Já está livre/escondido
		var dx := gp.x - player_pos.x
		var dz := gp.z - player_pos.z
		if (dx * dx + dz * dz) > radius_sq:
			# Saiu do círculo — esconder e marcar como livre
			var tr := Transform3D()
			tr.origin = Vector3(0, -1000, 0)
			tr.basis = Basis().scaled(Vector3(0.001, 0.001, 0.001))
			mm.set_instance_transform(i, tr)
			_grass_positions[i] = Vector3(0, -1000, 0)
			_grass_free_slots.append(i)

	# --- FASE 2: Reposicionar slots livres na faixa externa (longe do jogador) ---
	# Preferência para a frente; raio entre grass_spawn_min_ratio e 100% do raio
	var spawned := 0
	var max_tries_per_slot := 6
	var forward_2d := Vector2(-player.global_transform.basis.z.x, -player.global_transform.basis.z.z)
	if forward_2d.length_squared() < 0.01:
		forward_2d = Vector2(1.0, 0.0)
	else:
		forward_2d = forward_2d.normalized()
	var angle_fwd := atan2(forward_2d.y, forward_2d.x)
	var r_min := grass_circle_radius * grass_spawn_min_ratio
	var r_range := grass_circle_radius - r_min

	while spawned < grass_spawn_per_frame and _grass_free_slots.size() > 0:
		var slot: int = _grass_free_slots.pop_back()
		var placed := false

		for _try in max_tries_per_slot:
			# 70% na frente, 30% em qualquer direção (garante achar terreno válido)
			var angle: float
			if randf() < 0.7:
				angle = angle_fwd + randf_range(-PI / 2.0, PI / 2.0)
			else:
				angle = randf() * TAU
			var r := r_min + sqrt(randf()) * r_range
			var wx := player_pos.x + cos(angle) * r
			var wz := player_pos.z + sin(angle) * r
			var h := get_terrain_height(wx, wz)

			if h <= water_level or h < beach_level + 1.0 or h >= grass_max_height:
				continue

			var tr := Transform3D()
			tr.origin = Vector3(wx, h, wz)
			tr.basis = Basis(Vector3.UP, randf() * TAU)
			var s := randf_range(grass_min_scale, grass_max_scale)
			tr.basis = tr.basis.scaled(Vector3(s, s, s))
			mm.set_instance_transform(slot, tr)
			_grass_positions[slot] = Vector3(wx, h, wz)
			placed = true
			break

		if not placed:
			_grass_free_slots.append(slot)
		else:
			spawned += 1

	_grass_last_player_pos = player_pos


func _spawn_biome_item(biome: BiomeData, position: Vector3, chunk_data: ChunkData):
	# Um único item por posição para evitar árvores em cima de pedras etc.
	var total_weight := 1.0  # peso "não spawnar nada"
	for item in biome.biome_items:
		if item and not item.variants.is_empty():
			total_weight += item.spawn_chance

	var roll := randf() * total_weight
	if roll < 1.0:
		return  # não coloca nada neste ponto
	roll -= 1.0

	for item in biome.biome_items:
		if not item or item.variants.is_empty():
			continue
		if roll < item.spawn_chance:
			var variant := get_random_variant(item.variants)
			if variant and variant.scene:
				var obj := variant.scene.instantiate()
				obj.position = position
				obj.rotation.y = randf_range(0, TAU)
				var s := randf_range(item.min_scale, item.max_scale)
				obj.scale = Vector3(s, s, s)
				add_child(obj)
				chunk_data.objects.append(obj)

				for sub_item in item.sub_items:
					if not sub_item:
						continue
					var count := sub_item.spawn_count
					for _i in count:
						if randf() > sub_item.spawn_chance:
							continue
						var offset := Vector3(
							randf_range(-sub_item.spawn_radius, sub_item.spawn_radius),
							0.0,
							randf_range(-sub_item.spawn_radius, sub_item.spawn_radius)
						)
						var sub_pos := position + offset
						sub_pos.y = get_terrain_height(sub_pos.x, sub_pos.z) + sub_item.height_offset
						var sub_variant := get_random_variant(sub_item.variants)
						if sub_variant and sub_variant.scene:
							var sub_obj := sub_variant.scene.instantiate()
							sub_obj.position = sub_pos
							sub_obj.rotation.y = randf_range(0, TAU)
							var sub_s := randf_range(sub_item.min_scale, sub_item.max_scale)
							sub_obj.scale = Vector3(sub_s, sub_s, sub_s)
							add_child(sub_obj)
							chunk_data.objects.append(sub_obj)
			return
		roll -= item.spawn_chance

func get_random_variant(variants: Array[ItemVariant]) -> ItemVariant:
	if variants.is_empty():
		return null
	var total_weight := 0.0
	for variant in variants:
		if variant:
			total_weight += get_rarity_weight(variant.rarity)
	var roll := randf() * total_weight
	var current_weight := 0.0
	for variant in variants:
		if not variant:
			continue
		current_weight += get_rarity_weight(variant.rarity)
		if roll <= current_weight:
			return variant
	return variants[0]

func get_rarity_weight(rarity: ItemVariant.Rarity) -> float:
	match rarity:
		ItemVariant.Rarity.COMMON: return 10.0
		ItemVariant.Rarity.UNCOMMON: return 5.0
		ItemVariant.Rarity.RARE: return 2.0
		ItemVariant.Rarity.EPIC: return 0.5
		ItemVariant.Rarity.LEGENDARY: return 0.1
	return 1.0

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
