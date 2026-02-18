extends Control

## Menu Principal Standalone - Para uso na cena Main.tscn
## Este menu carrega a cena do jogo quando o jogador clica em "Iniciar"

@onready var start_button = $Control/Panel/VBoxContainer/StartButton
@onready var settings_button = $Control/Panel/VBoxContainer/SettingsButton
@onready var quit_button = $Control/Panel/VBoxContainer/QuitButton

var start_callback: Callable
var loading_screen_scene = preload("res://Scenes/LoadingScreen.tscn")
var loading_screen: Control = null

func _ready():
	# Carrega uma imagem (logo, loading, etc.)
	var tex = preload("uid://6gl80c43hdsd") as Texture2D
	if ScreenFade:
		ScreenFade.set_fade_texture(tex)
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
	
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
		settings_button.process_mode = Node.PROCESS_MODE_ALWAYS
		print("✅ SettingsButton conectado")
	
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
	
	# Criar e exibir tela de loading ANTES de mudar a cena
	show_loading_screen()
	
	# Salvar referência da tela de loading em um autoload ou variável global
	# para que ela persista após mudança de cena
	var tree = get_tree()
	if not tree:
		push_error("❌ Árvore de cena não disponível!")
		return
	
	
	# Carregar cena do jogo
	var game_scene_path = "res://Scenes/Level1.tscn"
	var error = tree.change_scene_to_file(game_scene_path)
	if error != OK:
		push_error("❌ Erro ao carregar cena do jogo: " + str(error))
		hide_loading_screen()
		return
	
	# NOTA: Após change_scene_to_file(), este nó será destruído
	# A configuração deve ser feita na nova cena (Test.tscn) ou em um autoload
	# Por isso, vamos usar um método alternativo: conectar via signal ou autoload

func show_loading_screen():
	if loading_screen_scene:
		loading_screen = loading_screen_scene.instantiate()
		loading_screen.name = "LoadingScreen"  # Nome fixo para facilitar busca
		# Adicionar à raiz para persistir após mudança de cena
		var root = get_tree().root
		root.add_child(loading_screen)
		loading_screen.z_index = 1000  # Garantir que está acima de tudo
		loading_screen.process_mode = Node.PROCESS_MODE_ALWAYS  # Processar sempre
		loading_screen.visible = true  # Garantir que está visível
		loading_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Não bloquear input
		print("📊 Tela de loading criada e exibida na raiz")

func hide_loading_screen():
	if loading_screen:
		loading_screen.queue_free()
		loading_screen = null
		print("📊 Tela de loading ocultada")

# Esta função não será mais chamada aqui porque o nó é destruído após change_scene_to_file
# A configuração deve ser feita na cena Test.tscn ou em um autoload
func setup_world_generation():
	push_warning("⚠️ setup_world_generation() não deve ser chamado aqui após change_scene_to_file()")

func on_loading_complete():
	hide_loading_screen()

func _on_settings_button_pressed():
	print("⚙️ Abrindo configurações...")
	# Carregar e mostrar tela de settings
	var settings_scene = preload("res://Scenes/Settings.tscn")
	if settings_scene:
		var settings = settings_scene.instantiate()
		add_child(settings)
		settings.z_index = 100
		settings.process_mode = Node.PROCESS_MODE_ALWAYS
		print("✅ Tela de configurações aberta")
	else:
		push_error("❌ Cena Settings.tscn não encontrada!")

func _on_quit_button_pressed():
	print("🚪 Sair!")
	get_tree().quit()
