extends Control

## Menu de pausa in-game (ESC). Mostra opções de Configurações e Sair do jogo.
## Deve ser filho de um CanvasLayer no Level1 (ou cena do jogo) para aparecer acima do mundo.

@onready var panel: Panel = $Panel
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

var _settings_scene: PackedScene
var _settings_instance: Control


func _ready() -> void:
	visible = false
	_settings_scene = preload("res://Scenes/Settings.tscn")
	# Reparentar para a raiz (deferred) para não ficar sob nós pausados
	call_deferred("_reparent_to_root")
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)


func _reparent_to_root() -> void:
	var root := get_tree().root
	var layer := CanvasLayer.new()
	layer.name = "PauseMenuRootLayer"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = 100
	root.add_child(layer)
	var old_parent := get_parent()
	old_parent.remove_child(self)
	layer.add_child(self)
	_set_process_mode_always(self)
	# Raiz e overlay não devem capturar cliques; deixar passar para o Panel/botões
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay := get_node_or_null("Overlay")
	if overlay is Control:
		(overlay as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_process_mode_always(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	for child in node.get_children():
		_set_process_mode_always(child)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if visible:
		_close()
	else:
		_open()


func _open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	if settings_button:
		settings_button.grab_focus()


func _close() -> void:
	if _settings_instance and is_instance_valid(_settings_instance):
		_settings_instance.queue_free()
		_settings_instance = null
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_settings_pressed() -> void:
	if not _settings_scene:
		return
	_settings_instance = _settings_scene.instantiate()
	add_child(_settings_instance)
	_settings_instance.z_index = 100
	_settings_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	# Ao clicar Voltar na tela de configurações, ela dá queue_free(); o menu de pausa continua visível


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	# O MainMenu remove o PauseMenuRootLayer no seu _ready() para não interferir
