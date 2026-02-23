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
	_face_camera()

func _face_camera() -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return
	look_at(cam.global_position)
	# look_at aponta -Z para a câmera; Label3D desenha em +Z, então gira 180° para o texto ficar legível
	rotate_object_local(Vector3.UP, PI)

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
	start_position = global_position
	_face_camera()
	# Cores baseadas no tipo de dano
	if value > 0:
		label.modulate = Color(1.0, 0.35, 0.2)
	else:
		label.modulate = Color(0.2, 1.0, 0.4)  # Cura
