extends Node

var inventory := {}

signal inventory_changed
signal world_generation_progress(percent: float, stage: int, message: String)
signal world_generation_complete()

var loading_screen: Control = null
var world_generator: InfiniteWorldGenerator = null

func add_item(id: String, amount: int):
	if not inventory.has(id):
		inventory[id] = 0

	inventory[id] += amount
	emit_signal("inventory_changed")

func remove_item(id: String, amount: int) -> bool:
	if not inventory.has(id):
		return false

	if inventory[id] < amount:
		return false

	inventory[id] -= amount
	emit_signal("inventory_changed")
	return true

func get_amount(id: String) -> int:
	if inventory.has(id):
		return inventory[id]
	return 0

# ========================================
# SISTEMA DE LOADING
# ========================================

func set_loading_screen(screen: Control):
	loading_screen = screen

func set_world_generator(generator: InfiniteWorldGenerator):
	world_generator = generator
	if world_generator:
		# Conectar sinais de progresso
		if not world_generator.progress_updated.is_connected(_on_world_generation_progress):
			world_generator.progress_updated.connect(_on_world_generation_progress)
		if not world_generator.generation_complete.is_connected(_on_world_generation_complete):
			world_generator.generation_complete.connect(_on_world_generation_complete)

func _on_world_generation_progress(percent: float, stage: int, message: String):
	# Atualizar tela de loading
	if loading_screen and loading_screen.has_method("update_progress"):
		loading_screen.update_progress(percent, message)
	
	# Emitir sinal para outros sistemas
	emit_signal("world_generation_progress", percent, stage, message)
	
	print("📊 Progresso: ", int(percent), "% - ", message)

func _on_world_generation_complete():
	# Ocultar tela de loading após um pequeno delay
	if loading_screen:
		await get_tree().create_timer(0.5).timeout
		if loading_screen.has_method("hide_loading"):
			loading_screen.hide_loading()
	
	# Emitir sinal
	emit_signal("world_generation_complete")
	print("✅ Geração do mundo completa!")
