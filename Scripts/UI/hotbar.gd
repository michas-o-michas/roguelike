# hotbar.gd
# Hotbar de itens (slots 0-8 do inventário). Teclas 1-9 selecionam.
# Magias usam a hotbar separada (HotbarSpells) com spell_1..spell_9 (F1-F9 por padrão).

extends Control

@export var selected_slot: int = 0
## Imagem de fundo aplicada a todos os slots desta hotbar (opcional).
@export var slot_background_texture: Texture2D = null

var slot_nodes: Array = []

func _ready() -> void:
	var container = $Panel/SlotsContainer
	slot_nodes = container.get_children()
	if slot_background_texture:
		for slot in slot_nodes:
			if slot.has_method("set_slot_background"):
				slot.set_slot_background(slot_background_texture)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	if ToolSelectionManager:
		ToolSelectionManager.tool_changed.connect(_on_tool_changed)
	_update_hotbar_visibility()
	_update_selection_visual()
	await get_tree().process_frame
	_apply_hotbar_mode()

func _input(event: InputEvent) -> void:
	for i in range(min(9, slot_nodes.size())):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			select_slot(i)
			_update_selection_visual()
			break

func select_slot(index: int) -> void:
	selected_slot = index
	_update_selection_visual()

func _update_selection_visual() -> void:
	for i in range(slot_nodes.size()):
		var slot = slot_nodes[i]
		slot.modulate = Color(1.2, 1.1, 0.8, 1.0) if i == selected_slot else Color.WHITE

func _on_tool_changed(_active_slot: int) -> void:
	_update_hotbar_visibility()
	_apply_hotbar_mode()
	_update_selection_visual()

func _update_hotbar_visibility() -> void:
	# Com cajado equipado, mostra só a hotbar de magias; com outras armas, mostra esta (itens).
	if ToolSelectionManager:
		visible = ToolSelectionManager.active_tool_slot != Weapon.ToolSlot.STAFF

func _on_inventory_changed() -> void:
	_apply_hotbar_mode()
	_update_selection_visual()

func _apply_hotbar_mode() -> void:
	for i in range(slot_nodes.size()):
		var slot = slot_nodes[i]
		if slot.has_method("refresh_from_inventory"):
			slot.refresh_from_inventory()
