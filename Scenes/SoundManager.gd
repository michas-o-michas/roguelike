extends Node
## Autoload: toca sons de efeito (teleporte, etc.). Adicione como autoload "SoundManager".

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)

func play_stream(stream: AudioStream) -> void:
	if not stream:
		return
	_player.stream = stream
	_player.play()
