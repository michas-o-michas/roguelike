extends Node3D
class_name EnemyHealthBar

@export var health_component: HealthComponent
@export var offset: Vector3 = Vector3(0, 2, 0)

@onready var fill: Sprite3D = $Fill

func _ready():
	if not health_component:
		print("EnemyHealthBar: Nenhum HealthComponent configurado!")
		return

	# Conectar sinais
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

	# Atualizar valor inicial
	_update_fill(health_component.current_health)

func _process(_delta):
	if not health_component:
		return

	# Seguir o inimigo
	var parent = get_parent()
	if parent:
		global_position = parent.global_position + offset



func _on_health_changed(_old_value: float, new_value: float):
	_update_fill(new_value)

func _update_fill(current_health: float):
	var percent = current_health / health_component.max_health
	percent = clamp(percent, 0, 1)

	# Escalar a parte verde
	fill.scale.x = percent

func _on_died():
	hide()
