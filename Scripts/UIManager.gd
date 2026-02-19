extends CanvasLayer

@onready var label = $Control/InventoryLabel

func _ready():
	InventoryManager.inventory_changed.connect(update_ui)
	update_ui()

func update_ui():
	var text = "INVENTÁRIO:\n"
	var counts = InventoryManager.get_all_item_counts()
	for key in counts.keys():
		text += key + ": " + str(counts[key]) + "\n"
	label.text = text
