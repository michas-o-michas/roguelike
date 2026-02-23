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

## Cores customizáveis na cena (borda do painel, fundo e barra de vida).
@export var border_color: Color = Color(0.93, 0.79, 0, 1)
@export var bg_color: Color = Color(0, 0, 0, 0.59)
@export var fill_color: Color = Color(0.22, 0.52, 0.28, 1)
@export var damage_color: Color = Color(0.59, 0, 0, 1)

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
## Atualizar posição só a cada N frames (reduz custo com muitos inimigos).
const POSITION_UPDATE_INTERVAL := 2
## Largura total da barra (para centralizar na tela). Tamanho do fill/back vem da cena.
var _inner_width: int = 0
var _inner_height: int = 0

# ========================================
# INICIALIZAÇÃO
# ========================================
func _ready():
	# Usa o tamanho definido na cena; não altera size/offset dos nós em runtime
	_inner_width = int(health_bar.size.x)
	_inner_height = int(health_bar.size.y)
	_apply_colors()
	if not target_node and get_parent() is CanvasLayer:
		pass
	set_process(false)
	hide()

func _apply_colors() -> void:
	# Borda e fundo: StyleBoxFlat do Panel
	var style = background.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style = style.duplicate()
		style.border_color = border_color
		style.bg_color = bg_color
		style.draw_center = true
		background.add_theme_stylebox_override("panel", style)
	health_bar.color = fill_color
	damage_bar.color = damage_color

func _process(_delta):
	if not target_node or not is_instance_valid(target_node):
		return
	# Atualiza posição só a cada N frames para reduzir custo com muitos inimigos
	if Engine.get_process_frames() % POSITION_UPDATE_INTERVAL != 0:
		return
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	if target_node.global_position.distance_squared_to(camera.global_position) > 2500.0:
		# Longe da câmera (~50m): esconde a barra para não ficar travada na tela
		hide()
		is_visible = false
		set_process(false)
		return
	update_position()
	# Esconder se saúde cheia e configurado para isso
	if hide_when_full and current_health >= max_health:
		hide()
		is_visible = false
		set_process(false)

# ========================================
# MÉTODOS PÚBLICOS
# ========================================
func set_colors(p_border: Color, p_bg: Color, p_fill: Color, p_damage: Color) -> void:
	"""Define as cores da barra (borda, fundo, vida, dano). Use para customizar por mob."""
	border_color = p_border
	bg_color = p_bg
	fill_color = p_fill
	damage_color = p_damage
	_apply_colors()

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
		if _inner_width <= 0:
			_inner_width = int(health_bar.size.x)
			_inner_height = int(health_bar.size.y)
		var pct := clampf(current_health / max_health, 0.0, 1.0)
		health_bar.size.x = _inner_width * pct
		damage_bar.size.x = _inner_width * pct
		update_position()
		# Só mostrar e atualizar se não for “esconder quando cheio” ou se já está machucado (menos barras ativas = mais performance)
		if not hide_when_full or current_health < max_health:
			set_process(true)
			show()
			is_visible = true
		else:
			hide()
			is_visible = false

func update_health(current: float, max_hp: float):
	"""
	Atualiza os valores da barra de vida.
	"""
	max_health = max_hp
	current_health = current
	if _inner_width <= 0:
		_inner_width = int(health_bar.size.x)
		_inner_height = int(health_bar.size.y)
	var health_percentage := current_health / max_health
	health_percentage = clampf(health_percentage, 0.0, 1.0)
	# Barra verde (vida atual): largura = porcentagem da largura interna
	health_bar.size.x = _inner_width * health_percentage
	# Barra vermelha (atraso): tween para o mesmo valor (fica ATRÁS da verde no desenho)
	if damage_bar:
		var tween = create_tween()
		tween.tween_property(damage_bar, "size:x", _inner_width * health_percentage, 0.4).set_trans(Tween.TRANS_CUBIC)
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
	
	# Posição em mundo: usar get_bar_world_position() se o alvo tiver (ex.: ResourceNode.raycast_position)
	var world_pos: Vector3 = target_node.global_position
	if target_node.has_method("get_bar_world_position"):
		world_pos = target_node.get_bar_world_position()
	var screen_pos = camera.unproject_position(world_pos)
	
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
