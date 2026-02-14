extends Control

## Tela de Loading - Mostra progresso da geração do mundo

@onready var loading_label = $VBoxContainer/LoadingLabel
@onready var progress_bar = $VBoxContainer/ProgressBar

var world_generator: Node = null
var game_manager: Node = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Se foi criado na raiz (vindo do MainMenu), já deve estar visível
	# Caso contrário, começar invisível
	if get_parent() == get_tree().root:
		visible = true
		# Inicializar valores
		if progress_bar:
			progress_bar.value = 0.0
		if loading_label:
			loading_label.text = "Carregando Mundo..."
	else:
		visible = false
	
	# Aguardar frame para garantir que tudo está carregado
	await get_tree().process_frame
	
	# Procurar GameManager
	game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		game_manager = get_node_or_null("/root/GameManager")
	
	# Conectar sinais do GameManager se existir
	if game_manager:
		if game_manager.has_signal("world_generation_progress"):
			if not game_manager.world_generation_progress.is_connected(_on_world_generation_progress):
				game_manager.world_generation_progress.connect(_on_world_generation_progress)
		if game_manager.has_signal("world_generation_complete"):
			if not game_manager.world_generation_complete.is_connected(_on_world_generation_complete):
				game_manager.world_generation_complete.connect(_on_world_generation_complete)
	
	# Se está na raiz e visível, procurar WorldGenerator para conectar diretamente
	if visible and get_parent() == get_tree().root:
		call_deferred("_connect_to_world_generator")

func start_loading(generator: Node):
	world_generator = generator
	visible = true
	progress_bar.value = 0.0
	loading_label.text = "Carregando Mundo..."
	
	# Conectar sinais diretamente do generator se não tiver GameManager
	if not game_manager and generator:
		if generator.has_signal("progress_updated"):
			if not generator.progress_updated.is_connected(_on_generator_progress):
				generator.progress_updated.connect(_on_generator_progress)
		if generator.has_signal("generation_complete"):
			if not generator.generation_complete.is_connected(_on_world_generation_complete):
				generator.generation_complete.connect(_on_world_generation_complete)
	
	# Iniciar monitoramento (fallback)
	monitor_loading()

func update_progress(percent: float, message: String = ""):
	progress_bar.value = percent
	if message != "":
		loading_label.text = message

func _on_world_generation_progress(percent: float, stage: int, message: String):
	update_progress(percent, message)

func _on_generator_progress(percent: float, stage: int, message: String):
	update_progress(percent, message)

func _on_world_generation_complete():
	update_progress(100.0, "Mundo gerado!")
	await get_tree().create_timer(0.5).timeout
	hide_loading()

func monitor_loading():
	# Fallback: monitoramento manual se sinais não estiverem conectados
	var total_chunks_needed = 0
	if world_generator and world_generator.has_method("get_total_chunks_needed"):
		total_chunks_needed = world_generator.get_total_chunks_needed()
	
	var last_loaded_count = 0
	var check_count = 0
	
	while visible:
		await get_tree().process_frame
		check_count += 1
		
		if not world_generator:
			break
		
		# Verificar progresso
		var loaded_count = 0
		if world_generator.has_method("get_loaded_chunks_count"):
			loaded_count = world_generator.get_loaded_chunks_count()
		
		if total_chunks_needed > 0:
			var percent = (float(loaded_count) / float(total_chunks_needed)) * 100.0
			percent = min(percent, 95.0)  # Máximo 95% até estar completo
			update_progress(percent, "Gerando terreno... (" + str(loaded_count) + "/" + str(total_chunks_needed) + ")")
		else:
			# Se não tem método, usar estimativa baseada em chunks carregados
			if loaded_count > last_loaded_count:
				update_progress(min(loaded_count * 8.0, 90.0), "Gerando terreno...")
				last_loaded_count = loaded_count
		
		# Verificar se está pronto (chunks iniciais carregados)
		if world_generator.has_method("is_initial_load_complete"):
			if world_generator.is_initial_load_complete():
				update_progress(100.0, "Pronto!")
				await get_tree().create_timer(0.5).timeout
				hide_loading()
				return
		else:
			# Fallback: aguardar alguns chunks serem carregados ou tempo mínimo
			if loaded_count >= 10 and check_count >= 30:  # Pelo menos 10 chunks e 30 frames
				update_progress(100.0, "Pronto!")
				await get_tree().create_timer(0.5).timeout
				hide_loading()
				return

func _connect_to_world_generator():
	# Procurar InfiniteWorldGenerator na cena atual
	var scene_root = get_tree().current_scene
	if scene_root:
		var world_gen = null
		if scene_root is InfiniteWorldGenerator:
			world_gen = scene_root
		else:
			world_gen = scene_root.get_node_or_null("InfiniteWorldGenerator")
		
		if world_gen and world_gen.has_signal("progress_updated"):
			if not world_gen.progress_updated.is_connected(_on_generator_progress):
				world_gen.progress_updated.connect(_on_generator_progress)
			if not world_gen.generation_complete.is_connected(_on_world_generation_complete):
				world_gen.generation_complete.connect(_on_world_generation_complete)
			print("✅ Tela de loading conectada ao WorldGenerator")

func hide_loading():
	visible = false
	# Notificar menu que loading terminou
	var menu = get_node_or_null("../MainMenu")
	if menu and menu.has_method("on_loading_complete"):
		menu.on_loading_complete()
