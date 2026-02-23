extends Control
## Barra de vida do jogador no canto superior esquerdo (estilo horizontal, vermelha, texto current/max).
## Obtém o player pelo grupo "player" e o HealthComponent; atualiza ao sinal health_changed.

@onready var health_label: Label = $VBox/HealthLabel
@onready var progress_bar: ProgressBar = $VBox/HealthBar

var _health_component: HealthComponent = null

func _ready() -> void:
	_setup_bar_style()
	call_deferred("_try_connect_player")

func _setup_bar_style() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.14, 0.85)
	bg.set_corner_radius_all(6)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.25, 0.25, 0.3)
	progress_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.2, 0.15)
	fill.set_corner_radius_all(5)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.show_percentage = false

func _try_connect_player() -> void:
	# Preferir o player que é dono desta UI (barra é filha de UI que é filha do Player)
	var player: Node = self
	while player:
		if player.has_method("get_health_component"):
			break
		player = player.get_parent()
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("get_health_component"):
		return
	_health_component = player.get_health_component()
	if not _health_component:
		return
	_health_component.health_changed.connect(_on_health_changed)
	_update_display(_health_component.current_health, _health_component.max_health)

func _on_health_changed(_old: float, _new: float) -> void:
	if _health_component:
		_update_display(_health_component.current_health, _health_component.max_health)

func _update_display(current: float, maximum: float) -> void:
	progress_bar.min_value = 0
	progress_bar.max_value = maximum
	progress_bar.value = current
	health_label.text = "%d/%d" % [int(current), int(maximum)]
