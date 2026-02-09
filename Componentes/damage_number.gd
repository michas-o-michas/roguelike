extends Node3D
class_name DamageNumber

@export var float_speed: float = 5.0
@export var float_height: float = 2.0
@export var lifetime: float = 1.0
@export var fade_time: float = 0.5

@onready var label: Label3D = $Label3D

var start_position: Vector3
var timer: float = 0.0

func _ready():
	start_position = global_position
	look_at(get_viewport().get_camera_3d().global_position)

func _process(delta):
	timer += delta
	
	# Flutuar para cima
	var t = timer / lifetime
	global_position = start_position + Vector3(0, float_height * t, 0)
	
	# Fade out
	if timer > lifetime - fade_time:
		var alpha = 1.0 - (timer - (lifetime - fade_time)) / fade_time
		label.modulate.a = alpha
	
	# Remover
	if timer >= lifetime:
		queue_free()

func set_value(value: float):
	label.text = str(int(value))
	
	# Cores baseadas no tipo de dano
	if value > 0:
		label.modulate = Color.RED
	else:
		label.modulate = Color.GREEN  # Para cura
