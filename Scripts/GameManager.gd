extends Node

var inventory := {}

signal inventory_changed

func add_item(id: String, amount: int):
	if not inventory.has(id):
		inventory[id] = 0

	inventory[id] += amount
	emit_signal("inventory_changed")

func remove_item(id: String, amount: int) -> bool:
	if not inventory.has(id):
		return false

	if inventory[id] < amount:
		return false

	inventory[id] -= amount
	emit_signal("inventory_changed")
	return true

func get_amount(id: String) -> int:
	if inventory.has(id):
		return inventory[id]
	return 0
