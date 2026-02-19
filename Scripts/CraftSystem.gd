extends Node
## Atalhos de craft que delegam ao CraftingManager (receitas em recipes.json).
## Índice 0 = Machado, 1 = Picareta.

func craft_axe() -> void:
	if CraftingManager.can_craft(0):
		CraftingManager.craft(0)

func craft_pickaxe() -> void:
	if CraftingManager.can_craft(1):
		CraftingManager.craft(1)
