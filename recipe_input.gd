# recipe_input.gd
# Resource que representa um input de receita (item + quantidade)
#
# Como usar:
#   Na receita, clica "Add Element" no array Inputs
#   Clica no elemento > "New RecipeInput"
#   Preenche Item e Amount

class_name RecipeInput
extends Resource

@export var item: Item
@export var amount: int = 1
