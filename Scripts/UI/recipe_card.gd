# recipe_card_manual.gd
# Attach na scene recipe_card.tscn que você cria manualmente
#
# Estrutura esperada (cria no editor):
#   Panel (este script)
#   ├── HBoxContainer "OutputContainer"
#   │   ├── Panel "OutputIcon"
#   │   │   └── Label "IconLabel"
#   │   └── Label "OutputName"
#   ├── Label "RequiredLabel" (texto: "Requer:")
#   ├── HBoxContainer "InputsContainer" ← ÚNICO que é preenchido dinamicamente
#   └── Button "CraftButton"

extends Panel
@onready var icon_label: Label = $OutputContainer/OutputIcon/IconLabel

# Referências (assign automaticamente via @onready)
@onready var output_icon_label: Label = $OutputContainer/OutputIcon/IconLabel
@onready var output_name_label: Label = $OutputContainer/OutputName
@onready var inputs_container: HBoxContainer = $InputsContainer
@onready var craft_button: Button = $CraftButton

# Dados da receita
var recipe: Dictionary
var recipe_index: int

# Cores
var color_slot: Color = Color("#0f1115")
var color_border: Color = Color("#2a2d35")
var color_green: Color = Color("#6aa66a")
var color_red: Color = Color("#aa6a6a")

## Configura o card com uma receita
func setup(p_index: int, p_recipe: Dictionary) -> void:
	recipe = p_recipe
	recipe_index = p_index
	_refresh()

## Atualiza o visual
func _refresh() -> void:
	if recipe.is_empty():
		return
	
	# === OUTPUT ===
	output_icon_label.text = recipe["output"].item_name.substr(0, 2).to_upper()
	output_name_label.text = recipe["output"].item_name
	output_name_label.add_theme_color_override("font_color", _get_rarity_color(recipe["output"].rarity))
	
	# === INPUTS (limpa e cria dinamicamente) ===
	for child in inputs_container.get_children():
		child.queue_free()
	
	for input in recipe["inputs"]:
		var have = InventoryManager.get_item_count(input["item"])
		var need = input["amount"]
		var enough = have >= need
		
		# Panel do input
		var input_panel = Panel.new()
		input_panel.custom_minimum_size = Vector2(110, 36)
		
		var style = StyleBoxFlat.new()
		style.bg_color = color_slot
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = color_green if enough else color_red
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		input_panel.add_theme_stylebox_override("panel", style)
		
		# Label dentro do panel
		var label = Label.new()
		label.text = "%s\n%d/%d" % [input["item"].item_name, have, need]
		label.position = Vector2(6, 6)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", color_green if enough else color_red)
		input_panel.add_child(label)
		
		inputs_container.add_child(input_panel)
	
	# === BOTÃO ===
	var can_craft = CraftingManager.can_craft(recipe_index)
	craft_button.disabled = not can_craft
	
	# Transparência do card
	modulate = Color(1, 1, 1, 1.0 if can_craft else 0.5)
	
	# Tooltip
	if not can_craft:
		var missing = CraftingManager.get_missing_inputs(recipe_index)
		var tooltip_text = "Falta:\n"
		for m in missing:
			if not m["enough"]:
				var need_more = m["need"] - m["have"]
				tooltip_text += "- %s x%d\n" % [m["item"].item_name, need_more]
		craft_button.tooltip_text = tooltip_text

func _on_craft_button_pressed() -> void:
	var result = CraftingManager.craft(recipe_index)
	if result:
		print("✅ Craftou:", result.item_name)
		# Atualiza visual
		await get_tree().process_frame
		_refresh()

func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		Item.Rarity.COMMON: return Color("#6aa66a")
		Item.Rarity.UNCOMMON: return Color("#6a8aaa")
		Item.Rarity.RARE: return Color("#8a6aaa")
	return Color.WHITE
