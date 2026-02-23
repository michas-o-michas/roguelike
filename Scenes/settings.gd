extends Control

## Tela de Configurações
## Usa SettingsManager (autoload) para carregar, aplicar e salvar. As opções são reais e persistem em user://settings.cfg.

@onready var master_volume_slider = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/MasterVolumeContainer/MasterVolumeSlider
@onready var master_volume_value = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/MasterVolumeContainer/MasterVolumeValue
@onready var music_volume_slider = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/MusicVolumeContainer/MusicVolumeSlider
@onready var music_volume_value = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/MusicVolumeContainer/MusicVolumeValue
@onready var sfx_volume_slider = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/SFXVolumeContainer/SFXVolumeSlider
@onready var sfx_volume_value = $Panel/VBoxContainer/ScrollContainer/SettingsContent/AudioSection/SFXVolumeContainer/SFXVolumeValue

@onready var fullscreen_checkbox = $Panel/VBoxContainer/ScrollContainer/SettingsContent/GraphicsSection/FullscreenContainer/FullscreenCheckBox
@onready var quality_option_button = $Panel/VBoxContainer/ScrollContainer/SettingsContent/GraphicsSection/QualityContainer/QualityOptionButton
@onready var vsync_checkbox = $Panel/VBoxContainer/ScrollContainer/SettingsContent/GraphicsSection/VSyncContainer/VSyncCheckBox

@onready var ssao_checkbox = $Panel/VBoxContainer/ScrollContainer/SettingsContent/EnvironmentSection/SSAOContainer/SSAOCheckBox
@onready var glow_checkbox = $Panel/VBoxContainer/ScrollContainer/SettingsContent/EnvironmentSection/GlowContainer/GlowCheckBox
@onready var fog_checkbox = $Panel/VBoxContainer/ScrollContainer/SettingsContent/EnvironmentSection/FogContainer/FogCheckBox
@onready var ssr_checkbox = $Panel/VBoxContainer/ScrollContainer/SettingsContent/EnvironmentSection/SSRContainer/SSRCheckBox
@onready var ssil_checkbox = $Panel/VBoxContainer/ScrollContainer/SettingsContent/EnvironmentSection/SSILContainer/SSILCheckBox
@onready var sdfgi_checkbox = $Panel/VBoxContainer/ScrollContainer/SettingsContent/EnvironmentSection/SDFGIContainer/SDFGICheckBox

@onready var back_button = $Panel/VBoxContainer/ButtonsContainer/BackButton
@onready var apply_button = $Panel/VBoxContainer/ButtonsContainer/ApplyButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_signals()
	_sync_ui_from_manager()
	if SoundManager:
		SoundManager.connect_buttons_sound(self)


func _connect_signals() -> void:
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if fullscreen_checkbox:
		fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	if vsync_checkbox:
		vsync_checkbox.toggled.connect(_on_vsync_toggled)
	if quality_option_button:
		quality_option_button.item_selected.connect(_on_quality_selected)
	if ssao_checkbox:
		ssao_checkbox.toggled.connect(_on_environment_toggled)
	if glow_checkbox:
		glow_checkbox.toggled.connect(_on_environment_toggled)
	if fog_checkbox:
		fog_checkbox.toggled.connect(_on_environment_toggled)
	if ssr_checkbox:
		ssr_checkbox.toggled.connect(_on_environment_toggled)
	if ssil_checkbox:
		ssil_checkbox.toggled.connect(_on_environment_toggled)
	if sdfgi_checkbox:
		sdfgi_checkbox.toggled.connect(_on_environment_toggled)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if apply_button:
		apply_button.pressed.connect(_on_apply_button_pressed)


func _sync_ui_from_manager() -> void:
	if not SettingsManager:
		return
	if master_volume_slider:
		master_volume_slider.value = SettingsManager.get_master_volume()
	if master_volume_value:
		master_volume_value.text = str(int(SettingsManager.get_master_volume())) + "%"
	if music_volume_slider:
		music_volume_slider.value = SettingsManager.get_music_volume()
	if music_volume_value:
		music_volume_value.text = str(int(SettingsManager.get_music_volume())) + "%"
	if sfx_volume_slider:
		sfx_volume_slider.value = SettingsManager.get_sfx_volume()
	if sfx_volume_value:
		sfx_volume_value.text = str(int(SettingsManager.get_sfx_volume())) + "%"
	if fullscreen_checkbox:
		fullscreen_checkbox.button_pressed = SettingsManager.get_fullscreen()
	if vsync_checkbox:
		vsync_checkbox.button_pressed = SettingsManager.get_vsync()
	if quality_option_button:
		quality_option_button.selected = SettingsManager.get_quality_index()
	if ssao_checkbox:
		ssao_checkbox.button_pressed = SettingsManager.get_ssao_enabled()
	if glow_checkbox:
		glow_checkbox.button_pressed = SettingsManager.get_glow_enabled()
	if fog_checkbox:
		fog_checkbox.button_pressed = SettingsManager.get_fog_enabled()
	if ssr_checkbox:
		ssr_checkbox.button_pressed = SettingsManager.get_ssr_enabled()
	if ssil_checkbox:
		ssil_checkbox.button_pressed = SettingsManager.get_ssil_enabled()
	if sdfgi_checkbox:
		sdfgi_checkbox.button_pressed = SettingsManager.get_sdfgi_enabled()


# ---- Áudio (aplica na hora e atualiza o manager) ----

func _on_master_volume_changed(value: float) -> void:
	if master_volume_value:
		master_volume_value.text = str(int(value)) + "%"
	if SettingsManager:
		SettingsManager.set_master_volume(value)
		SettingsManager.apply_audio()


func _on_music_volume_changed(value: float) -> void:
	if music_volume_value:
		music_volume_value.text = str(int(value)) + "%"
	if SettingsManager:
		SettingsManager.set_music_volume(value)
		SettingsManager.apply_audio()


func _on_sfx_volume_changed(value: float) -> void:
	if sfx_volume_value:
		sfx_volume_value.text = str(int(value)) + "%"
	if SettingsManager:
		SettingsManager.set_sfx_volume(value)
		SettingsManager.apply_audio()


# ---- Gráficos (aplica na hora e atualiza o manager) ----

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if SettingsManager:
		SettingsManager.set_fullscreen(button_pressed)
		SettingsManager.apply_graphics()


func _on_vsync_toggled(button_pressed: bool) -> void:
	if SettingsManager:
		SettingsManager.set_vsync(button_pressed)
		SettingsManager.apply_graphics()


func _on_quality_selected(index: int) -> void:
	if SettingsManager:
		SettingsManager.set_quality_index(index)
		SettingsManager.apply_graphics()


func _on_environment_toggled(_pressed: bool) -> void:
	if not SettingsManager:
		return
	SettingsManager.set_ssao_enabled(ssao_checkbox.button_pressed if ssao_checkbox else true)
	SettingsManager.set_glow_enabled(glow_checkbox.button_pressed if glow_checkbox else true)
	SettingsManager.set_fog_enabled(fog_checkbox.button_pressed if fog_checkbox else true)
	SettingsManager.set_ssr_enabled(ssr_checkbox.button_pressed if ssr_checkbox else true)
	SettingsManager.set_ssil_enabled(ssil_checkbox.button_pressed if ssil_checkbox else false)
	SettingsManager.set_sdfgi_enabled(sdfgi_checkbox.button_pressed if sdfgi_checkbox else false)
	SettingsManager.apply_environment_to_scene()


# ---- Persistir e fechar ----

func _persist_and_apply() -> void:
	if not SettingsManager:
		return
	SettingsManager.set_master_volume(master_volume_slider.value if master_volume_slider else 100.0)
	SettingsManager.set_music_volume(music_volume_slider.value if music_volume_slider else 80.0)
	SettingsManager.set_sfx_volume(sfx_volume_slider.value if sfx_volume_slider else 100.0)
	SettingsManager.set_fullscreen(fullscreen_checkbox.button_pressed if fullscreen_checkbox else false)
	SettingsManager.set_vsync(vsync_checkbox.button_pressed if vsync_checkbox else true)
	SettingsManager.set_quality_index(quality_option_button.selected if quality_option_button else 2)
	SettingsManager.set_ssao_enabled(ssao_checkbox.button_pressed if ssao_checkbox else true)
	SettingsManager.set_glow_enabled(glow_checkbox.button_pressed if glow_checkbox else true)
	SettingsManager.set_fog_enabled(fog_checkbox.button_pressed if fog_checkbox else true)
	SettingsManager.set_ssr_enabled(ssr_checkbox.button_pressed if ssr_checkbox else true)
	SettingsManager.set_ssil_enabled(ssil_checkbox.button_pressed if ssil_checkbox else false)
	SettingsManager.set_sdfgi_enabled(sdfgi_checkbox.button_pressed if sdfgi_checkbox else false)
	var err := SettingsManager.save_to_disk()
	if err == OK:
		SettingsManager.apply_all()


func _on_apply_button_pressed() -> void:
	_persist_and_apply()


func _on_back_button_pressed() -> void:
	_persist_and_apply()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
