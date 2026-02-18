extends Node
## Autoload: fade de tela (preto) para transições. Use fade_out_then() para dungeon/teleporte.
## Opcional: defina uma imagem com set_fade_texture() para aparecer sobre o preto durante o fade.

signal fade_finished

var _layer: CanvasLayer
var _rect: ColorRect
var _texture_rect: TextureRect
var _tween: Tween
var _on_fade_out_done: Callable

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.set_process_input(false)
	add_child(_layer)

	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(0, 0, 0, 1)
	_rect.modulate.a = 0.0
	_rect.visible = true
	_layer.add_child(_rect)

	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.modulate.a = 0.0
	_texture_rect.visible = true
	_layer.add_child(_texture_rect)

## Define a imagem exibida durante o fade (ex.: logo, loading). Passe null para só usar o preto.
func set_fade_texture(texture: Texture2D) -> void:
	_texture_rect.texture = texture
	_texture_rect.visible = texture != null

func _tween_finished() -> void:
	fade_finished.emit()
	if _on_fade_out_done.is_valid():
		_on_fade_out_done.call()
		_on_fade_out_done = Callable()

func _tween_fade(to_rect: float, to_texture: float, duration: float, on_done: Callable) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if not _texture_rect.texture:
		to_texture = 0.0
		_texture_rect.modulate.a = 0.0
	else:
		_texture_rect.modulate.a = 1.0 - to_texture
	_rect.modulate.a = 1.0 - to_rect
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_rect, "modulate:a", to_rect, duration)
	if _texture_rect.texture:
		_tween.tween_property(_texture_rect, "modulate:a", to_texture, duration)
	_tween.tween_callback(on_done)

## Fade in: tela preta (e imagem) -> transparente (mostra o jogo).
func fade_in(duration: float = 0.25) -> void:
	_tween_fade(0.0, 0.0, duration, _tween_finished)

## Fade out: transparente -> tela preta (e imagem, se definida).
func fade_out(duration: float = 0.25) -> void:
	_tween_fade(1.0, 1.0, duration, _tween_finished)

## Fade out rápido, opcionalmente espera hold_duration (tela loading), depois chama callback.
## No callback faça a transição e chame fade_in(). Ex.: hold_duration = 0.8 para "loading".
func fade_out_then(duration: float, callback: Callable, hold_duration: float = 0.0) -> void:
	if hold_duration <= 0.0:
		_on_fade_out_done = callback
		fade_out(duration)
		return
	var cb := callback
	_on_fade_out_done = func():
		await get_tree().create_timer(hold_duration).timeout
		if cb.is_valid():
			cb.call()
		_on_fade_out_done = Callable()
	fade_out(duration)
