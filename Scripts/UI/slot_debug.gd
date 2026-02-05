# slot_debug.gd
# Script de DEBUG — attach temporariamente em UM slot pra testar
# Remove depois que o drag & drop funcionar

extends Panel

func _ready():
	print("=== SLOT DEBUG ===")
	print("Script attached: OK")
	print("Mouse filter: ", mouse_filter)
	print("Position: ", position)
	print("Size: ", size)
	print("Visible: ", visible)
	
	# Lista filhos
	print("Filhos:")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")

func _gui_input(event):
	print("_gui_input chamado! Evento: ", event)
	
	if event is InputEventMouseButton:
		print("  Mouse button: ", event.button_index, " Pressed: ", event.pressed)

func _get_drag_data(_pos):
	print("_get_drag_data CHAMADO!")
	return { "test": "drag funcionando!" }

func _can_drop_data(_pos, data):
	print("_can_drop_data CHAMADO! Data: ", data)
	return true

func _drop_data(_pos, data):
	print("_drop_data CHAMADO! Data: ", data)
