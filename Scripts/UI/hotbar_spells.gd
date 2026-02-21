# hotbar_spells.gd
# Hotbar exclusiva para magias. Usa ações spell_1..spell_9 (remapeáveis em Project Settings).
# Os slots têm os mesmos índices 0-8 do SpellManager; você pode trocar o fundo do Panel e dos slots no editor.

extends Control

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
	if SpellManager:
		SpellManager.selected_spell_slot_changed.connect(_on_selected_slot_changed)
	if ToolSelectionManager:
		ToolSelectionManager.tool_changed.connect(_on_tool_changed)
	_update_hotbar_visibility()
	_refresh_spell_slots()
	_update_selection_visual()

func _input(event: InputEvent) -> void:
	for i in range(min(9, slot_nodes.size())):
		if event.is_action_pressed("spell_%d" % (i + 1)):
			if SpellManager:
				SpellManager.set_selected_slot(i)
			_update_selection_visual()
			break

func _on_selected_slot_changed(_slot: int) -> void:
	_update_selection_visual()

func _on_tool_changed(_active_slot: int) -> void:
	_update_hotbar_visibility()

func _update_hotbar_visibility() -> void:
	# Só mostra a hotbar de magias quando o cajado está equipado (Q para trocar).
	if ToolSelectionManager:
		visible = ToolSelectionManager.active_tool_slot == Weapon.ToolSlot.STAFF

## Chame quando desbloquear magias em tempo de execução para atualizar os ícones.
func refresh_spells() -> void:
	_refresh_spell_slots()

func _refresh_spell_slots() -> void:
	if not SpellManager:
		return
	for i in range(slot_nodes.size()):
		var slot = slot_nodes[i]
		if slot.has_method("set_display_spell"):
			slot.set_display_spell(SpellManager.get_spell_at_slot(i))

func _update_selection_visual() -> void:
	var highlight_idx: int = SpellManager.selected_spell_slot if SpellManager else 0
	for i in range(slot_nodes.size()):
		var slot = slot_nodes[i]
		slot.modulate = Color(1.2, 1.1, 0.8, 1.0) if i == highlight_idx else Color.WHITE
