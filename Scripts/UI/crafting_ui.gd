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
@onready var scroll_container = $ScrollContainer

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
	recipes_list.add_theme_constant_override("separation", 10)
	if scroll_container is ScrollContainer:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.05, 0.05, 0.5)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		scroll_container.add_theme_stylebox_override("panel", style)
	InventoryManager.inventory_changed.connect(_refresh_recipes)
	CraftingManager.craft_success.connect(_on_craft_success)
	CraftingManager.craft_failed.connect(_on_craft_failed)
	_refresh_recipes()

# ================= ATUALIZAR RECEITAS =================

func _refresh_recipes() -> void:
	# Limpa receitas antigas
	for child in recipes_list.get_children():
		child.queue_free()
	
	# Pega todas as receitas
	var recipes = CraftingManager.get_all_recipes()
	
	if recipes.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Nenhuma receita disponível"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", color_text_dim)
		empty_label.add_theme_font_size_override("font_size", 14)
		recipes_list.add_child(empty_label)
		return
	
	var recipe_card_scene = preload("res://Scenes/UI/recipe_card.tscn")
	for i in range(recipes.size()):
		var card = recipe_card_scene.instantiate()
		recipes_list.add_child(card)
		card.setup(i, recipes[i])

# ================= CALLBACKS =================

func _on_craft_success(item: Item) -> void:
	print("✅ Craftou: ", item.item_name)
	# Pode adicionar efeito visual aqui (ex: animação, som)
	if SoundManager and SoundManager.has_sfx(&"ui_inventory_select"):
		SoundManager.play_sfx_id(&"ui_inventory_select")

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
