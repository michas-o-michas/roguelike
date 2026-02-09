extends Node3D

# Referências
@onready var sun_pivot: Node3D = $SunPivot
@onready var sun: DirectionalLight3D = $SunPivot/DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment

# Duração do ciclo completo em segundos
@export var cycle_duration: float = 120.0

# Tempo atual do ciclo (0.0 a 1.0)
@export var time_of_day: float = 0.0  # Começa no nascer do sol

# Cores do sol
var sunrise_color = Color(1.0, 0.6, 0.4)
var day_color = Color(1.0, 0.98, 0.95)
var sunset_color = Color(1.0, 0.4, 0.2)
var night_color = Color(0.4, 0.5, 0.7)  # Azulado para a luz da lua

# Cores do céu (topo)
var sky_sunrise = Color(1.0, 0.5, 0.3)
var sky_day = Color(0.385, 0.647, 0.912)
var sky_sunset = Color(1.0, 0.3, 0.2)
var sky_night = Color(0.01, 0.01, 0.05)

# Cores do horizonte
var horizon_sunrise = Color(1.0, 0.7, 0.5)
var horizon_day = Color(0.646, 0.824, 0.941)
var horizon_sunset = Color(1.0, 0.5, 0.3)
var horizon_night = Color(0.05, 0.05, 0.15)

# Referência ao material do céu
var sky_material: ProceduralSkyMaterial

func _ready():
	if not sun:
		push_error("DirectionalLight3D não encontrado!")
		return
	
	# Configurações do sol para evitar blur
	sun.shadow_enabled = true
	sun.shadow_blur = 0.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	
	if not world_env:
		push_error("WorldEnvironment não encontrado!")
		return
	
	# Acessa o material do céu
	if world_env.environment and world_env.environment.sky:
		sky_material = world_env.environment.sky.sky_material as ProceduralSkyMaterial
		
		if sky_material:
			print("Sky Material encontrado com sucesso!")
			sky_material.sky_curve = 0.15
			sky_material.ground_curve = 0.02
			sky_material.sun_angle_max = 30.0
			sky_material.sun_curve = 0.05
		else:
			push_error("ProceduralSkyMaterial não encontrado!")
	else:
		push_error("Environment ou Sky não configurado!")
	
	# Configurar ambiente
	if world_env.environment:
		world_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		world_env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		world_env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		world_env.environment.tonemap_exposure = 1.0
	
	update_sun()
	update_sky()

func _process(delta):
	time_of_day += delta / cycle_duration
	
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	
	update_sun()
	update_sky()

func update_sun():
	if not sun or not sun_pivot:
		return
	
	var intensity = 1.0
	var color = day_color
	
	# DIA: time_of_day de 0.0 a 0.5 (sol visível)
	if time_of_day <= 0.5:
		# Sol se move de 0° (horizonte leste) até 180° (horizonte oeste)
		var sun_angle = time_of_day * 180.0
		sun_pivot.rotation_degrees.x = sun_angle
		
		# Nascer do sol (0.0 - 0.1)
		if time_of_day < 0.1:
			var t = time_of_day / 0.1
			color = sunrise_color.lerp(day_color, t)
			intensity = lerp(0.3, 1.0, t)
			sun.visible = true
		
		# Dia (0.1 - 0.4)
		elif time_of_day < 0.4:
			color = day_color
			intensity = 1.0
			sun.visible = true
		
		# Pôr do sol (0.4 - 0.5)
		else:
			var t = (time_of_day - 0.4) / 0.1
			color = day_color.lerp(sunset_color, t)
			intensity = lerp(1.0, 0.3, t)
			sun.visible = true
	
	# NOITE: time_of_day de 0.5 a 1.0 (sol invisível)
	else:
		# Desliga o sol durante a noite
		sun.visible = false
		# Mantém a rotação no horizonte oeste
		sun_pivot.rotation_degrees.x = 180.0
		color = night_color
		intensity = 0.0
	
	sun.light_color = color
	sun.light_energy = intensity

func update_sky():
	if not sky_material:
		return
	
	var sky_top = sky_day
	var sky_horizon = horizon_day
	var ground_bottom = Color(0.35, 0.3, 0.25)
	var ground_horizon = Color(0.45, 0.4, 0.35)
	
	# Nascer do sol (0.0 - 0.1)
	if time_of_day < 0.1:
		var t = time_of_day / 0.1
		sky_top = sky_sunrise.lerp(sky_day, t)
		sky_horizon = horizon_sunrise.lerp(horizon_day, t)
		ground_horizon = Color(0.6, 0.5, 0.4).lerp(Color(0.45, 0.4, 0.35), t)
	
	# Dia (0.1 - 0.4)
	elif time_of_day < 0.4:
		sky_top = sky_day
		sky_horizon = horizon_day
		ground_bottom = Color(0.35, 0.3, 0.25)
		ground_horizon = Color(0.45, 0.4, 0.35)
	
	# Pôr do sol (0.4 - 0.5)
	elif time_of_day < 0.5:
		var t = (time_of_day - 0.4) / 0.1
		sky_top = sky_day.lerp(sky_sunset, t)
		sky_horizon = horizon_day.lerp(horizon_sunset, t)
		ground_horizon = Color(0.45, 0.4, 0.35).lerp(Color(0.6, 0.4, 0.3), t)
	
	# Transição para noite (0.5 - 0.6)
	elif time_of_day < 0.6:
		var t = (time_of_day - 0.5) / 0.1
		sky_top = sky_sunset.lerp(sky_night, t)
		sky_horizon = horizon_sunset.lerp(horizon_night, t)
		ground_bottom = Color(0.35, 0.3, 0.25).lerp(Color(0.02, 0.02, 0.05), t)
		ground_horizon = Color(0.6, 0.4, 0.3).lerp(Color(0.05, 0.05, 0.15), t)
	
	# Noite (0.6 - 0.9)
	elif time_of_day < 0.9:
		sky_top = sky_night
		sky_horizon = horizon_night
		ground_bottom = Color(0.02, 0.02, 0.05)
		ground_horizon = Color(0.05, 0.05, 0.15)
	
	# Amanhecer (0.9 - 1.0)
	else:
		var t = (time_of_day - 0.9) / 0.1
		sky_top = sky_night.lerp(sky_sunrise, t)
		sky_horizon = horizon_night.lerp(horizon_sunrise, t)
		ground_bottom = Color(0.02, 0.02, 0.05).lerp(Color(0.35, 0.3, 0.25), t)
		ground_horizon = Color(0.05, 0.05, 0.15).lerp(Color(0.6, 0.5, 0.4), t)
	
	# Aplica as cores
	sky_material.sky_top_color = sky_top
	sky_material.sky_horizon_color = sky_horizon
	sky_material.ground_bottom_color = ground_bottom
	sky_material.ground_horizon_color = ground_horizon
	
	# Energia do céu
	if time_of_day < 0.1:
		sky_material.energy_multiplier = lerp(0.4, 1.0, time_of_day / 0.1)
	elif time_of_day < 0.4:
		sky_material.energy_multiplier = 1.0
	elif time_of_day < 0.5:
		sky_material.energy_multiplier = lerp(1.0, 0.4, (time_of_day - 0.4) / 0.1)
	elif time_of_day < 0.6:
		sky_material.energy_multiplier = lerp(0.4, 0.2, (time_of_day - 0.5) / 0.1)
	else:
		sky_material.energy_multiplier = 0.2

func set_cycle_duration(new_duration: float):
	cycle_duration = new_duration

func set_time_of_day(new_time: float):
	time_of_day = clamp(new_time, 0.0, 1.0)
	update_sun()
	update_sky()
