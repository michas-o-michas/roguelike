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
	# ESCOLHA UMA OPÇÃO:
	
	# OPÇÃO 1: Registro manual (atual)
	#_register_items()
	
	# OPÇÃO 2: Auto-registra de pasta (recomendado)
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

# ================= REGISTRO DE ITENS =================

func _register_items():
	# Registra todos os itens do jogo aqui (ID → Item)
	# Você pode automatizar isso depois, mas por enquanto é manual
	
	# Recursos
	var wood = Item.new()
	wood.item_name = "Madeira"
	wood.type = Item.Type.RESOURCE
	wood.rarity = Item.Rarity.COMMON
	wood.max_stack = 64
	item_registry["wood"] = wood
	
	var stone = Item.new()
	stone.item_name = "Pedra"
	stone.type = Item.Type.RESOURCE
	stone.rarity = Item.Rarity.COMMON
	stone.max_stack = 64
	item_registry["stone"] = stone
	
	var iron = Item.new()
	iron.item_name = "Ferro"
	iron.type = Item.Type.RESOURCE
	iron.rarity = Item.Rarity.UNCOMMON
	iron.max_stack = 64
	item_registry["iron"] = iron
	
	var crystal = Item.new()
	crystal.item_name = "Cristal"
	crystal.type = Item.Type.RESOURCE
	crystal.rarity = Item.Rarity.RARE
	crystal.max_stack = 64
	item_registry["crystal"] = crystal
	
	# Armas
	var wood_sword = Weapon.new()
	wood_sword.item_name = "Espada de Madeira"
	wood_sword.type = Item.Type.WEAPON
	wood_sword.rarity = Item.Rarity.COMMON
	wood_sword.weapon_type = Weapon.WeaponType.MELEE
	wood_sword.damage = 5
	wood_sword.attack_speed = 0.8
	item_registry["wood_sword"] = wood_sword
	
	var iron_sword = Weapon.new()
	iron_sword.item_name = "Espada de Ferro"
	iron_sword.type = Item.Type.WEAPON
	iron_sword.rarity = Item.Rarity.UNCOMMON
	iron_sword.weapon_type = Weapon.WeaponType.MELEE
	iron_sword.damage = 15
	iron_sword.attack_speed = 0.6
	item_registry["iron_sword"] = iron_sword
	
	var crystal_sword = Weapon.new()
	crystal_sword.item_name = "Espada de Cristal"
	crystal_sword.type = Item.Type.WEAPON
	crystal_sword.rarity = Item.Rarity.RARE
	crystal_sword.weapon_type = Weapon.WeaponType.MELEE
	crystal_sword.damage = 25
	crystal_sword.attack_speed = 0.5
	item_registry["crystal_sword"] = crystal_sword
	
	var stone_pickaxe = Weapon.new()
	stone_pickaxe.item_name = "Picareta de Pedra"
	stone_pickaxe.type = Item.Type.TOOL
	stone_pickaxe.rarity = Item.Rarity.COMMON
	stone_pickaxe.weapon_type = Weapon.WeaponType.MELEE
	stone_pickaxe.damage = 3
	stone_pickaxe.attack_speed = 1.0
	item_registry["stone_pickaxe"] = stone_pickaxe
	
	print("  %d itens registrados" % item_registry.size())

# ================= CARREGAR RECIPES =================

func _load_recipes_from_json():
	var file = FileAccess.open("res://recipes.json", FileAccess.READ)
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
