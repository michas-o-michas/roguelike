# inventory_slot.gd
# Attach em cada Panel de slot (inventário, hotbar, equipamento).
# Gerencia drag & drop, validação de tipo, e visual.
#
# Setup no Editor:
#   1. Cada Panel de slot tem este script
#   2. No Inspector, define o slot_type (inventory, hotbar, equipment_weapon, etc.)
#   3. Conecta os nós filhos: ItemIcon, AmountLabel (se tiver)

extends Panel

# ================= TIPOS DE SLOT =================
enum SlotType {
	INVENTORY,            # Aceita qualquer item
	HOTBAR,              # Aceita: as 4 armas (Weapon) ou consumíveis — uso rápido
	EQUIPMENT_WEAPON,    # Aceita qualquer Weapon (legado; preferir os 4 abaixo)
	EQUIPMENT_ARMOR,     # Aceita só: armaduras (futuro)
	EQUIPMENT_ACCESSORY, # Aceita só: acessórios (futuro)
	EQUIPMENT_MELEE,     # Só Weapon com equipment_slot == MELEE (Espada)
	EQUIPMENT_STAFF,     # Só Weapon com equipment_slot == STAFF (Cajado)
	EQUIPMENT_AXE,       # Só Weapon com equipment_slot == AXE (Machado)
	EQUIPMENT_PICKAXE    # Só Weapon com equipment_slot == PICKAXE (Picareta)
}

# ================= EXPORTS =================
@export var slot_type: SlotType = SlotType.INVENTORY
@export var slot_index: int = 0  # Índice deste slot no array do InventoryManager
## Imagem de fundo do slot. Se definida, sobrescreve a textura padrão da cena.
@export var slot_background: Texture2D = null

# ================= REFERÊNCIAS (assign no _ready ou manualmente) =================
@onready var item_icon: TextureRect = $PanelContainer/ItemIcon     # Mostra o ícone do item
@onready var amount_label: Label = $AmountLabel      # Mostra quantidade (se >1)
@onready var _bg_rect: TextureRect = $PanelContainer  # Retângulo que exibe o fundo do slot

# ================= ESTADO =================
var item_data: Dictionary = {}  # { "item": Item, "amount": int } ou vazio
var display_spell: Spell = null  # Quando não null, slot mostra magia (modo cajado)
var is_dragging: bool = false
var is_swapping: bool = false  # Flag pra prevenir refresh durante swap
var original_modulate: Color

# ================= CORES =================
var color_valid_drop: Color = Color(0.4, 0.8, 0.4, 0.3)    # Verde quando pode soltar
var color_invalid_drop: Color = Color(0.8, 0.4, 0.4, 0.3)  # Vermelho quando não pode

# ================= INICIALIZAÇÃO =================
func _ready():
	original_modulate = modulate
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # Mostra que é clicável
	if slot_background and _bg_rect:
		_bg_rect.texture = slot_background
	# Reseta cor quando mouse sai durante drag
	mouse_exited.connect(_on_mouse_exited)

## Define a imagem de fundo do slot (pode ser chamado pela hotbar ou em código).
func set_slot_background(texture: Texture2D) -> void:
	if _bg_rect:
		_bg_rect.texture = texture
	else:
		var rect = get_node_or_null("PanelContainer") as TextureRect
		if rect:
			rect.texture = texture

func _on_mouse_exited() -> void:
	# Só reseta se não tiver item sendo dropado neste frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	modulate = original_modulate

# ================= DRAG & DROP (GODOT NATIVO) =================

## Godot chama isso quando clica e arrasta
func _get_drag_data(_at_position: Vector2):
	print("_get_drag_data chamado! Item vazio? ", item_data.is_empty())
	
	if item_data.is_empty():
		return null
	
	print("Iniciando drag de: ", item_data["item"].item_name)
	
	# Cria preview visual
	var preview = Panel.new()
	preview.custom_minimum_size = size
	preview.z_index = 1
	preview.custom_minimum_size = Vector2(64,64)
	preview.set_anchors_preset(Control.PRESET_CENTER)
	
	# Copia estilo
	if get_theme_stylebox("panel"):
		preview.add_theme_stylebox_override("panel", get_theme_stylebox("panel").duplicate())
	
	# Copia ícone
	if item_icon and item_icon.texture:
		var icon = TextureRect.new()
		icon.texture = item_icon.texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = size * 0.8
		icon.z_index =1 
		preview.add_child(icon)
	
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	
	# Retorna os dados
	return {
		"item": item_data["item"],
		"amount": item_data.get("amount", 1),
		"source_slot": self
	}

## Godot chama isso pra verificar se pode dropar
func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not data is Dictionary or data.is_empty():
		modulate = original_modulate  # Reseta cor se dados inválidos
		return false
	
	var item: Item = data.get("item")
	if not item:
		modulate = original_modulate
		return false
	
	# Validação baseada no tipo de slot
	match slot_type:
		SlotType.INVENTORY:
			# Inventário aceita qualquer item
			modulate = color_valid_drop
			return true
		
		SlotType.HOTBAR:
			# Hotbar: só as 4 armas (Weapon) ou consumíveis
			if (item is Weapon) or item.type == Item.Type.CONSUMABLE:
				modulate = color_valid_drop
				return true
			modulate = color_invalid_drop
			return false
		
		SlotType.EQUIPMENT_WEAPON:
			if item is Weapon:
				modulate = color_valid_drop
				return true
			modulate = color_invalid_drop
			return false
		
		SlotType.EQUIPMENT_MELEE, SlotType.EQUIPMENT_STAFF, SlotType.EQUIPMENT_AXE, SlotType.EQUIPMENT_PICKAXE:
			if item is Weapon:
				var wanted: int = Weapon.ToolSlot.MELEE
				match slot_type:
					SlotType.EQUIPMENT_MELEE:   wanted = Weapon.ToolSlot.MELEE
					SlotType.EQUIPMENT_STAFF:   wanted = Weapon.ToolSlot.STAFF
					SlotType.EQUIPMENT_AXE:     wanted = Weapon.ToolSlot.AXE
					SlotType.EQUIPMENT_PICKAXE: wanted = Weapon.ToolSlot.PICKAXE
				if (item as Weapon).get_equipment_slot() == wanted:
					modulate = color_valid_drop
					return true
			modulate = color_invalid_drop
			return false
		
		SlotType.EQUIPMENT_ARMOR:
			# Slot de armadura aceita só armaduras
			# (precisa adicionar Type.ARMOR no item.gd)
			modulate = color_invalid_drop
			return false  # Implementar quando tiver armaduras
		
		SlotType.EQUIPMENT_ACCESSORY:
			# Slot de acessório aceita só acessórios
			modulate = color_invalid_drop
			return false  # Implementar quando tiver acessórios
	
	modulate = color_invalid_drop
	return false

## Godot chama isso quando solta o item
func _drop_data(_at_position: Vector2, data) -> void:
	modulate = original_modulate
	
	if not data is Dictionary:
		return
	
	var source_slot = data.get("source_slot")
	
	# Se dropou no mesmo slot, cancela
	if source_slot == self:
		return
	
	# Troca os itens entre os slots
	_swap_items(source_slot)

## Troca itens com outro slot
func _swap_items(other_slot: Panel) -> void:
	if not other_slot:
		return
	
	print("=== SWAP DEBUG ===")
	print("Source: index=%d, type=%d, item=%s" % [slot_index, slot_type, item_data.get("item").item_name if not item_data.is_empty() else "vazio"])
	print("Target: index=%d, type=%d, item=%s" % [other_slot.slot_index, other_slot.slot_type, other_slot.item_data.get("item").item_name if not other_slot.item_data.is_empty() else "vazio"])
	
	# Marca ambos slots como "em swap" pra não serem refreshados
	is_swapping = true
	other_slot.is_swapping = true
	
	# Guarda temporariamente os dados de ambos
	var temp_this = item_data.duplicate(true)
	var temp_other = other_slot.item_data.duplicate(true)
	
	# Atualiza visual dos dois slots
	set_item(temp_other)
	other_slot.set_item(temp_this)
	
	# Atualiza AMBOS no InventoryManager de uma vez
	if not temp_other.is_empty():
		InventoryManager.slots[slot_index] = temp_other.duplicate(true)
	else:
		InventoryManager.slots[slot_index] = null
	
	if not temp_this.is_empty():
		InventoryManager.slots[other_slot.slot_index] = temp_this.duplicate(true)
	else:
		InventoryManager.slots[other_slot.slot_index] = null
	
	# Desmarca flag
	is_swapping = false
	other_slot.is_swapping = false
	
	# Emite sinal UMA VEZ ao final
	InventoryManager.emit_signal("inventory_changed")

## Cancela drag quando sai do slot
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = original_modulate

# ================= VISUAL =================

## Define o item visual deste slot
func set_item(data: Dictionary) -> void:
	display_spell = null  # Limpa modo magia
	item_data = data
	
	if data.is_empty():
		if item_icon:
			item_icon.texture = null
		if amount_label:
			amount_label.visible = false
	else:
		var item: Item = data["item"]
		var amount: int = data.get("amount", 1)
		if item_icon and item.item_icon:
			item_icon.texture = item.item_icon
		if amount_label:
			if amount > 1:
				amount_label.text = str(amount)
				amount_label.visible = true
			else:
				amount_label.visible = false

## Mostra uma magia neste slot (modo cajado). Passar null para limpar.
func set_display_spell(spell: Spell) -> void:
	display_spell = spell
	if item_icon:
		item_icon.texture = spell.icon if spell and spell.icon else null
	if amount_label:
		amount_label.visible = false

## Retorna o item atual
func get_item() -> Dictionary:
	return item_data

# ================= SINCRONIZAÇÃO COM INVENTORYMANAGER =================

func _update_inventory_manager() -> void:
	# Atualiza o InventoryManager com o novo estado deste slot
	
	# Valida índice
	if slot_index < 0 or slot_index >= InventoryManager.slots.size():
		push_error("Slot index fora do range! Index: %d, Max: %d" % [slot_index, InventoryManager.slots.size()])
		return
	
	# Atualiza o slot no array (funciona pra todos os tipos)
	if not item_data.is_empty():
		InventoryManager.slots[slot_index] = item_data.duplicate(true)
	else:
		InventoryManager.slots[slot_index] = null
	
	InventoryManager.emit_signal("inventory_changed")

## Atualiza o visual baseado no InventoryManager (chamado quando inventário muda)
func refresh_from_inventory() -> void:
	if is_swapping:
		return
	display_spell = null
	var data = InventoryManager.get_slot(slot_index)
	set_item(data if not data.is_empty() else {})
