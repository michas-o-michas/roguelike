extends CanvasLayer

@onready var label = $Control/InventoryLabel

func _ready():
	GameManager.inventory_changed.connect(update_ui)
	update_ui()

func update_ui():
	var text = "INVENTÁRIO:\n"

	for key in GameManager.inventory.keys():
		text += key + ": " + str(GameManager.inventory[key]) + "\n"

	label.text = text
