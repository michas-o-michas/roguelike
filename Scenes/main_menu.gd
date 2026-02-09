extends Control

## Menu Principal - Aparece ao iniciar a cena Test

@export var game_world_path: NodePath = NodePath("../../Test")
@export var loading_screen_path: NodePath = NodePath("../LoadingScreen")
@export var menu_camera_path: NodePath = NodePath("../../MenuCamera")

@onready var start_button = $Control/Panel/VBoxContainer/StartButton
@onready var quit_button = $Control/Panel/VBoxContainer/QuitButton
@onready var game_world: Node3D = null
@onready var loading_screen: Control = null
@onready var menu_camera: Camera3D = null
@onready var player_camera: Camera3D = null

func _ready():
	# Buscar referências usando os caminhos configurados
	if game_world_path != NodePath(""):
		game_world = get_node_or_null(game_world_path)
	if loading_screen_path != NodePath(""):
		loading_screen = get_node_or_null(loading_screen_path)
	if menu_camera_path != NodePath(""):
		menu_camera = get_node_or_null(menu_camera_path)
	
	# Menu processa mesmo quando pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Menu visível
	visible = true
	
	# Pausar jogo
	get_tree().paused = true
	
	# Mostrar cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Ativar câmera do menu (se existir)
	if menu_camera:
		menu_camera.current = true
	else:
		# Se não tem câmera de menu, criar uma temporária
		create_menu_camera()
	
	# Guardar referência da câmera do player (será buscada novamente quando necessário)
	# Não buscar aqui porque o player pode não estar pronto ainda
	
	# Aguardar frame
	await get_tree().process_frame
	
	# Conectar botões
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
		start_button.process_mode = Node.PROCESS_MODE_ALWAYS
		print("✅ StartButton conectado")
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
		quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
		print("✅ QuitButton conectado")
	
	# Desabilitar mundo
	if game_world:
		game_world.set_process(false)
		game_world.set_physics_process(false)
		# Esconder mundo visualmente mas manter player para câmera funcionar
		for child in game_world.get_children():
			if child.name != "Player" and child.name != "MenuCamera":
				child.visible = false

func _on_start_button_pressed():
	print("🎮 Iniciar Jogo!")
	
	# Esconder menu
	visible = false
	
	# Mostrar tela de loading
	if loading_screen:
		loading_screen.start_loading(game_world)
	
	# Iniciar geração do mundo
	if game_world and game_world.has_method("start_world_generation"):
		game_world.start_world_generation()
	
	# Aguardar loading completar
	await wait_for_loading_complete()

func wait_for_loading_complete():
	# Aguardar até loading screen esconder
	while loading_screen and loading_screen.visible:
		await get_tree().process_frame
	
	# Quando loading terminar, mostrar jogo
	show_game()

func _on_quit_button_pressed():
	print("🚪 Sair!")
	get_tree().quit()

func show_game():
	print("🎮 Mostrando jogo...")
	
	# Verificar se game_world foi encontrado
	if not game_world:
		print("   ⚠️ game_world é null! Tentando buscar novamente...")
		if game_world_path != NodePath(""):
			game_world = get_node_or_null(game_world_path)
		if not game_world:
			game_world = get_tree().get_first_node_in_group("world")
		if not game_world:
			# Tentar buscar pela raiz
			var root = get_tree().root
			game_world = root.get_node_or_null("Test")
	
	if not game_world:
		print("   ❌ ERRO: Não foi possível encontrar o mundo!")
		print("   Configure 'game_world_path' no inspector!")
		return
	
	print("   - game_world encontrado: ", game_world.name)
	
	# Desativar câmera do menu primeiro
	if menu_camera:
		menu_camera.current = false
		print("   - Câmera do menu desativada")
	
	# Despausar jogo ANTES de buscar o player (para garantir que nodes estejam processando)
	get_tree().paused = false
	print("   - Jogo despausado")
	
	# Aguardar um frame para garantir que tudo esteja pronto
	await get_tree().process_frame
	
	# Tornar mundo visível e ativar processamento
	game_world.visible = true
	game_world.set_process(true)
	game_world.set_physics_process(true)
	print("   - Mundo ativado e visível")
	
	# Buscar player
	var player = game_world.get_node_or_null("Player")
	if not player:
		# Tentar buscar pelo grupo
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		print("   - Player encontrado: ", player.name)
		player.visible = true
		
		# Buscar câmera do player
		var cam = player.get_node_or_null("Camera3D")
		if cam:
			cam.current = true
			print("   - Câmera do player ativada")
			player_camera = cam
		else:
			print("   ⚠️ Câmera do player não encontrada!")
	else:
		print("   ⚠️ Player não encontrado!")
	
	# Mostrar todos os filhos do mundo (exceto MenuCamera)
	for child in game_world.get_children():
		if child.name != "MenuCamera":
			child.visible = true
	print("   - Filhos do mundo tornados visíveis (", game_world.get_child_count(), " filhos)")
	
	# Travar cursor do mouse (modo jogo)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("   - Mouse capturado")
	
	print("✅ Jogo iniciado!")

func create_menu_camera():
	# Criar câmera temporária para o menu se não existir
	if not menu_camera and game_world:
		var camera = Camera3D.new()
		camera.name = "MenuCamera"
		camera.position = Vector3(0, 5, 0)
		camera.current = true
		game_world.add_child(camera)
		menu_camera = camera

func on_loading_complete():
	# Chamado quando loading termina
	show_game()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if not visible and not get_tree().paused:
			visible = true
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if game_world:
				game_world.set_process(false)
				game_world.set_physics_process(false)
