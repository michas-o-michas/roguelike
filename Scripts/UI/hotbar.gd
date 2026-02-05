# hotbar.gd (SIMPLIFICADO para UI manual)
# Attach no Control raiz da hotbar.tscn
#
# Estrutura esperada no editor:
#   Control (este script)
#   └── HBoxContainer (name: "SlotsContainer")
#       └── Panel x9 (cada um com inventory_slot.gd, slot_type = HOTBAR, slot_index = 0-8)

extends Control

@export var selected_slot: int = 0

var slot_nodes: Array = []

func _ready():
	# Pega todos os slots filhos do container
	var container = $Panel/SlotsContainer
	slot_nodes = container.get_children()
	
	# Conecta ao InventoryManager
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	
	_update_selection_visual()
	
	# Atualiza visual inicial
	await get_tree().process_frame
	_on_inventory_changed()

func _input(event):
	# Teclas 1-9 pra trocar slot
	for i in range(min(9, slot_nodes.size())):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			select_slot(i)
			break

func select_slot(index: int) -> void:
	selected_slot = index
	_update_selection_visual()
	_equip_item_from_slot(index)

func _update_selection_visual() -> void:
	# Destaca o slot selecionado visualmente
	for i in range(slot_nodes.size()):
		var slot = slot_nodes[i]
		if i == selected_slot:
			# Borda dourada no slot selecionado
			slot.modulate = Color(1.2, 1.1, 0.8, 1.0)
		else:
			slot.modulate = Color.WHITE

func _equip_item_from_slot(index: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_node("WeaponHandler"):
		return
	
	var slot_data = InventoryManager.get_slot(index)
	
	if not slot_data.is_empty() and slot_data["item"] is Weapon:
		player.get_node("WeaponHandler").equip(slot_data["item"])
	else:
		player.get_node("WeaponHandler").unequip()

func _on_inventory_changed() -> void:
	# Atualiza todos os slots quando inventário muda
	for i in range(slot_nodes.size()):
		if slot_nodes[i].has_method("refresh_from_inventory"):
			slot_nodes[i].refresh_from_inventory()
