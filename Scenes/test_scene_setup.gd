extends Node

## Script de Setup da Cena Test - Configura GameManager e WorldGenerator após carregamento
## Este script deve ser anexado ao nó raiz da cena Test.tscn (Level1)

@onready var world_generator: InfiniteWorldGenerator = get_parent() if get_parent() is InfiniteWorldGenerator else get_node_or_null("../InfiniteWorldGenerator")
@onready var player: Node3D = get_node_or_null("../Player")

var loading_screen_scene = preload("res://Scenes/LoadingScreen.tscn")
var loading_screen: Control = null

func _ready():
	# Aguardar alguns frames para garantir que tudo está carregado
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Procurar InfiniteWorldGenerator (pode ser o nó pai ou um nó irmão)
	if not world_generator:
		world_generator = get_tree().get_first_node_in_group("world_generator")
	if not world_generator:
		# Tentar encontrar na cena atual
		var scene_root = get_tree().current_scene
		if scene_root:
			if scene_root is InfiniteWorldGenerator:
				world_generator = scene_root
			else:
				world_generator = scene_root.get_node_or_null("InfiniteWorldGenerator")
				if not world_generator:
					# Tentar encontrar qualquer InfiniteWorldGenerator na cena
					for child in scene_root.get_children():
						if child is InfiniteWorldGenerator:
							world_generator = child
							break
	
	# Procurar Player
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		var scene_root = get_tree().current_scene
		if scene_root:
			player = scene_root.get_node_or_null("Player")
	
	# Verificar se foi carregado do MainMenu (procurar tela de loading existente)
	loading_screen = get_tree().root.get_node_or_null("LoadingScreen")
	
	# Se não encontrou, criar uma nova
	if not loading_screen:
		loading_screen = loading_screen_scene.instantiate()
		loading_screen.name = "LoadingScreen"
		get_tree().root.add_child(loading_screen)
		loading_screen.z_index = 1000
		loading_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Procurar GameManager (autoload; não criar manualmente)
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		game_manager = get_node_or_null("/root/GameManager")

	# Configurar GameManager e WorldGenerator
	if world_generator and world_generator is InfiniteWorldGenerator:
		print("🌍 WorldGenerator encontrado!")
		
		# Configurar GameManager
		if game_manager and game_manager.has_method("set_world_generator"):
			game_manager.set_world_generator(world_generator)
			if loading_screen and game_manager.has_method("set_loading_screen"):
				game_manager.set_loading_screen(loading_screen)
		
		# Iniciar geração do mundo
		# Se player já existe na cena, passar ele; senão será instanciado depois
		if player:
			world_generator.start_world_generation(player)
		else:
			world_generator.start_world_generation()
	else:
		push_warning("⚠️ InfiniteWorldGenerator não encontrado na cena Test!")
		if loading_screen:
			loading_screen.queue_free()
