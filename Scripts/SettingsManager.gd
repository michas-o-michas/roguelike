extends Node

## Autoload: gerencia configurações do jogo (áudio, gráficos).
## Carrega e aplica as configurações salvas na inicialização; a tela de configurações
## lê/escreve através dele e persiste em user://settings.cfg.

const CONFIG_PATH := "user://settings.cfg"

# Valores em memória (defaults)
var _master_volume: float = 100.0
var _music_volume: float = 80.0
var _sfx_volume: float = 100.0
var _fullscreen: bool = false
var _vsync: bool = true
var _quality_index: int = 2  # 0=Muito baixa, 1=Baixa, 2=Média, 3=Alta
# Environment (WorldEnvironment) — controlados pela tela de configurações
var _ssao_enabled: bool = true
var _ssil_enabled: bool = false
var _sdfgi_enabled: bool = false
var _glow_enabled: bool = true
var _fog_enabled: bool = true
var _ssr_enabled: bool = true

var _config: ConfigFile
var _loaded: bool = false


func _ready() -> void:
	_config = ConfigFile.new()
	_ensure_audio_buses()
	load_from_disk()
	apply_all()


# -----------------------------------------------------------------------------
# Leitura (para a UI de configurações)
# -----------------------------------------------------------------------------

func get_master_volume() -> float:
	return _master_volume

func get_music_volume() -> float:
	return _music_volume

func get_sfx_volume() -> float:
	return _sfx_volume

func get_fullscreen() -> bool:
	return _fullscreen

func get_vsync() -> bool:
	return _vsync

func get_quality_index() -> int:
	return _quality_index

func get_ssao_enabled() -> bool:
	return _ssao_enabled
func get_ssil_enabled() -> bool:
	return _ssil_enabled
func get_sdfgi_enabled() -> bool:
	return _sdfgi_enabled
func get_glow_enabled() -> bool:
	return _glow_enabled
func get_fog_enabled() -> bool:
	return _fog_enabled
func get_ssr_enabled() -> bool:
	return _ssr_enabled


# -----------------------------------------------------------------------------
# Escrita (a UI chama antes de save_to_disk)
# -----------------------------------------------------------------------------

func set_master_volume(v: float) -> void:
	_master_volume = clampf(v, 0.0, 100.0)

func set_music_volume(v: float) -> void:
	_music_volume = clampf(v, 0.0, 100.0)

func set_sfx_volume(v: float) -> void:
	_sfx_volume = clampf(v, 0.0, 100.0)

func set_fullscreen(v: bool) -> void:
	_fullscreen = v

func set_vsync(v: bool) -> void:
	_vsync = v

func set_quality_index(v: int) -> void:
	_quality_index = clampi(v, 0, 3)

func set_ssao_enabled(v: bool) -> void:
	_ssao_enabled = v
func set_ssil_enabled(v: bool) -> void:
	_ssil_enabled = v
func set_sdfgi_enabled(v: bool) -> void:
	_sdfgi_enabled = v
func set_glow_enabled(v: bool) -> void:
	_glow_enabled = v
func set_fog_enabled(v: bool) -> void:
	_fog_enabled = v
func set_ssr_enabled(v: bool) -> void:
	_ssr_enabled = v


# -----------------------------------------------------------------------------
# Persistência
# -----------------------------------------------------------------------------

func load_from_disk() -> void:
	var err := _config.load(CONFIG_PATH)
	if err != OK:
		return
	_master_volume = _config.get_value("audio", "master_volume", 100.0)
	_music_volume = _config.get_value("audio", "music_volume", 80.0)
	_sfx_volume = _config.get_value("audio", "sfx_volume", 100.0)
	_fullscreen = _config.get_value("graphics", "fullscreen", false)
	_vsync = _config.get_value("graphics", "vsync", true)
	_quality_index = clampi(_config.get_value("graphics", "quality", 2), 0, 3)
	_ssao_enabled = _config.get_value("environment", "ssao_enabled", true)
	_ssil_enabled = _config.get_value("environment", "ssil_enabled", false)
	_sdfgi_enabled = _config.get_value("environment", "sdfgi_enabled", false)
	_glow_enabled = _config.get_value("environment", "glow_enabled", true)
	_fog_enabled = _config.get_value("environment", "fog_enabled", true)
	_ssr_enabled = _config.get_value("environment", "ssr_enabled", true)
	_loaded = true


func save_to_disk() -> Error:
	_config.set_value("audio", "master_volume", _master_volume)
	_config.set_value("audio", "music_volume", _music_volume)
	_config.set_value("audio", "sfx_volume", _sfx_volume)
	_config.set_value("graphics", "fullscreen", _fullscreen)
	_config.set_value("graphics", "vsync", _vsync)
	_config.set_value("graphics", "quality", _quality_index)
	_config.set_value("environment", "ssao_enabled", _ssao_enabled)
	_config.set_value("environment", "ssil_enabled", _ssil_enabled)
	_config.set_value("environment", "sdfgi_enabled", _sdfgi_enabled)
	_config.set_value("environment", "glow_enabled", _glow_enabled)
	_config.set_value("environment", "fog_enabled", _fog_enabled)
	_config.set_value("environment", "ssr_enabled", _ssr_enabled)
	return _config.save(CONFIG_PATH)


# -----------------------------------------------------------------------------
# Áudio — garantir buses Music e SFX (sliders funcionam)
# -----------------------------------------------------------------------------

func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "Music")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus(2)
		AudioServer.set_bus_name(2, "SFX")


# -----------------------------------------------------------------------------
# Aplicar ao motor (DisplayServer, AudioServer, Viewport)
# -----------------------------------------------------------------------------

func apply_all() -> void:
	apply_audio()
	apply_graphics()


func apply_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(_master_volume / 100.0))
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(_music_volume / 100.0))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(_sfx_volume / 100.0))


func apply_graphics() -> void:
	# Janela
	if _fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# VSync
	if _vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Qualidade (viewport raiz): sombras e MSAA apenas — resolução 3D não é alterada
	var vp := get_viewport()
	if vp:
		var shadow_size: int
		var msaa: int  # Viewport.MSAA_*
		match _quality_index:
			0:  # Muito baixa
				shadow_size = 1024
				msaa = Viewport.MSAA_DISABLED
			1:  # Baixa
				shadow_size = 2048
				msaa = Viewport.MSAA_DISABLED
			2:  # Média
				shadow_size = 4096
				msaa = Viewport.MSAA_2X
			3:  # Alta
				shadow_size = 8192
				msaa = Viewport.MSAA_4X
			_:
				shadow_size = 4096
				msaa = Viewport.MSAA_2X
		vp.positional_shadow_atlas_size = shadow_size
		vp.msaa_3d = msaa
	_apply_environment_settings()


## Chame isso quando a cena do jogo (ex.: Level1) carregar, para aplicar qualidade ao
## WorldEnvironment dessa cena (ex.: o que está dentro de Day_Night).
func apply_environment_to_scene() -> void:
	_apply_environment_settings()


## Aplica opções de Environment (SSAO, neblina, glow, SDFGI, etc.) aos WorldEnvironment
## que estiverem no grupo "world_environment_apply" (ex.: o do DayNightCycle no Level1).
func _apply_environment_settings() -> void:
	var list := get_tree().get_nodes_in_group("world_environment_apply")
	for node in list:
		if not node is WorldEnvironment:
			continue
		var we: WorldEnvironment = node
		if not we.environment:
			continue
		var env: Environment = we.environment
		env.ssao_enabled = _ssao_enabled
		env.ssil_enabled = _ssil_enabled
		env.sdfgi_enabled = _sdfgi_enabled
		env.glow_enabled = _glow_enabled
		env.fog_enabled = _fog_enabled
		env.ssr_enabled = _ssr_enabled
