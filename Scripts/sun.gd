extends Node3D

@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment

# Horário atual (0–24)
@export_range(0, 24) var hour := 12.0

# Velocidade do tempo (quanto maior, mais rápido passa o dia)
@export var time_speed := 1.0

# Cores estilo Muck
@export var day_color := Color(1, 0.95, 0.8)
@export var night_color := Color(0.1, 0.1, 0.3)

func _process(delta):

	# Avança o tempo
	hour += delta * time_speed

	# Mantém sempre entre 0 e 24
	if hour >= 24:
		hour = 0

	update_sun()
	update_sky()

func update_sun():

	# Normaliza o tempo para 0–1
	var t = hour / 24.0

	# 🌞 Nascer no Leste (-90) e pôr no Oeste (90)
	sun.rotation_degrees = Vector3(
		lerp(-10.0, -170.0, t),  # arco no céu
		lerp(-90.0, 90.0, t),    # leste → oeste
		0
	)

	# -------- SISTEMA 12H DIA / 12H NOITE --------

	var curve = 0.0

	# Das 6h às 18h é dia
	if hour >= 6 and hour <= 18:
		# Transição suave dentro do período de dia
		curve = smoothstep(6.0, 18.0, hour)
	else:
		# Noite
		curve = 0.0

	# Energia do sol baseada na curva
	sun.light_energy = lerp(0.1, 2.0, curve)

	# Cor do sol entre noite e dia
	sun.light_color = night_color.lerp(day_color, curve)

func update_sky():

	var sky = environment.environment.sky
	if not sky:
		return

	var material = sky.sky_material

	if material is ProceduralSkyMaterial:

		var curve = 0.0

		if hour >= 6 and hour <= 18:
			curve = smoothstep(6.0, 18.0, hour)

		# Cores do céu interpoladas
		var day_top = Color(0.3, 0.6, 1.0)
		var day_horizon = Color(0.6, 0.8, 1.0)

		var night_top = Color(0.02, 0.02, 0.06)
		var night_horizon = Color(0.05, 0.05, 0.1)

		material.sky_top_color = night_top.lerp(day_top, curve)
		material.sky_horizon_color = night_horizon.lerp(day_horizon, curve)

		# Sol visível e suave
		material.sun_angle_max = 1.5
		material.sun_curve = 0.15
