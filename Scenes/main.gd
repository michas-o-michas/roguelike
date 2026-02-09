extends Node2D

## Cena Principal - Menu do Jogo
## Esta cena contém apenas o menu e a tela de loading
## Quando o jogador clica em "Iniciar Jogo", carrega a cena Test.tscn

@export var game_scene_path: String = "res://Scenes/Test.tscn"

@onready var main_menu = $CanvasLayer/MainMenu
@onready var loading_screen = $CanvasLayer/LoadingScreen

func _ready():
	print("🎮 Cena Main carregada")
	
	# Garantir que o menu está visível e loading está escondido
	if main_menu:
		main_menu.visible = true
	if loading_screen:
		loading_screen.visible = false
	
	# Conectar sinais do menu
	if main_menu and main_menu.has_method("set_start_callback"):
		main_menu.set_start_callback(_on_start_game)
	
	# Mostrar cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_start_game():
	print("🎮 Iniciando jogo...")
	
	# Mostrar tela de loading
	if loading_screen:
		loading_screen.visible = true
		loading_screen.update_progress(0.0, "Carregando jogo...")
	
	# Aguardar um frame para mostrar o loading
	await get_tree().process_frame
	
	# Carregar cena do jogo
	print("📦 Carregando cena: ", game_scene_path)
	
	var error = get_tree().change_scene_to_file(game_scene_path)
	if error != OK:
		push_error("❌ Erro ao carregar cena do jogo: " + str(error))
		if loading_screen:
			loading_screen.visible = false
