# SpellManager.gd
# Autoload — magias desbloqueadas e ordem na hotbar do cajado.
# 1–9 selecionam o slot; o disparo é feito pelo WeaponHandler no clique.
#
# Registrar em Project Settings > Autoload: SpellManager -> res://Scripts/SpellManager.gd

extends Node

signal selected_spell_slot_changed(slot: int)

# Magias desbloqueadas (recursos Spell). Ordem na hotbar = índice 0-8.
var unlocked_spells: Array[Spell] = []
# Para cada slot 0-8 da hotbar, índice em unlocked_spells (-1 = vazio). Permite reordenar.
var hotbar_order: Array[int] = []

var _selected_spell_slot: int = 0
var selected_spell_slot: int:
	get:
		return _selected_spell_slot
	set(v):
		v = clampi(v, 0, 8)
		if v == _selected_spell_slot:
			return
		_selected_spell_slot = v
		emit_signal("selected_spell_slot_changed", _selected_spell_slot)

const HOTBAR_SIZE: int = 9

func _ready() -> void:
	hotbar_order.resize(HOTBAR_SIZE)
	for i in range(HOTBAR_SIZE):
		hotbar_order[i] = -1
	# Por padrão, slot 0 mostra primeira magia se houver
	if unlocked_spells.size() > 0:
		hotbar_order[0] = 0

## Retorna a magia exibida no slot da hotbar [0-8]
func get_spell_at_slot(slot_index: int) -> Spell:
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		return null
	var idx: int = hotbar_order[slot_index]
	if idx < 0 or idx >= unlocked_spells.size():
		return null
	return unlocked_spells[idx]

## Retorna a magia atualmente selecionada (a que será disparada no clique)
func get_selected_spell() -> Spell:
	return get_spell_at_slot(selected_spell_slot)

## Define o slot selecionado (0-8)
func set_selected_slot(slot_index: int) -> void:
	selected_spell_slot = clampi(slot_index, 0, HOTBAR_SIZE - 1)

## Adiciona uma magia ao conjunto desbloqueado (e à hotbar se houver espaço)
func unlock_spell(spell: Spell) -> void:
	if spell == null or unlocked_spells.has(spell):
		return
	unlocked_spells.append(spell)
	for i in range(HOTBAR_SIZE):
		if hotbar_order[i] < 0:
			hotbar_order[i] = unlocked_spells.size() - 1
			break
