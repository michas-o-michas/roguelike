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

extends PanelContainer

# Referências (assign automaticamente via @onready)
@onready var output_icon_label: Label = $MainRow/OutputSection/OutputIcon/IconCenter/IconLabel
@onready var output_icon_texture: TextureRect = $MainRow/OutputSection/OutputIcon/IconCenter/ItemIcon
@onready var output_name_label: Label = $MainRow/OutputSection/OutputName
@onready var inputs_container: HBoxContainer = $MainRow/InputsSection/InputsContainer
@onready var craft_button: Button = $MainRow/CraftButton

# Dados da receita
var recipe: Dictionary
var recipe_index: int

func _ready() -> void:
	if craft_button:
		craft_button.pressed.connect(_on_craft_button_pressed)
		_style_craft_button()

# Paleta dark fantasy (fogueira, madeira, pedra — Bg.png)
var color_slot: Color = Color("#1c1814")
var color_border: Color = Color("#3d3630")
var color_craft_ok: Color = Color("#c96a2a")   # laranja fogueira
var color_craft_fail: Color = Color("#8b5a4a") # vermelho acinzentado
var color_text: Color = Color("#e8e0d4")      # pergaminho
var color_text_dim: Color = Color("#8a7a6a")

## Configura o card com uma receita
func setup(p_index: int, p_recipe: Dictionary) -> void:
	recipe = p_recipe
	recipe_index = p_index
	_refresh()

## Atualiza o visual
func _refresh() -> void:
	if recipe.is_empty():
		return
	
	# === OUTPUT (ícone do item ou fallback com 2 letras) ===
	var output_item: Item = recipe["output"]
	if output_item.item_icon != null:
		output_icon_texture.texture = output_item.item_icon
		output_icon_texture.visible = true
		output_icon_label.visible = false
	else:
		output_icon_texture.visible = false
		output_icon_label.visible = true
		output_icon_label.text = output_item.item_name.substr(0, 2).to_upper()
		output_icon_label.add_theme_color_override("font_color", color_text)
		output_icon_label.add_theme_font_size_override("font_size", 18)
	output_name_label.text = output_item.item_name
	output_name_label.add_theme_color_override("font_color", _get_rarity_color(output_item.rarity))
	output_name_label.add_theme_font_size_override("font_size", 16)
	
	# === INPUTS (limpa e cria dinamicamente) ===
	for child in inputs_container.get_children():
		child.queue_free()
	
	for input in recipe["inputs"]:
		var input_item: Item = input["item"]
		var have := InventoryManager.get_item_count(input_item)
		var need: int = input["amount"]
		var enough := have >= need
		
		var input_row := HBoxContainer.new()
		input_row.add_theme_constant_override("separation", 6)
		
		# Ícone do ingrediente (ou quadrado com iniciais)
		var icon_panel := PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(32, 32)
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = color_slot
		icon_style.border_width_left = 1
		icon_style.border_width_right = 1
		icon_style.border_width_top = 1
		icon_style.border_width_bottom = 1
		icon_style.border_color = color_craft_ok if enough else color_craft_fail
		icon_style.corner_radius_top_left = 4
		icon_style.corner_radius_top_right = 4
		icon_style.corner_radius_bottom_left = 4
		icon_style.corner_radius_bottom_right = 4
		icon_panel.add_theme_stylebox_override("panel", icon_style)
		var icon_center := CenterContainer.new()
		icon_panel.add_child(icon_center)
		if input_item.item_icon != null:
			var tex := TextureRect.new()
			tex.custom_minimum_size = Vector2(26, 26)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.texture = input_item.item_icon
			icon_center.add_child(tex)
		else:
			var init_label := Label.new()
			init_label.text = input_item.item_name.substr(0, 2).to_upper()
			init_label.add_theme_font_size_override("font_size", 11)
			init_label.add_theme_color_override("font_color", color_text)
			init_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			init_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_center.add_child(init_label)
		input_row.add_child(icon_panel)
		
		var amount_label := Label.new()
		amount_label.text = "%s  %d/%d" % [input_item.item_name, have, need]
		amount_label.add_theme_font_size_override("font_size", 13)
		amount_label.add_theme_color_override("font_color", color_craft_ok if enough else color_craft_fail)
		amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		input_row.add_child(amount_label)
		
		inputs_container.add_child(input_row)
	
	# === BOTÃO ===
	var can_craft = CraftingManager.can_craft(recipe_index)
	craft_button.disabled = not can_craft
	
	# Transparência do card
	modulate = Color(1, 1, 1, 1.0 if can_craft else 0.5)
	
	# Tooltip
	if not can_craft:
		var missing = CraftingManager.get_missing_inputs(recipe_index)
		var tip := "Falta:\n"
		for m in missing:
			if not m["enough"]:
				var need_more = m["need"] - m["have"]
				tip += "- %s x%d\n" % [m["item"].item_name, need_more]
		craft_button.tooltip_text = tip
	else:
		craft_button.tooltip_text = ""

func _on_craft_button_pressed() -> void:
	var result = CraftingManager.craft(recipe_index)
	if result:
		print("✅ Craftou:", result.item_name)
		# Atualiza visual
		await get_tree().process_frame
		_refresh()

func _style_craft_button() -> void:
	if not craft_button:
		return
	# Aparência dark fantasy: fundo madeira/ferro, borda quente
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color("#2a231c")
	normal_style.border_color = Color("#5c4a3a")
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	craft_button.add_theme_stylebox_override("normal", normal_style)
	var hover_style = normal_style.duplicate()
	hover_style.border_color = Color("#c96a2a")
	craft_button.add_theme_stylebox_override("hover", hover_style)
	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color("#1a1612")
	disabled_style.border_color = Color("#3d3530")
	craft_button.add_theme_stylebox_override("disabled", disabled_style)
	craft_button.add_theme_font_size_override("font_size", 14)
	craft_button.add_theme_color_override("font_color", color_text)
	craft_button.add_theme_color_override("font_hover_color", Color("#f0d8a8"))
	craft_button.add_theme_color_override("font_disabled_color", color_text_dim)

func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		Item.Rarity.COMMON: return Color("#7a9a6a")
		Item.Rarity.UNCOMMON: return Color("#6a8aaa")
		Item.Rarity.RARE: return Color("#c9a227")
	return color_text
