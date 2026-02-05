# inventory_manager.gd
# Autoload/Singleton — gerencia todo o inventário do player.
#
# Como registrar no Godot:
#   Scene > Project > Project Settings > Autoload
#   Name: InventoryManager
#   Path: res://scripts/inventory_manager.gd
#
# Como usar em outros scripts:
#   InventoryManager.add_item(item_resource, quantidade)
#   InventoryManager.remove_item(item_resource, quantidade)
#   InventoryManager.get_coins()
#   InventoryManager.spend_coins(quantidade)

extends Node

# ================= SINAIS =================
signal inventory_changed         # Emitido toda vez que o inventário muda (atualiza UI)
signal coins_changed(new_amount) # Emitido quando moedas mudam

# ================= CONFIGURAÇÃO =================
@export var max_slots: int = 110         # Hotbar (0-8) + Inventário (9-28) + Equipment (100-106)

# ================= ESTRUTURA INTERNA =================
# Cada slot é um dicionário: { "item": Item (resource), "amount": int }
# Se o slot estiver vazio, fica como null.
var slots: Array = []
var coins: int = 0

## Inicializa moedas (chamado pelo Player no _ready)
func init_coins(amount: int) -> void:
	coins = amount
	emit_signal("coins_changed", coins)

# ================= INICIALIZAÇÃO =================
func _ready():
	# FORÇA o resize mesmo que já tenha valor anterior
	slots.clear()
	slots.resize(max_slots)
	print("InventoryManager inicializado com ", max_slots, " slots")
	
	# --- ITENS DE TESTE (remova depois) ---
	print("=== Adicionando itens de teste ao inventário ===")
	const WOOD = preload("res://items/wood.tres")
	slots[13] = { "item": WOOD, "amount": 30 }

	const stone = preload("res://items/stone.tres")
	slots[11] = { "item": stone, "amount": 30 }

	const WOOD_SWORD = preload("uid://dty3m422lyon1")
	
	slots[12] = { "item": WOOD_SWORD, "amount": 1 }
	print("Espada adicionada no slot 12")
	
	print("Total de slots ocupados: ", _count_occupied_slots())
	
	# Debug: mostra conteúdo dos slots
	for i in range(15):
		var slot = slots[i]
		if slot != null:
			print("  Slot ", i, ": ", slot["item"].item_name, " x", slot["amount"])
	
	emit_signal("inventory_changed")
	print("===========================================")



func _count_occupied_slots() -> int:
	var count = 0
	for slot in slots:
		if slot != null:
			count += 1
	return count

# ================= MOEDAS =================

## Retorna a quantidade atual de moedas
func get_coins() -> int:
	return coins

## Adiciona moedas
func add_coins(amount: int) -> void:
	coins += amount
	emit_signal("coins_changed", coins)

## Tenta gastar moedas — retorna true se teve saldo suficiente
func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		emit_signal("coins_changed", coins)
		return true
	return false

# ================= ADICIONAR ITENS =================

## Adiciona um item ao inventário
## Retorna true se foi bem-sucedido, false se o inventário estiver cheio
func add_item(item: Item, amount: int = 1) -> bool:
	# Se for moeda, direta para a variável de coins
	if item.type == Item.Type.CURRENCY:
		add_coins(amount)
		return true

	# Se o item empilha, tenta completar um slot existente primeiro
	if item.is_stackable():
		for i in range(max_slots):
			var slot = slots[i]
			if slot != null and slot["item"].resource_path == item.resource_path:
				var space = item.max_stack - slot["amount"]
				if space > 0:
					var to_add = min(amount, space)
					slot["amount"] += to_add
					amount -= to_add
					emit_signal("inventory_changed")
					if amount <= 0:
						return true

	# Se ainda tem quantidade pra colocar, procura slot vazio
	while amount > 0:
		var empty_slot = _get_first_empty_slot()
		if empty_slot == -1:
			emit_signal("inventory_changed")
			return false  # Inventário cheio

		if item.is_stackable():
			var to_add = min(amount, item.max_stack)
			slots[empty_slot] = { "item": item, "amount": to_add }
			amount -= to_add
		else:
			slots[empty_slot] = { "item": item, "amount": 1 }
			amount -= 1

	emit_signal("inventory_changed")
	return true

# ================= REMOVER ITENS =================

## Remove uma quantidade de um item específico
## Retorna true se foi bem-sucedido
func remove_item(item: Item, amount: int = 1) -> bool:
	if not has_item(item, amount):
		return false

	var remaining = amount
	for i in range(max_slots):
		var slot = slots[i]
		if slot != null and slot["item"].resource_path == item.resource_path:
			if slot["amount"] <= remaining:
				remaining -= slot["amount"]
				slots[i] = null
			else:
				slot["amount"] -= remaining
				remaining = 0

			if remaining <= 0:
				break

	emit_signal("inventory_changed")
	return true

# ================= VERIFICAÇÃO =================

## Verifica se o inventário tem pelo menos [amount] do item
func has_item(item: Item, amount: int = 1) -> bool:
	var total = 0
	for slot in slots:
		if slot != null and slot["item"].resource_path == item.resource_path:
			total += slot["amount"]
			if total >= amount:
				return true
	return false

## Retorna a quantidade total de um item no inventário
func get_item_count(item: Item) -> int:
	var total = 0
	for slot in slots:
		if slot != null and slot["item"].resource_path == item.resource_path:
			total += slot["amount"]
	return total

# ================= UTILITÁRIOS =================

## Retorna o índice do primeiro slot vazio, ou -1 se não houver
func _get_first_empty_slot() -> int:
	for i in range(max_slots):
		if slots[i] == null:
			return i
	return -1

## Retorna o item no slot [index], ou null se vazio
func get_slot(index: int) -> Dictionary:
	if index >= 0 and index < max_slots:
		return slots[index] if slots[index] != null else {}
	return {}

## Limpa todo o inventário (útil pra reset/teste)
func clear() -> void:
	for i in range(max_slots):
		slots[i] = null
	coins = 0
	emit_signal("inventory_changed")
	emit_signal("coins_changed", coins)
