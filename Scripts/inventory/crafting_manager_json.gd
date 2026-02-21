# crafting_manager.gd
# Sistema de crafting SIMPLES — baseado em JSON
#
# Como adicionar receitas:
#   1. Edita recipes.json na pasta res://
#   2. Adiciona um novo objeto no array "recipes"
#   3. Pronto! Automático quando rodar o jogo
#
# Formato:
#   {
#     "name": "Nome do Item",
#     "output": "id_do_item",
#     "inputs": [
#       {"item": "id_recurso", "amount": 5}
#     ]
#   }

extends Node

signal craft_success(item: Item)
signal craft_failed(reason: String)

# Registro de itens (ID → Item resource)
var item_registry: Dictionary = {}

# Receitas carregadas do JSON
var recipes: Array = []

func _ready():

	_register_items_from_folder("res://items/")
	
	_load_recipes_from_json()
	print("✅ CraftingManager carregado com %d receitas" % recipes.size())

# ================= OPÇÃO 2: AUTO REGISTRO =================

func _register_items_from_folder(folder_path: String):
	var dir = DirAccess.open(folder_path)
	if not dir:
		push_warning("Pasta de itens não encontrada: %s" % folder_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path = folder_path + file_name
			var item = load(full_path) as Item
			if item:
				# ID = nome do arquivo sem extensão
				var item_id = file_name.replace(".tres", "")
				item_registry[item_id] = item
				print("  Item registrado: %s → %s" % [item_id, item.item_name])
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("  Total: %d itens registrados" % item_registry.size())

# ================= API REGISTRO (ID ↔ Item) =================

## Retorna o Item associado ao id (nome do .tres em res://items/). Retorna null se não existir.
func get_item_by_id(id: String) -> Item:
	return item_registry.get(id, null)

## Retorna o id (string) do item no registro. Usado para UI e get_all_item_counts.
func get_id_for_item(item: Item) -> String:
	if not item:
		return ""
	for key in item_registry:
		var reg_item = item_registry[key]
		if reg_item and reg_item.resource_path == item.resource_path:
			return key
	return ""

# ================= CARREGAR RECIPES =================

func _load_recipes_from_json():
	var file = FileAccess.open("res://Recipes/recipes.json", FileAccess.READ)
	if not file:
		push_error("recipes.json não encontrado!")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Erro ao parsear recipes.json: %s" % json.get_error_message())
		return
	
	var data = json.data
	
	if not data.has("recipes"):
		push_error("recipes.json não tem campo 'recipes'")
		return
	
	for recipe_data in data["recipes"]:
		var recipe = _parse_recipe(recipe_data)
		if recipe:
			recipes.append(recipe)
			print("  Receita: %s" % recipe["name"])

func _parse_recipe(data: Dictionary) -> Dictionary:
	# Converte JSON pra formato interno
	if not data.has("output") or not item_registry.has(data["output"]):
		push_warning("Receita com output inválido: %s" % data.get("name", "sem nome"))
		return {}
	
	var recipe = {
		"name": data.get("name", ""),
		"output": item_registry[data["output"]],
		"output_amount": data.get("output_amount", 1),
		"inputs": []
	}
	
	for input_data in data.get("inputs", []):
		if not input_data.has("item") or not item_registry.has(input_data["item"]):
			continue
		
		recipe["inputs"].append({
			"item": item_registry[input_data["item"]],
			"amount": input_data.get("amount", 1)
		})
	
	return recipe

# ================= API =================

func get_all_recipes() -> Array:
	return recipes

func get_recipe(index: int) -> Dictionary:
	if index >= 0 and index < recipes.size():
		return recipes[index]
	return {}

## Retorna o índice da receita cujo output é este id (ex.: "axe", "pickaxe"). -1 se não existir.
func get_recipe_index_by_output_id(output_id: String) -> int:
	for i in range(recipes.size()):
		var r = recipes[i]
		if r.get("output", null) and get_id_for_item(r["output"]) == output_id:
			return i
	return -1

## Crafta por id do item de saída (ex.: craft_by_id("axe")). Retorna o Item craftado ou null.
func craft_by_id(output_id: String) -> Item:
	var idx = get_recipe_index_by_output_id(output_id)
	if idx < 0:
		emit_signal("craft_failed", "Receita não encontrada: %s" % output_id)
		return null
	return craft(idx)

func can_craft(index: int) -> bool:
	var recipe = get_recipe(index)
	if recipe.is_empty():
		return false
	
	for input in recipe["inputs"]:
		if not InventoryManager.has_item(input["item"], input["amount"]):
			return false
	
	return true

func get_missing_inputs(index: int) -> Array:
	var recipe = get_recipe(index)
	if recipe.is_empty():
		return []
	
	var result = []
	for input in recipe["inputs"]:
		var have = InventoryManager.get_item_count(input["item"])
		result.append({
			"item": input["item"],
			"have": have,
			"need": input["amount"],
			"enough": have >= input["amount"]
		})
	
	return result

func craft(index: int) -> Item:
	if not can_craft(index):
		emit_signal("craft_failed", "Recursos insuficientes")
		return null
	
	var recipe = get_recipe(index)
	
	# Consome recursos
	for input in recipe["inputs"]:
		InventoryManager.remove_item(input["item"], input["amount"])
	
	# Adiciona output
	var output_item = recipe["output"]
	InventoryManager.add_item(output_item, recipe.get("output_amount", 1))
	
	emit_signal("craft_success", output_item)
	return output_item
