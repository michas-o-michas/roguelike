# inventory_ui_simple.gd (SIMPLIFICADO para UI manual)
# Attach no Control raiz da inventory_ui.tscn
#
# Estrutura esperada no editor:
#   Control (este script)
#   ├── ColorRect (name: "Overlay")
#   └── Panel (name: "Window")
#       ├── Button (name: "CloseButton")
#       ├── HBoxContainer (name: "Tabs")
#       │   ├── Button (name: "InventoryTab")
#       │   └── Button (name: "CraftingTab")
#       ├── Control (name: "InventoryContent")
#       │   ├── GridContainer (name: "InventoryGrid")
#       │   │   └── Panel x20 (inventory_slot.gd, slot_type=INVENTORY, slot_index=9-28)
#       │   └── VBoxContainer (name: "EquipmentPanel")
#       │       └── Panel x7 (inventory_slot.gd, slot_type=EQUIPMENT_*, slot_index separado)
#       └── Control (name: "CraftingContent", visible: false)

extends Control

@export var is_open: bool = false

@onready var window = $PanelContainer/Window
@onready var close_button = $PanelContainer/Window/Header/CloseButton
@onready var inv_tab = $PanelContainer/Window/TabsBar/Tabs/InventoryTab
@onready var craft_tab = $PanelContainer/Window/TabsBar/Tabs/CraftingTab
@onready var inv_content = $PanelContainer/Window/InventoryContent
@onready var craft_content = $PanelContainer/Window/MarginContainer/CraftingContent
@onready var coins_label = $PanelContainer/Window/Header/CoinsLabel

var current_tab: String = "inventory"

func _ready():
	visible = is_open
	z_index = 50 if is_open else 0
	_style_tabs()
	_style_close_button()
	close_button.pressed.connect(_toggle)
	inv_tab.pressed.connect(func(): _switch_tab("inventory"))
	craft_tab.pressed.connect(func(): _switch_tab("crafting"))
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	InventoryManager.coins_changed.connect(_on_coins_changed)
	_switch_tab("inventory")
	_on_coins_changed(InventoryManager.get_coins())
	
	_load_all_slots()
	await get_tree().process_frame
	_refresh_all_slots()

func _refresh_all_slots() -> void:
	# Atualiza todos os slots do inventário
	if inv_content and inv_content.has_node("InventoryGrid"):
		var grid = inv_content.get_node("InventoryGrid")
		for slot in grid.get_children():
			if slot.has_method("refresh_from_inventory"):
				slot.refresh_from_inventory()
	
	# Atualiza slots de equipamento
	if inv_content and inv_content.has_node("EquipmentPanel"):
		var equip = inv_content.get_node("EquipmentPanel")
		for slot in equip.get_children():
			if slot.has_method("refresh_from_inventory"):
				slot.refresh_from_inventory()

func _input(event):
	if event.is_action_pressed("ui_inventory"):
		_toggle()
	elif event.is_action_pressed("ui_cancel") and is_open:
		_toggle()


func _toggle() -> void:
	is_open = !is_open
	visible = is_open
	
	if is_open:
		# Garantir que o inventário fique por cima de SkillsHUD, Hotbar e outros irmãos
		z_index = 50
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		z_index = 0
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if current_tab != "inventory":
			_switch_tab("inventory")

	SoundManager.play("ui_inventory_open")

func _switch_tab(tab_id: String) -> void:
	current_tab = tab_id
	
	# Mostra/esconde conteúdo
	inv_content.visible = (tab_id == "inventory")
	craft_content.visible = (tab_id == "crafting")
	
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.28, 0.2, 0.12, 1)
	active_style.border_color = Color(0.65, 0.45, 0.25, 1)
	active_style.set_border_width_all(1)
	active_style.set_corner_radius_all(4)
	var inactive_style := StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.1, 0.08, 0.06, 1)
	inactive_style.border_color = Color(0.25, 0.2, 0.15, 1)
	inactive_style.set_border_width_all(1)
	inactive_style.set_corner_radius_all(4)
	if tab_id == "inventory":
		inv_tab.add_theme_stylebox_override("normal", active_style)
		craft_tab.add_theme_stylebox_override("normal", inactive_style)
		inv_tab.add_theme_color_override("font_color", Color(0.95, 0.88, 0.75, 1))
		craft_tab.add_theme_color_override("font_color", Color(0.6, 0.57, 0.52, 1))
	else:
		inv_tab.add_theme_stylebox_override("normal", inactive_style)
		craft_tab.add_theme_stylebox_override("normal", active_style)
		inv_tab.add_theme_color_override("font_color", Color(0.6, 0.57, 0.52, 1))
		craft_tab.add_theme_color_override("font_color", Color(0.95, 0.88, 0.75, 1))
	SoundManager.play("ui_inventory_select")


func _on_inventory_changed() -> void:
	# Atualiza visual de todos os slots
	_refresh_all_slots()

func _on_coins_changed(amount: int) -> void:
	if coins_label:
		coins_label.text = "🪙  %d" % amount
		coins_label.tooltip_text = "Moedas"

func _style_tabs() -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.08, 0.06, 1)
	normal_style.border_color = Color(0.25, 0.2, 0.15, 1)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(4)
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.18, 0.14, 0.1, 1)
	hover_style.border_color = Color(0.45, 0.35, 0.22, 1)
	for tab in [inv_tab, craft_tab]:
		if tab:
			tab.add_theme_stylebox_override("normal", normal_style.duplicate())
			tab.add_theme_stylebox_override("hover", hover_style.duplicate())
			var pressed_style := hover_style.duplicate()
			pressed_style.bg_color = Color(0.22, 0.17, 0.11, 1)
			tab.add_theme_stylebox_override("pressed", pressed_style)
			tab.add_theme_color_override("font_color", Color(0.75, 0.7, 0.65, 1))
			tab.add_theme_color_override("font_hover_color", Color(0.95, 0.9, 0.82, 1))

func _style_close_button() -> void:
	if not close_button:
		return
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.1, 0.08, 1)
	normal_style.border_color = Color(0.35, 0.25, 0.18, 1)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(4)
	close_button.add_theme_stylebox_override("normal", normal_style)
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.5, 0.2, 0.15, 1)
	hover_style.border_color = Color(0.7, 0.35, 0.25, 1)
	close_button.add_theme_stylebox_override("hover", hover_style)
	close_button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8, 1))
	close_button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.9, 1))

func _load_all_slots() -> void:
	# Carrega todos os slots do InventoryManager pra UI
	print("=== Carregando slots na UI ===")
	
	# Pega todos os Panels que são slots (tem inventory_slot.gd)
	var all_slots = _find_all_slots(self)
	
	for slot in all_slots:
		if slot.has_method("refresh_from_inventory"):
			slot.refresh_from_inventory()
			print("Slot ", slot.slot_index, " carregado")
	
	print("Total de slots carregados: ", all_slots.size())

func _find_all_slots(node: Node) -> Array:
	# Busca recursivamente todos os nós que são slots
	var result = []
	
	for child in node.get_children():
		# Se tem o método refresh_from_inventory, é um slot
		if child.has_method("refresh_from_inventory"):
			result.append(child)
		
		# Busca nos filhos também
		result.append_array(_find_all_slots(child))
	
	return result
