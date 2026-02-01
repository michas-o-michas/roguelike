extends Node

func craft_axe():
	if GameManager.remove_item("wood", 5):
		GameManager.add_item("axe", 1)

func craft_pickaxe():
	if GameManager.remove_item("stone", 5):
		GameManager.add_item("pickaxe", 1)
