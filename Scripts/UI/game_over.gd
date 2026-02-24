extends Control
## Tela de game over / permadeath.
## Chamada por Player._show_game_over(days, coins).
## Corrige o mouse (libera ao mostrar, captura ao reiniciar).

@onready var _bg:          ColorRect     = $BG
@onready var _card:        PanelContainer = $Center/Card
@onready var _title:       Label          = $Center/Card/Margin/VBox/Title
@onready var _subtitle:    Label          = $Center/Card/Margin/VBox/Subtitle
@onready var _days_label:  Label          = $Center/Card/Margin/VBox/DaysLabel
@onready var _coins_label: Label          = $Center/Card/Margin/VBox/CoinsLabel
@onready var _menu_btn:    Button         = $Center/Card/Margin/VBox/MenuBtn

var _tween: Tween


func _ready() -> void:
	_menu_btn.pressed.connect(_on_menu)
	_apply_styles()


## Exibe a tela com fade in. Chame com dias sobrevividos e moedas acumuladas.
func show_game_over(days: int, coins: int) -> void:
	var day_text := "dia" if days == 1 else "dias"
	_days_label.text = "⏳  %d %s sobrevivido" % [days, day_text]
	_coins_label.text = "🪙  %d moedas acumuladas" % coins
	_subtitle.text = _pick_subtitle(days)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show()
	_fade_in()


func _fade_in() -> void:
	_bg.color = Color(0, 0, 0, 0)
	_card.modulate.a = 0.0
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_bg, "color", Color(0, 0, 0, 0.93), 0.6)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.5).set_delay(0.15)


func _pick_subtitle(days: int) -> String:
	if days <= 1:
		return "Mal começou..."
	elif days <= 3:
		return "Boa tentativa."
	elif days <= 7:
		return "Você foi longe!"
	else:
		return "Uma lenda caiu."


func _on_restart() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if StatsManager:
		StatsManager.reset_all()
	if InventoryManager:
		InventoryManager.reset_for_new_run()
	get_tree().reload_current_scene()


func _on_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	hide()


# ─── Estilos ──────────────────────────────────────────────────────────────────

func _apply_styles() -> void:
	# Card (painel central)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color       = Color(0.055, 0.025, 0.025)
	card_style.border_color   = Color(0.55, 0.07, 0.07)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card_style.content_margin_left   = 40
	card_style.content_margin_right  = 40
	card_style.content_margin_top    = 38
	card_style.content_margin_bottom = 38
	_card.add_theme_stylebox_override("panel", card_style)

	# VBox separation
	var vbox := _card.get_node("Margin/VBox") as VBoxContainer
	vbox.add_theme_constant_override("separation", 14)

	# Título
	_title.add_theme_font_size_override("font_size", 58)
	_title.add_theme_color_override("font_color", Color(0.88, 0.1, 0.1))
	_title.add_theme_color_override("font_shadow_color", Color(0.4, 0.0, 0.0, 0.9))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 3)

	# Subtítulo
	_subtitle.add_theme_font_size_override("font_size", 17)
	_subtitle.add_theme_color_override("font_color", Color(0.55, 0.42, 0.42))

	# Separadores
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.4, 0.08, 0.08, 0.7)
	sep_style.content_margin_top    = 1
	sep_style.content_margin_bottom = 1
	for sep_name: String in ["Sep1", "Sep2"]:
		var sep := vbox.get_node(sep_name) as HSeparator
		sep.add_theme_stylebox_override("separator", sep_style)

	# Labels de stats
	for lbl: Label in [_days_label, _coins_label]:
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.82, 0.5))


	# Botão secundário (Menu) — cinza escuro
	_style_btn(
		_menu_btn,
		Color(0.14, 0.14, 0.17),
		Color(0.22, 0.22, 0.27),
		Color(0.09, 0.09, 0.12),
		18
	)


func _style_btn(btn: Button, normal: Color, hover: Color, pressed: Color, font_size: int) -> void:
	var mk := func(col: Color, margin_v: int = 14) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = col
		s.set_corner_radius_all(7)
		s.content_margin_top    = margin_v
		s.content_margin_bottom = margin_v
		s.content_margin_left   = 20
		s.content_margin_right  = 20
		return s
