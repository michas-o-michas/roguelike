extends Control
## Barra de progresso do cooldown de ataque do jogador (embaixo na tela).
## Enche conforme o cooldown recarrega (1 = pronto para atacar).

@onready var progress_bar: ProgressBar = $VBox/CooldownBar
@onready var label: Label = $VBox/Label

var _weapon_handler: Node = null

func _ready() -> void:
	_setup_bar_style()
	call_deferred("_try_connect_weapon_handler")

func _setup_bar_style() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	bg.set_corner_radius_all(4)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.35, 0.35, 0.4)
	progress_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.25, 0.5, 0.85)
	fill.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.show_percentage = false
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 1.0

func _try_connect_weapon_handler() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		# Tenta pelo pai (UI pode ser filha do Player)
		var n: Node = self
		while n:
			if n.is_in_group("player"):
				player = n
				break
			n = n.get_parent()
	if not player:
		return
	_weapon_handler = player.get_node_or_null("WeaponHandler")
	if not _weapon_handler or not _weapon_handler.has_method("get_attack_cooldown_progress"):
		_weapon_handler = null

func _process(_delta: float) -> void:
	if _weapon_handler == null:
		_try_connect_weapon_handler()
		return
	var progress = _weapon_handler.get_attack_cooldown_progress()
	progress_bar.value = progress
	if label:
		label.text = "Ataque" if progress >= 0.99 else "Recarregando..."
