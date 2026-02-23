# test_inventory_crafting.gd
# Testes manuais de inventário e crafting. Rode a cena Testes/test_inventory_crafting.tscn (F6 ou Play nesta cena).
# Requer autoloads: InventoryManager, CraftingManager.

extends Node

func _ready() -> void:
	var passed := true
	# Inventário
	if not _test_inventory():
		passed = false
	# Crafting
	if not _test_crafting():
		passed = false
	if passed:
		print("[TEST] ✅ Todos os testes de inventário e crafting passaram.")
	else:
		print("[TEST] ❌ Alguns testes falharam. Veja as mensagens acima.")

func _test_inventory() -> bool:
	if not InventoryManager:
		print("[TEST] FAIL: InventoryManager não disponível (autoload).")
		return false
	InventoryManager.clear()
	# add_item_by_id
	if not InventoryManager.add_item_by_id("wood", 50):
		print("[TEST] FAIL: add_item_by_id('wood', 50) retornou false.")
		return false
	if not InventoryManager.has_item_by_id("wood", 50):
		print("[TEST] FAIL: has_item_by_id('wood', 50) retornou false após add 50.")
		return false
	if InventoryManager.get_item_count_by_id("wood") != 50:
		print("[TEST] FAIL: get_item_count_by_id('wood') != 50.")
		return false
	# remove
	if not InventoryManager.remove_item_by_id("wood", 10):
		print("[TEST] FAIL: remove_item_by_id('wood', 10) retornou false.")
		return false
	if InventoryManager.get_item_count_by_id("wood") != 40:
		print("[TEST] FAIL: Após remove 10, count deveria ser 40, era ", InventoryManager.get_item_count_by_id("wood"))
		return false
	# id inexistente
	if InventoryManager.add_item_by_id("id_inexistente_xyz", 1):
		print("[TEST] FAIL: add_item_by_id com id inexistente deveria retornar false.")
		return false
	if InventoryManager.get_item_count_by_id("id_inexistente_xyz") != 0:
		print("[TEST] FAIL: get_item_count_by_id(id inexistente) deveria ser 0.")
		return false
	# moedas (item type CURRENCY)
	InventoryManager.init_coins(0)
	if InventoryManager.get_coins() != 0:
		print("[TEST] FAIL: init_coins(0) ou get_coins().")
		return false
	InventoryManager.add_coins(100)
	if InventoryManager.get_coins() != 100:
		print("[TEST] FAIL: add_coins(100) ou get_coins().")
		return false
	if not InventoryManager.spend_coins(30):
		print("[TEST] FAIL: spend_coins(30) retornou false.")
		return false
	if InventoryManager.get_coins() != 70:
		print("[TEST] FAIL: Após spend 30, coins deveria ser 70.")
		return false
	if InventoryManager.spend_coins(100):
		print("[TEST] FAIL: spend_coins(100) com saldo 70 deveria retornar false.")
		return false
	return true

func _test_crafting() -> bool:
	if not CraftingManager:
		print("[TEST] FAIL: CraftingManager não disponível (autoload).")
		return false
	if not InventoryManager:
		return false
	InventoryManager.clear()
	# Garantir recursos para uma receita (axe = 1 wood)
	InventoryManager.add_item_by_id("wood", 5)
	InventoryManager.add_item_by_id("stone", 10)
	var idx_axe := CraftingManager.get_recipe_index_by_output_id("axe")
	if idx_axe < 0:
		print("[TEST] FAIL: Receita 'axe' não encontrada.")
		return false
	if not CraftingManager.can_craft(idx_axe):
		print("[TEST] FAIL: can_craft(axe) deveria ser true com wood no inventário.")
		return false
	var item_before := InventoryManager.get_item_count_by_id("axe")
	var crafted: Item = CraftingManager.craft(idx_axe)
	if not crafted:
		print("[TEST] FAIL: craft(axe) retornou null.")
		return false
	if InventoryManager.get_item_count_by_id("axe") != item_before + 1:
		print("[TEST] FAIL: Após craft(axe), quantidade de axe no inventário não aumentou em 1.")
		return false
	# craft sem recursos (remove toda madeira)
	InventoryManager.remove_item_by_id("wood", 10)
	var idx_axe2 := CraftingManager.get_recipe_index_by_output_id("axe")
	if CraftingManager.can_craft(idx_axe2):
		InventoryManager.remove_item_by_id("wood", InventoryManager.get_item_count_by_id("wood"))
	var craft_fail: Item = CraftingManager.craft(idx_axe2)
	if craft_fail != null:
		print("[TEST] FAIL: craft sem recursos deveria retornar null.")
		return false
	# get_item_by_id / get_id_for_item
	var wood_item: Item = CraftingManager.get_item_by_id("wood")
	if not wood_item:
		print("[TEST] FAIL: get_item_by_id('wood') retornou null.")
		return false
	if CraftingManager.get_id_for_item(wood_item) != "wood":
		print("[TEST] FAIL: get_id_for_item(wood_item) deveria ser 'wood'.")
		return false
	return true
