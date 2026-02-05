# crafting_ui.gd
# UI do Crafting — mostra receitas, valida recursos, e crafta itens
#
# Attach em: Control dentro do CraftingContent (tab de crafting)
#
# Estrutura esperada:
#   Control (este script)
#   └── ScrollContainer
#       └── VBoxContainer (name: "RecipesList")
#           └── Receitas são criadas dinamicamente

extends Control

# Referência ao container das receitas
@onready var recipes_list = $ScrollContainer/RecipesList

# ================= CORES =================
var color_panel_light: Color = Color("#1d2025")
var color_slot: Color = Color("#0f1115")
var color_border: Color = Color("#2a2d35")
var color_text: Color = Color("#e8e6e0")
var color_text_dim: Color = Color("#8a8a82")
var color_green: Color = Color("#6aa66a")
var color_red: Color = Color("#aa6a6a")
var color_rarity_common: Color = Color("#6aa66a")
var color_rarity_uncommon: Color = Color("#6a8aaa")
var color_rarity_rare: Color = Color("#8a6aaa")

# ================= INICIALIZAÇÃO =================
func _ready():
	# Conecta sinais
	InventoryManager.inventory_changed.connect(_refresh_recipes)
	CraftingManager.craft_success.connect(_on_craft_success)
	CraftingManager.craft_failed.connect(_on_craft_failed)
	
	# Carrega receitas
	_refresh_recipes()

# ================= ATUALIZAR RECEITAS =================

func _refresh_recipes() -> void:
	# Limpa receitas antigas
	for child in recipes_list.get_children():
		child.queue_free()
	
	# Pega todas as receitas
	var recipes = CraftingManager.get_all_recipes()
	
	if recipes.is_empty():
		# Mensagem se não tiver receitas
		var empty_label = Label.new()
		empty_label.text = "Nenhuma receita disponível"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", color_text_dim)
		recipes_list.add_child(empty_label)
		return
	
	# OPÇÃO 1: Cria cards programaticamente (atual)
	# Descomenta se não tiver recipe_card.tscn
	#for i in range(recipes.size()):
		#var recipe_card = _create_recipe_card(i, recipes[i])
		#recipes_list.add_child(recipe_card)
	
	# OPÇÃO 2: Instancia scene manual (se tiver recipe_card.tscn)
	# Comenta o código acima e descomenta este:
	#
	var recipe_card_scene = preload("res://Scenes/UI/recipe_card.tscn")
	for i in range(recipes.size()):
		var card = recipe_card_scene.instantiate()
		recipes_list.add_child(card)
		card.setup(i, recipes[i])

# ================= CRIAR CARD DE RECEITA =================

func _create_recipe_card(recipe_index: int, recipe: Dictionary) -> Panel:
	var can_craft = CraftingManager.can_craft(recipe_index)
	
	var card = Panel.new()
	card.custom_minimum_size = Vector2(0, 100)
	
	# Estilo do card
	var style = StyleBoxFlat.new()
	style.bg_color = color_panel_light
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color_border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Se não pode craftar, fica meio transparente
	if not can_craft:
		card.modulate = Color(1, 1, 1, 0.5)
	
	# === OUTPUT (item que será craftado) ===
	var output_container = HBoxContainer.new()
	output_container.position = Vector2(16, 12)
	card.add_child(output_container)
	
	# Ícone do output (placeholder)
	var output_icon = Panel.new()
	output_icon.custom_minimum_size = Vector2(48, 48)
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = color_slot
	icon_style.border_width_left = 2
	icon_style.border_width_right = 2
	icon_style.border_width_top = 2
	icon_style.border_width_bottom = 2
	icon_style.border_color = _get_rarity_color(recipe["output"].rarity)
	icon_style.corner_radius_top_left = 6
	icon_style.corner_radius_top_right = 6
	icon_style.corner_radius_bottom_left = 6
	icon_style.corner_radius_bottom_right = 6
	output_icon.add_theme_stylebox_override("panel", icon_style)
	
	# Label do ícone (letra inicial)
	var icon_label = Label.new()
	icon_label.text = recipe["output"].item_name.substr(0, 2).to_upper()
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(48, 48)
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.add_theme_color_override("font_color", _get_rarity_color(recipe["output"].rarity))
	output_icon.add_child(icon_label)
	
	output_container.add_child(output_icon)
	
	# Nome do output
	var output_name = Label.new()
	output_name.text = recipe["output"].item_name
	output_name.position = Vector2(8, 0)
	output_name.add_theme_font_size_override("font_size", 16)
	output_name.add_theme_color_override("font_color", _get_rarity_color(recipe["output"].rarity))
	output_container.add_child(output_name)
	
	# === INPUTS (recursos necessários) ===
	var inputs_label = Label.new()
	inputs_label.text = "Requer:"
	inputs_label.position = Vector2(80, 12)
	inputs_label.add_theme_font_size_override("font_size", 11)
	inputs_label.add_theme_color_override("font_color", color_text_dim)
	card.add_child(inputs_label)
	
	var inputs_container = HBoxContainer.new()
	inputs_container.position = Vector2(80, 32)
	inputs_container.add_theme_constant_override("separation", 8)
	card.add_child(inputs_container)
	
	for input in recipe["inputs"]:
		var have = InventoryManager.get_item_count(input["item"])
		var need = input["amount"]
		var enough = have >= need
		
		# Panel do input
		var input_panel = Panel.new()
		input_panel.custom_minimum_size = Vector2(120, 36)
		
		var input_style = StyleBoxFlat.new()
		input_style.bg_color = color_slot
		input_style.border_width_left = 2
		input_style.border_width_right = 2
		input_style.border_width_top = 2
		input_style.border_width_bottom = 2
		input_style.border_color = color_green if enough else color_red
		input_style.corner_radius_top_left = 4
		input_style.corner_radius_top_right = 4
		input_style.corner_radius_bottom_left = 4
		input_style.corner_radius_bottom_right = 4
		input_panel.add_theme_stylebox_override("panel", input_style)
		
		# Label do input
		var input_label = Label.new()
		input_label.text = "%s\n%d/%d" % [input["item"].item_name, have, need]
		input_label.position = Vector2(8, 6)
		input_label.add_theme_font_size_override("font_size", 11)
		input_label.add_theme_color_override("font_color", color_green if enough else color_red)
		input_panel.add_child(input_label)
		
		inputs_container.add_child(input_panel)
	
	# === BOTÃO CRAFTAR ===
	var craft_button = Button.new()
	craft_button.text = "CRAFTAR"
	craft_button.custom_minimum_size = Vector2(100, 40)
	craft_button.position = Vector2(card.custom_minimum_size.x - 116, 30)
	craft_button.disabled = not can_craft
	craft_button.pressed.connect(_on_craft_button_pressed.bind(recipe_index))
	
	# Tooltip mostrando o que falta
	if not can_craft:
		var missing = CraftingManager.get_missing_inputs(recipe_index)
		var tooltip_text = "Falta:\n"
		for m in missing:
			if not m["enough"]:
				var need_more = m["need"] - m["have"]
				tooltip_text += "- %s x%d\n" % [m["item"].item_name, need_more]
		craft_button.tooltip_text = tooltip_text
	
	card.add_child(craft_button)
	
	return card

# ================= CALLBACKS =================

func _on_craft_button_pressed(recipe_index: int) -> void:
	print("Tentando craftar receita ", recipe_index)
	CraftingManager.craft(recipe_index)

func _on_craft_success(item: Item) -> void:
	print("✅ Craftou: ", item.item_name)
	# Pode adicionar efeito visual aqui (ex: animação, som)

func _on_craft_failed(reason: String) -> void:
	print("❌ Craft falhou: ", reason)
	# Pode mostrar mensagem de erro na UI

# ================= UTILITÁRIOS =================

func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		Item.Rarity.COMMON:   return color_rarity_common
		Item.Rarity.UNCOMMON: return color_rarity_uncommon
		Item.Rarity.RARE:     return color_rarity_rare
	return Color.WHITE
