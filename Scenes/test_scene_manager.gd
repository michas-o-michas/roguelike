extends Node

## Gerenciador da Cena Test - Gerencia menu e loading quando a cena é carregada
## Este script é usado no nó SceneManager filho do Test

@onready var world_generator = get_parent()  # O nó Test é o gerador
@onready var player = get_parent().get_node_or_null("Player")
@onready var menu_camera = get_parent().get_node_or_null("MenuCamera")

var loading_screen: Control = null
var main_menu: Control = null

func _ready():
	print("🌍 Cena Test carregada")
	
	# Buscar menu e loading screen (podem estar na cena ou serem criados)
	main_menu = get_node_or_null("CanvasLayer/MainMenu")
	loading_screen = get_node_or_null("CanvasLayer/LoadingScreen")
	
	# Se não existirem, criar
	if not main_menu:
		create_menu_and_loading()
	
	# Garantir que o mundo não inicie automaticamente
	if has_method("set") and has_method("get"):
		if get("auto_start") == true:
			set("auto_start", false)
	
	# Esconder mundo inicialmente
	if world_generator:
		world_generator.visible = false
	if player:
		player.visible = false
	
	# Ativar câmera do menu
	if menu_camera:
		menu_camera.current = true
	
	# Mostrar menu
	if main_menu:
		main_menu.visible = true
		# Conectar botão do menu
		if main_menu.has_method("set_start_callback"):
			main_menu.set_start_callback(_on_start_game)
	
	# Mostrar cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	print("✅ Menu pronto!")

func create_menu_and_loading():
	# Criar CanvasLayer se não existir
	var canvas_layer = get_node_or_null("CanvasLayer")
	if not canvas_layer:
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		add_child(canvas_layer)
	
	# Carregar e instanciar menu
	var menu_scene = load("res://Scenes/MainMenu.tscn")
	if menu_scene:
		main_menu = menu_scene.instantiate()
		canvas_layer.add_child(main_menu)
		if main_menu.has_method("set_start_callback"):
			main_menu.set_start_callback(_on_start_game)
	
	# Carregar e instanciar loading screen
	var loading_scene = load("res://Scenes/LoadingScreen.tscn")
	if loading_scene:
		loading_screen = loading_scene.instantiate()
		canvas_layer.add_child(loading_screen)

func _on_start_game():
	print("🎮 Iniciando jogo...")
	
	# Esconder menu
	if main_menu:
		main_menu.visible = false
	
	# Mostrar loading screen
	if loading_screen:
		loading_screen.visible = true
		loading_screen.start_loading(world_generator)
	
	# Iniciar geração do mundo
	if world_generator.has_method("start_world_generation"):
		world_generator.start_world_generation()
	
	# Aguardar loading completar
	await wait_for_loading_complete()
	
	# Mostrar jogo
	show_game()

func wait_for_loading_complete():
	# Aguardar até loading screen esconder
	while loading_screen and loading_screen.visible:
		await get_tree().process_frame

func show_game():
	print("🎮 Mostrando jogo...")
	
	# Desativar câmera do menu
	if menu_camera:
		menu_camera.current = false
	
	# Tornar mundo visível
	if world_generator:
		world_generator.visible = true
		world_generator.set_process(true)
		world_generator.set_physics_process(true)
	
	# Mostrar player e ativar sua câmera
	if player:
		player.visible = true
		var player_camera = player.get_node_or_null("Camera3D")
		if player_camera:
			player_camera.current = true
			print("   - Câmera do player ativada")
	
	# Mostrar todos os filhos
	for child in get_children():
		if child.name != "CanvasLayer" and child.name != "MenuCamera":
			child.visible = true
	
	# Travar cursor do mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	print("✅ Jogo iniciado!")
