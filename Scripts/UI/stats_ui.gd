# stats_ui.gd
# Anexar ao Control do conteúdo da aba "Status" (StatusContent).
# Mostra pontos disponíveis, botão comprar com moedas, e lista de atributos com botão [+].

extends Control

var points_label: Label
var buy_point_btn: Button
var stats_list: VBoxContainer

var _stat_buttons: Dictionary = {}   # Stat -> Button
var _value_labels: Dictionary = {}  # Stat -> Label

func _ready() -> void:
	if not StatsManager:
		return
	_ensure_layout()
	_build_stat_rows()
	_update_points_display()
	StatsManager.points_changed.connect(_on_points_changed)
	StatsManager.stats_changed.connect(_on_stats_changed)
	if InventoryManager:
		InventoryManager.coins_changed.connect(func(_new_amount: int) -> void: _update_points_display())
	if buy_point_btn:
		buy_point_btn.pressed.connect(_on_buy_point_pressed)
		buy_point_btn.tooltip_text = "Custa %d moedas" % StatsManager.coins_per_point

## Cria TopRow, ScrollContainer e StatsList se não existirem (permite cena mínima)
func _ensure_layout() -> void:
	if has_node("VBox/TopRow"):
		points_label = $VBox/TopRow/PointsLabel
		buy_point_btn = $VBox/TopRow/BuyPointButton
	if has_node("VBox/ScrollContainer/StatsList"):
		stats_list = $VBox/ScrollContainer/StatsList
		return
	# Layout: VBox empilha linha de pontos + lista de atributos
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	add_child(vbox)
	var top := HBoxContainer.new()
	top.name = "TopRow"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pl := Label.new()
	pl.name = "PointsLabel"
	pl.text = "Pontos disponíveis: 0"
	top.add_child(pl)
	var bp := Button.new()
	bp.name = "BuyPointButton"
	bp.text = "Comprar ponto (50 🪙)"
	top.add_child(bp)
	vbox.add_child(top)
	points_label = pl
	buy_point_btn = bp
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 200
	var list := VBoxContainer.new()
	list.name = "StatsList"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	vbox.add_child(scroll)
	stats_list = list

func _build_stat_rows() -> void:
	if not stats_list:
		return
	for stat in StatsManager.Stat.values():
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 36
		# Nome
		var name_lbl := Label.new()
		name_lbl.name = "Label_" + StatsManager.STAT_NAMES[stat]
		name_lbl.text = StatsManager.STAT_NAMES[stat]
		name_lbl.custom_minimum_size.x = 140
		name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_lbl)
		# Valor (nível / bônus)
		var value_lbl := Label.new()
		value_lbl.name = "Value_" + str(stat)
		value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_lbl)
		_value_labels[stat] = value_lbl
		# Botão +
		var add_btn := Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size.x = 36
		add_btn.pressed.connect(_make_add_callback(stat))
		row.add_child(add_btn)
		_stat_buttons[stat] = add_btn
		stats_list.add_child(row)
		_update_stat_row(stat, value_lbl)

func _make_add_callback(stat: int) -> Callable:
	return func() -> void: _on_add_stat_pressed(stat)

func _on_add_stat_pressed(stat: int) -> void:
	if not StatsManager:
		return
	if StatsManager.points_available > 0:
		StatsManager.spend_point_on_stat(stat)
		SoundManager.play("ui_inventory_select")
	else:
		# Opção: comprar com moedas e já gastar neste stat
		if StatsManager.buy_point_with_coins(stat):
			SoundManager.play("new_coin")
		# Se não tiver moedas, não faz nada (poderia mostrar tooltip)

func _on_buy_point_pressed() -> void:
	if StatsManager and StatsManager.buy_point():
		SoundManager.play("new_coin")

func _on_points_changed(_p: int) -> void:
	_update_points_display()

func _on_stats_changed() -> void:
	_update_points_display()
	_update_all_stat_rows()
	_apply_to_player()

func _apply_to_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player and StatsManager:
		StatsManager.apply_to_player(player)

func _update_points_display() -> void:
	if not StatsManager:
		return
	if points_label:
		points_label.text = "Pontos disponíveis: %d" % StatsManager.get_points_available()
	if buy_point_btn:
		buy_point_btn.text = "Comprar ponto (%d 🪙)" % StatsManager.coins_per_point
		buy_point_btn.disabled = not InventoryManager or InventoryManager.get_coins() < StatsManager.coins_per_point
	var can_add: bool = StatsManager.get_points_available() > 0 or (InventoryManager != null and InventoryManager.get_coins() >= StatsManager.coins_per_point)
	for stat in _stat_buttons:
		var btn: Button = _stat_buttons[stat]
		if btn:
			btn.disabled = !can_add

func _update_stat_row(stat: int, value_lbl: Label) -> void:
	if not value_lbl or not StatsManager:
		return
	var lvl: int = StatsManager.get_stat_level(stat)
	var bonus: float = StatsManager.get_stat_bonus(stat)
	value_lbl.text = "Nível %d  (+%s)" % [lvl, _format_bonus(bonus)]

func _format_bonus(val: float) -> String:
	if int(val) == val:
		return str(int(val))
	return "%.1f" % val

func _update_all_stat_rows() -> void:
	for stat in _value_labels:
		_update_stat_row(stat, _value_labels[stat])
