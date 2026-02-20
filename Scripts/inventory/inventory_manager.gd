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
	slots.clear()
	slots.resize(max_slots)
	emit_signal("inventory_changed")



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

# ================= API POR ID (usa CraftingManager.item_registry) =================

## Adiciona item por id (ex.: "wood", "stone"). Retorna false se id não existir ou inventário cheio.
func add_item_by_id(id: String, amount: int) -> bool:
	if not CraftingManager:
		return false
	var item: Item = CraftingManager.get_item_by_id(id)
	if not item:
		return false
	return add_item(item, amount)

## Remove quantidade do item por id. Retorna false se não tiver quantidade suficiente.
func remove_item_by_id(id: String, amount: int) -> bool:
	if not CraftingManager:
		return false
	var item: Item = CraftingManager.get_item_by_id(id)
	if not item:
		return false
	return remove_item(item, amount)

## Verifica se tem pelo menos [amount] do item por id.
func has_item_by_id(id: String, amount: int = 1) -> bool:
	if not CraftingManager:
		return false
	var item: Item = CraftingManager.get_item_by_id(id)
	if not item:
		return false
	return has_item(item, amount)

## Retorna a quantidade total do item por id no inventário.
func get_item_count_by_id(id: String) -> int:
	if not CraftingManager:
		return 0
	var item: Item = CraftingManager.get_item_by_id(id)
	if not item:
		return 0
	return get_item_count(item)

## Retorna dicionário id (string) → quantidade total. Útil para UI legada (ex.: UIManager).
func get_all_item_counts() -> Dictionary:
	var counts: Dictionary = {}
	if not CraftingManager:
		return counts
	for slot in slots:
		if slot == null:
			continue
		var item: Item = slot["item"]
		var id: String = CraftingManager.get_id_for_item(item)
		if id.is_empty():
			id = item.resource_path
		if not counts.has(id):
			counts[id] = 0
		counts[id] += slot["amount"]
	return counts

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
