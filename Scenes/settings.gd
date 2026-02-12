extends Control

## Tela de Configurações
## Gerencia configurações básicas do jogo: áudio, gráficos, etc.

@onready var master_volume_slider = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/MasterVolumeContainer/MasterVolumeSlider
@onready var master_volume_value = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/MasterVolumeContainer/MasterVolumeValue
@onready var music_volume_slider = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/MusicVolumeContainer/MusicVolumeSlider
@onready var music_volume_value = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/MusicVolumeContainer/MusicVolumeValue
@onready var sfx_volume_slider = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/SFXVolumeContainer/SFXVolumeSlider
@onready var sfx_volume_value = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/SFXVolumeContainer/SFXVolumeValue

@onready var fullscreen_checkbox = $Panel/VBoxContainer/ScrollContainer/SettingsContent/GraphicsSection/FullscreenContainer/FullscreenCheckBox
@onready var quality_option_button = $Panel/VBoxContainer/ScrollContainer/SettingsContent/GraphicsSection/QualityContainer/QualityOptionButton
@onready var vsync_checkbox = $Panel/VBoxContainer/ScrollContainer/SettingsContent/GraphicsSection/VSyncContainer/VSyncCheckBox

@onready var back_button = $Panel/VBoxContainer/ButtonsContainer/BackButton
@onready var apply_button = $Panel/VBoxContainer/ButtonsContainer/ApplyButton

# Configurações padrão
var config_file_path = "user://settings.cfg"
var config = ConfigFile.new()

func _ready():
	# Processar sempre (mesmo quando pausado)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Conectar sinais
	_connect_signals()
	
	# Carregar configurações salvas
	load_settings()
	
	# Aplicar configurações carregadas
	apply_settings()

func _connect_signals():
	# Sliders de volume
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# Checkboxes
	if fullscreen_checkbox:
		fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	if vsync_checkbox:
		vsync_checkbox.toggled.connect(_on_vsync_toggled)
	
	# OptionButton
	if quality_option_button:
		quality_option_button.item_selected.connect(_on_quality_option_button_item_selected)
	
	# Botões
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if apply_button:
		apply_button.pressed.connect(_on_apply_button_pressed)

# ========================================
# ÁUDIO
# ========================================

func _on_master_volume_changed(value: float):
	master_volume_value.text = str(int(value)) + "%"
	# Aplicar volume imediatamente
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value / 100.0))

func _on_music_volume_changed(value: float):
	music_volume_value.text = str(int(value)) + "%"
	# Aplicar volume imediatamente (assumindo que há um bus "Music")
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index != -1:
		AudioServer.set_bus_volume_db(music_bus_index, linear_to_db(value / 100.0))

func _on_sfx_volume_changed(value: float):
	sfx_volume_value.text = str(int(value)) + "%"
	# Aplicar volume imediatamente (assumindo que há um bus "SFX")
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index != -1:
		AudioServer.set_bus_volume_db(sfx_bus_index, linear_to_db(value / 100.0))

# ========================================
# GRÁFICOS
# ========================================

func _on_fullscreen_toggled(button_pressed: bool):
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(button_pressed: bool):
	if button_pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_quality_option_button_item_selected(index: int):
	# Aplicar qualidade gráfica baseada no índice
	match index:
		0:  # Muito Baixa
			apply_quality_settings(0.5, false, false)
		1:  # Baixa
			apply_quality_settings(0.75, false, false)
		2:  # Média
			apply_quality_settings(1.0, true, false)
		3:  # Alta
			apply_quality_settings(1.0, true, true)
		4:  # Muito Alta
			apply_quality_settings(1.0, true, true)

func apply_quality_settings(scale: float, shadows: bool, reflections: bool):
	# Aplicar escala de renderização
	get_viewport().set_scaling_3d_scale(scale)
	
	# Aplicar sombras (se disponível)
	var viewport = get_viewport()
	if viewport:
		viewport.shadow_atlas_size = 4096 if shadows else 0
	
	# Aplicar reflexos (se disponível)
	# Nota: Reflexos podem ser controlados via environment se configurado

# ========================================
# SALVAR/CARREGAR CONFIGURAÇÕES
# ========================================

func load_settings():
	# Carregar arquivo de configuração
	var error = config.load(config_file_path)
	if error != OK:
		print("ℹ️ Arquivo de configurações não encontrado. Usando padrões.")
		return
	
	# Carregar valores de áudio
	if master_volume_slider:
		master_volume_slider.value = config.get_value("audio", "master_volume", 100.0)
	if music_volume_slider:
		music_volume_slider.value = config.get_value("audio", "music_volume", 80.0)
	if sfx_volume_slider:
		sfx_volume_slider.value = config.get_value("audio", "sfx_volume", 100.0)
	
	# Carregar valores de gráficos
	if fullscreen_checkbox:
		fullscreen_checkbox.button_pressed = config.get_value("graphics", "fullscreen", false)
	if quality_option_button:
		quality_option_button.selected = config.get_value("graphics", "quality", 2)
	if vsync_checkbox:
		vsync_checkbox.button_pressed = config.get_value("graphics", "vsync", true)

func save_settings():
	# Salvar valores de áudio
	config.set_value("audio", "master_volume", master_volume_slider.value if master_volume_slider else 100.0)
	config.set_value("audio", "music_volume", music_volume_slider.value if music_volume_slider else 80.0)
	config.set_value("audio", "sfx_volume", sfx_volume_slider.value if sfx_volume_slider else 100.0)
	
	# Salvar valores de gráficos
	config.set_value("graphics", "fullscreen", fullscreen_checkbox.button_pressed if fullscreen_checkbox else false)
	config.set_value("graphics", "quality", quality_option_button.selected if quality_option_button else 2)
	config.set_value("graphics", "vsync", vsync_checkbox.button_pressed if vsync_checkbox else true)
	
	# Salvar arquivo
	var error = config.save(config_file_path)
	if error == OK:
		print("✅ Configurações salvas!")
	else:
		push_error("❌ Erro ao salvar configurações: " + str(error))

func apply_settings():
	# Aplicar todas as configurações carregadas
	_on_master_volume_changed(master_volume_slider.value if master_volume_slider else 100.0)
	_on_music_volume_changed(music_volume_slider.value if music_volume_slider else 80.0)
	_on_sfx_volume_changed(sfx_volume_slider.value if sfx_volume_slider else 100.0)
	_on_fullscreen_toggled(fullscreen_checkbox.button_pressed if fullscreen_checkbox else false)
	_on_vsync_toggled(vsync_checkbox.button_pressed if vsync_checkbox else true)
	if quality_option_button:
		_on_quality_option_button_item_selected(quality_option_button.selected)

# ========================================
# BOTÕES
# ========================================

func _on_apply_button_pressed():
	print("💾 Aplicando configurações...")
	save_settings()
	apply_settings()
	print("✅ Configurações aplicadas!")

func _on_back_button_pressed():
	print("🔙 Voltando ao menu...")
	queue_free()

# Fechar com ESC
func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC
		_on_back_button_pressed()
