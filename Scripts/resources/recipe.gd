# recipe.gd
# Resource de receita — cria arquivos .tres no editor
#
# Como criar uma receita:
#   1. FileSystem > clica direito > New Resource > Recipe
#   2. No Inspector:
#      - Output Item: arrasta o .tres do item final
#      - Inputs > Add Element > New RecipeInput
#        - Item: arrasta o .tres do recurso
#        - Amount: quantidade necessária
#   3. Salva como recipe_iron_sword.tres na pasta res://recipes/

class_name Recipe
extends Resource

## Item que será craftado
@export var output_item: Item

## Recursos necessários (array de RecipeInput)
@export var inputs: Array[Item] = []

## Verifica se o player pode craftar esta receita
func can_craft() -> bool:
	if not output_item:
		return false
	
	for input in inputs:
		if not input or not input.item:
			continue
		
		if not InventoryManager.has_item(input.item, input.amount):
			return false
	
	return true

## Retorna inputs faltando
func get_missing_inputs() -> Array:
	var result = []
	
	for input in inputs:
		if not input or not input.item:
			continue
		
		var have = InventoryManager.get_item_count(input.item)
		result.append({
			"item": input.item,
			"have": have,
			"need": input.amount,
			"enough": have >= input.amount
		})
	
	return result

## Crafta o item (consome recursos e adiciona ao inventário)
func craft() -> bool:
	if not can_craft():
		return false
	
	# Consome recursos
	for input in inputs:
		if not input or not input.item:
			continue
		
		InventoryManager.remove_item(input.item, input.amount)
	
	# Adiciona output
	if output_item:
		InventoryManager.add_item(output_item, 1)
		return true
	
	return false
