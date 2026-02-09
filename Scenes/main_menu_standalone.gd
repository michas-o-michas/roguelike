extends Control

## Menu Principal Standalone - Para uso na cena Main.tscn
## Este menu carrega a cena do jogo quando o jogador clica em "Iniciar"

@onready var start_button = $Control/Panel/VBoxContainer/StartButton
@onready var quit_button = $Control/Panel/VBoxContainer/QuitButton

var start_callback: Callable

func _ready():
	# Menu processa mesmo quando pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Menu visível
	visible = true
	
	# Mostrar cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
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

func set_start_callback(callback: Callable):
	start_callback = callback

func _on_start_button_pressed():
	print("🎮 Iniciar Jogo!")
	
	if start_callback.is_valid():
		start_callback.call()
	else:
		# Fallback: carregar cena diretamente
		_on_start_game_direct()

func _on_start_game_direct():
	print("📦 Carregando cena do jogo...")
	var game_scene_path = "res://Scenes/Test.tscn"
	var error = get_tree().change_scene_to_file(game_scene_path)
	if error != OK:
		push_error("❌ Erro ao carregar cena do jogo: " + str(error))

func _on_quit_button_pressed():
	print("🚪 Sair!")
	get_tree().quit()
