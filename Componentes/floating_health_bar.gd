extends Control
class_name FloatingHealthBar

# ========================================
# PROPRIEDADES
# ========================================
@export var target_node: Node3D
@export var health_component: HealthComponent
@export var bar_width: int = 100
@export var bar_height: int = 15
@export var bar_offset: Vector2 = Vector2(0, -50)
@export var show_always: bool = false
@export var hide_when_full: bool = true

# ========================================
# NÓS
# ========================================
@onready var background: Panel = $Background
@onready var health_bar: ColorRect = $HealthBar
@onready var damage_bar: ColorRect = $DamageBar  # Barra de dano que segue atrás

# ========================================
# VARIÁVEIS
# ========================================
var is_visible: bool = true
var max_health: float = 100.0
var current_health: float = 100.0
var damage_health: float = 100.0  # Para efeito de dano gradual

# ========================================
# INICIALIZAÇÃO
# ========================================
func _ready():
	custom_minimum_size = Vector2(bar_width, bar_height)
	background.custom_minimum_size = Vector2(bar_width, bar_height)
	
	if not target_node and get_parent() is CanvasLayer:
		# Tentar encontrar o target por outros meios
		pass
	
	set_process(false)
	hide()

func _process(_delta):
	if target_node and is_instance_valid(target_node):
		update_position()
		
		# Esconder se saúde cheia e configurado para isso
		if hide_when_full and current_health >= max_health:
			hide()
			is_visible = false
			set_process(false)

# ========================================
# MÉTODOS PÚBLICOS
# ========================================
func set_target(new_target: Node3D):
	"""
	Define o nó alvo que a barra de vida seguirá.
	"""
	target_node = new_target
	
	if target_node and is_instance_valid(target_node):
		# Procurar HealthComponent no alvo
		for child in target_node.get_children():
			if child is HealthComponent:
				health_component = child
				health_component.health_changed.connect(_on_health_changed)
				max_health = health_component.max_health
				current_health = health_component.current_health
				damage_health = current_health
				break
		
		update_position()
		set_process(true)
		show()

func update_health(current: float, max_hp: float):
	"""
	Atualiza os valores da barra de vida.
	"""
	max_health = max_hp
	current_health = current
	
	# Atualizar barra principal imediatamente
	var health_percentage = current_health / max_health
	health_bar.size.x = bar_width * health_percentage
	
	# Efeito de dano gradual
	if damage_bar:
		var damage_tween = create_tween()
		damage_tween.tween_property(damage_bar, "size:x", 
			bar_width * health_percentage, 0.5).set_trans(Tween.TRANS_CUBIC)
	
	# Mostrar/ocultar
	if not is_visible and (not hide_when_full or current_health < max_health):
		show()
		is_visible = true
		set_process(true)

func update_position():
	"""
	Atualiza a posição da barra para seguir o alvo.
	"""
	if not target_node or not is_instance_valid(target_node):
		return
	
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	# Converter posição 3D para 2D
	var screen_pos = camera.unproject_position(target_node.global_position)
	
	# Aplicar offset
	screen_pos += bar_offset
	
	# Centralizar
	screen_pos.x -= bar_width / 2
	
	position = screen_pos

# ========================================
# CONEXÕES
# ========================================
func _on_health_changed(old_value: float, new_value: float):
	update_health(new_value, max_health)

func _on_visibility_changed():
	if not visible:
		set_process(false)
