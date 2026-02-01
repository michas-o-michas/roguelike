extends Node
class_name DayNightSystem

@export var day_length := 60.0

@export var day_color := Color(1, 1, 1)
@export var night_color := Color(0.349, 0.475, 0.937, 1.0)

@export var day_energy := 1.2
@export var night_energy := 0.1

# Intensidade do céu (o que você pediu)
@export var day_sky_intensity := 1.0
@export var night_sky_intensity := 0.1

@onready var sun: DirectionalLight3D = $"../DirectionalLight3D"
@onready var environment: WorldEnvironment = $"../WorldEnvironment"
@onready var night_cycle: AudioStreamPlayer2D = $"../NightCycle"
@onready var day_cycle: AudioStreamPlayer2D = $"../DayCycle"

var time: float = 0.0

signal night_started
signal day_started

var last_was_night := false


func _ready() -> void:
	# começa exatamente no amanhecer
	time = day_length * 0.25
	last_was_night = true
	day_cycle.stop()
	night_cycle.stop()


func _process(delta):
	time += delta

	if time > day_length:
		time = 0

	update_lighting()
	check_day_night_transition()


func update_lighting():
	var t = time / day_length

	var curve = (sin(t * PI * 2 - PI / 2) + 1) / 2

	# Atualiza cor e energia da luz do sol
	sun.light_color = night_color.lerp(day_color, curve)
	sun.light_energy = lerpf(night_energy, day_energy, curve)

	# Sol faz um arco completo no céu
	sun.rotation_degrees.x = lerpf(-10, -170, t)

	# Intensidade geral do ambiente
	environment.environment.background_energy_multiplier = lerpf(0.2, 1.0, curve)

	# ---- CONTROLE DO PANORAMA DO CÉU ----
	var sky = environment.environment.sky

	if sky and sky.sky_material:
		return
		sky.sky_material.energy_multiplier = lerpf(
			night_sky_intensity,
			day_sky_intensity,
			curve
		)



func check_day_night_transition():
	var t = time / day_length

	# Considerar noite quando a curva estiver abaixo de 0.5
	var is_night_now = t < 0.25 or t > 0.75

	if is_night_now and not last_was_night:
		emit_signal("night_started")
		print("🌙 NOITE começou")
		night_cycle.play()

	if not is_night_now and last_was_night:
		emit_signal("day_started")
		print("☀ DIA começou")
		day_cycle.play()

	last_was_night = is_night_now
