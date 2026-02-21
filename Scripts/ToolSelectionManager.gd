# ToolSelectionManager.gd
# Autoload — gerencia qual das 4 ferramentas está ativa: Espada (MELEE), Cajado (STAFF), Machado (AXE), Picareta (PICKAXE).
# Q alterna entre espada e cajado. E em recurso (árvore/pedra) auto-seleciona machado ou picareta.
#
# Registrar em Project Settings > Autoload:
#   Name: ToolSelectionManager
#   Path: res://Scripts/ToolSelectionManager.gd

extends Node

# ================= SINAIS =================
signal tool_changed(active_slot: int)  # Weapon.ToolSlot: MELEE=0, STAFF=1, AXE=2, PICKAXE=3

# ================= ESTADO =================
var active_tool_slot: int = Weapon.ToolSlot.MELEE  # Uma das 4: Espada, Cajado, Machado, Picareta

# ================= INICIALIZAÇÃO =================
func _ready() -> void:
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
	call_deferred("_apply_tool_to_weapon_handler")

func _on_inventory_changed() -> void:
	_apply_tool_to_weapon_handler()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_weapon"):
		_toggle_melee_staff()

# ================= PÚBLICO =================

## Alterna entre MELEE e STAFF (espada ↔ cajado)
func _toggle_melee_staff() -> void:
	if active_tool_slot == Weapon.ToolSlot.MELEE:
		set_active_tool(Weapon.ToolSlot.STAFF)
	else:
		set_active_tool(Weapon.ToolSlot.MELEE)

## Define a ferramenta ativa (MELEE, STAFF, AXE, PICKAXE). Usado por Q e por E em recurso (Fase 3).
func set_active_tool(slot: int) -> void:
	if slot == active_tool_slot:
		return
	active_tool_slot = slot
	emit_signal("tool_changed", active_tool_slot)
	_apply_tool_to_weapon_handler()

## Retorna a arma equipada no slot ativo (do InventoryManager)
func get_active_weapon() -> Weapon:
	if not InventoryManager:
		return null
	return InventoryManager.get_equipped_weapon(active_tool_slot)

# ================= INTERNO =================

func _apply_tool_to_weapon_handler() -> void:
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if not player or not player.has_node("WeaponHandler"):
		return
	var wh = player.get_node("WeaponHandler") as Node
	if not wh or not wh.has_method("equip"):
		return
	var w: Weapon = get_active_weapon()
	if w:
		wh.equip(w)
	else:
		wh.unequip()
