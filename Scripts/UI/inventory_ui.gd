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
@onready var inv_tab = $PanelContainer/Window/Tabs/InventoryTab
@onready var craft_tab = $PanelContainer/Window/Tabs/CraftingTab
@onready var inv_content = $PanelContainer/Window/InventoryContent
@onready var craft_content = $PanelContainer/Window/MarginContainer/CraftingContent
@onready var coins_label = $PanelContainer/Window/Header/CoinsLabel  # Ajuste o caminho

var current_tab: String = "inventory"

func _ready():
	visible = is_open
	z_index = 50 if is_open else 0
	
	# Conecta botões
	close_button.pressed.connect(_toggle)
	inv_tab.pressed.connect(func(): _switch_tab("inventory"))
	craft_tab.pressed.connect(func(): _switch_tab("crafting"))
	
	# Conecta sinais do InventoryManager
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	InventoryManager.coins_changed.connect(_on_coins_changed)
	
	# Inicializa tabs
	_switch_tab("inventory")
	_on_coins_changed(InventoryManager.get_coins())
	
	# IMPORTANTE: Carrega itens do InventoryManager nos slots visuais
	_load_all_slots()
	
	# Atualiza visual inicial dos slots
	await get_tree().process_frame  # Espera 1 frame pra garantir que slots existem
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

func _switch_tab(tab_id: String) -> void:
	current_tab = tab_id
	
	# Mostra/esconde conteúdo
	inv_content.visible = (tab_id == "inventory")
	craft_content.visible = (tab_id == "crafting")
	
	# Atualiza cor das tabs (dourado = ativa, cinza = inativa)
	if tab_id == "inventory":
		inv_tab.modulate = Color(1.2, 1.1, 0.7)
		craft_tab.modulate = Color(0.6, 0.6, 0.6)
	else:
		inv_tab.modulate = Color(0.6, 0.6, 0.6)
		craft_tab.modulate = Color(1.2, 1.1, 0.7)

func _on_inventory_changed() -> void:
	# Atualiza visual de todos os slots
	_refresh_all_slots()

func _on_coins_changed(amount: int) -> void:
	if coins_label:
		coins_label.text = "Moedas: %d" % amount

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
