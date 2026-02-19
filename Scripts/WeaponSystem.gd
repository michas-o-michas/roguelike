# WeaponSystem.gd
# Autoload: registro de armas e ferramentas por id (melee + ferramentas que batem).
# Usa os itens tipo Weapon do CraftingManager (wood_sword, axe, pickaxe, etc.).
#
# Uso:
#   WeaponSystem.get_weapon("wood_sword")  # retorna Weapon ou null
#   WeaponSystem.get_all_weapon_ids()  # ["wood_sword", "axe", "pickaxe"]
#   weapon_handler.equip(WeaponSystem.get_weapon("axe"))

extends Node

var _weapons: Dictionary = {}  # id (String) -> Weapon

func _ready() -> void:
	# Defer para garantir que CraftingManager já populou item_registry
	call_deferred("_build_registry")

func _build_registry() -> void:
	_weapons.clear()
	if not CraftingManager:
		push_warning("WeaponSystem: CraftingManager não encontrado.")
		return
	for id in CraftingManager.item_registry:
		var item = CraftingManager.item_registry[id]
		if item is Weapon:
			_weapons[id] = item
	if _weapons.is_empty():
		_load_weapons_from_folder("res://items/")
	print("WeaponSystem: ", _weapons.size(), " armas registradas")

func _load_weapons_from_folder(folder_path: String) -> void:
	var dir = DirAccess.open(folder_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path = folder_path
			if not path.ends_with("/"):
				path += "/"
			var item = load(path + file_name) as Resource
			if item is Weapon:
				var id = file_name.get_basename()
				_weapons[id] = item
		file_name = dir.get_next()
	dir.list_dir_end()

## Retorna o Weapon associado ao id (ex.: "wood_sword", "axe", "pickaxe"). Retorna null se não existir.
func get_weapon(id: String) -> Weapon:
	return _weapons.get(id, null)

## Retorna todos os ids de armas/ferramentas (útil para UI ou equipar primeira arma).
func get_all_weapon_ids() -> Array:
	var out: Array = []
	for key in _weapons:
		out.append(key)
	return out

## Retorna o id do primeiro weapon no registro (ex.: "wood_sword") para equip inicial.
func get_default_weapon_id() -> String:
	if _weapons.is_empty():
		return ""
	# Preferência: wood_sword > axe > pickaxe > qualquer
	for preferred in ["wood_sword", "axe", "pickaxe"]:
		if _weapons.has(preferred):
			return preferred
	return _weapons.keys()[0]
