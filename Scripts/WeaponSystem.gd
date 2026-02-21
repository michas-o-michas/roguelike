# WeaponSystem.gd
# Autoload: acesso a armas por id usando o registro do CraftingManager (uma única fonte).
#
# Uso:
#   WeaponSystem.get_weapon("wood_sword")
#   WeaponSystem.get_all_weapon_ids()
#   weapon_handler.equip(WeaponSystem.get_weapon("axe"))

extends Node

## Retorna o Weapon associado ao id. Retorna null se não existir ou não for Weapon.
func get_weapon(id: String) -> Weapon:
	if not CraftingManager:
		return null
	var item = CraftingManager.get_item_by_id(id)
	return item as Weapon if item is Weapon else null

## Retorna todos os ids de armas/ferramentas no item_registry.
func get_all_weapon_ids() -> Array:
	var out: Array = []
	if not CraftingManager:
		return out
	for id in CraftingManager.item_registry:
		if CraftingManager.item_registry[id] is Weapon:
			out.append(id)
	return out

## Id preferido para equip inicial (wood_sword > axe > pickaxe > primeiro disponível).
func get_default_weapon_id() -> String:
	var ids = get_all_weapon_ids()
	if ids.is_empty():
		return ""
	for preferred in ["wood_sword", "axe", "pickaxe"]:
		if preferred in ids:
			return preferred
	return ids[0]
