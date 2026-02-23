extends Node
## Autoload: sistema central de efeitos sonoros (SFX).
## - Cria buses Music/SFX se não existirem (compatível com SettingsManager).
## - Pool de AudioStreamPlayers no bus SFX (vários sons ao mesmo tempo).
## - Registro de sons por ID para play_sfx_id("ui_click"), etc.
##
## Adicione como autoload "SoundManager". Para música/ambiente use nós na cena (Music bus).

const SFX_POOL_SIZE := 16
const BUS_SFX := &"SFX"

var _pool: Array[AudioStreamPlayer] = []
var _next_index: int = 0

## IDs conhecidos → AudioStream (preload ou carregado). Adicione mais em _ready ou via register_sfx().
var _registry: Dictionary = {}

func _ready() -> void:
	_ensure_sfx_bus()
	_build_pool()
	_register_default_sounds()


func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")


func _build_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		p.name = "SFX_%d" % i
		add_child(p)
		_pool.append(p)
	_next_index = 0


func _register_default_sounds() -> void:
	var base := "res://Assets/sounds/"
	var ui := base + "UI/"
	var player_dir := base + "player/"
	var world_dir := base + "world/"
	var world_cap := base + "World/"  # pasta pode ser World (teleporting-sound.wav)
	# UI — botões e interface (todos em UI/)
	_try_register(&"ui_click", [ui + "player-select.mp3"])
	_try_register(&"ui_hover", [ui + "hover.mp3"])
	# UI — inventário, seleção, notificação
	_try_register(&"ui_inventory_open", [ui + "open-inventory.mp3"])
	_try_register(&"ui_inventory_select", [ui + "select-item.mp3"])

	_try_register(&"ui_select", [ui + "player-select.mp3"])
	_try_register(&"new_item", [ui + "new-item.mp3"])
	_try_register(&"new_coin", [ui + "coin.mp3"])


	_try_register(&"ui_notification", [ui + "bell-notification.wav"])
	# Player — hurt, death, heal (player/ ou UI/)
	_try_register(&"player_hurt", [
		ui + "fast-punch-2047.wav",
		player_dir + "player_hurt.mp3", player_dir + "player_hurt.wav",
	])
	_try_register(&"player_death", [
		player_dir + "player_death.mp3", player_dir + "player_death.wav",
	])
	_try_register(&"player_heal", [
		ui + "eat.wav",
		player_dir + "player_heal.mp3", player_dir + "player_heal.wav",
	])
	# Mundo (world/)
	_try_register(&"chest_open", [
		world_dir + "chest_open.mp3", world_dir + "chest_open.wav",
	])
	# Teleporte e dungeon (landing pad) — arquivo em World/ ou world/ ou UI/
	_try_register(&"teleport", [
		ui + "teleporting-sound.wav",
	])
	_try_register(&"enimy-hit", [
		world_cap + "enimy-hit.wav",
	])
	_try_register(&"harvest_complete", [
		ui + "success.mp3",
	])
	_try_register(&"working", [
		ui + "working.mp3",
	])


func play(id: String) -> void:
	if not SoundManager:
		return
	
	var sound_id: StringName = StringName(id)
	
	if SoundManager.has_sfx(sound_id):
		SoundManager.play_sfx_id(sound_id)
	else:
		push_warning("SFX não encontrado: %s" % id)

## Tenta carregar um dos caminhos; registra o primeiro que existir. Não sobrescreve se já registrado.
func _try_register(id: StringName, paths: Array) -> void:
	if _registry.has(id):
		return
	for path in paths:
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream:
				_registry[id] = stream
				return


## Registra um som por ID (para play_sfx_id). Útil para outros autoloads ou cenas.
func register_sfx(id: StringName, stream: AudioStream) -> void:
	if stream:
		_registry[id] = stream


## Toca um stream qualquer no pool SFX (vários podem tocar ao mesmo tempo).
## volume_db e pitch_scale opcionais.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream:
		return
	var p := _get_available_player()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.play()


## Toca um som registrado por ID. Se o ID não existir, não faz nada.
func play_sfx_id(id: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _registry.has(id):
		return
	play_sfx(_registry[id], volume_db, pitch_scale)


## Compatibilidade: toca um stream (ex.: landingpad, teleporte). Usa o pool.
func play_stream(stream: AudioStream) -> void:
	play_sfx(stream, 0.0, 1.0)


func _get_available_player() -> AudioStreamPlayer:
	# Round-robin: sempre pega o próximo; se estiver tocando, para e reutiliza (evita corte raro)
	var p := _pool[_next_index]
	_next_index = (_next_index + 1) % SFX_POOL_SIZE
	if p.playing:
		p.stop()
	return p


## Retorna true se o ID está registrado (útil para UI condicional).
func has_sfx(id: StringName) -> bool:
	return _registry.has(id)


## Conecta todos os Button sob `root` a ui_click (pressed) e ui_hover (mouse_entered).
## Chame no _ready() dos menus (ex.: SoundManager.connect_buttons_sound(self)).
func connect_buttons_sound(root: Node) -> void:
	for child in _collect_all_children(root):
		if child is Button:
			_connect_single_button(child as Button)


func _collect_all_children(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	out.append(n)
	for c in n.get_children():
		out.append_array(_collect_all_children(c))
	return out


func _connect_single_button(btn: Button) -> void:
	if not btn.pressed.is_connected(_on_button_pressed):
		btn.pressed.connect(_on_button_pressed)
	if not btn.mouse_entered.is_connected(_on_button_hover):
		btn.mouse_entered.connect(_on_button_hover)


func _on_button_pressed() -> void:
	play_sfx_id(&"ui_click")


func _on_button_hover() -> void:
	play_sfx_id(&"ui_hover")
