extends Node
## Autoload: registro de mobs por ID e por tier.
## Carrega todos os .tres de res://data/mobs/ no _ready.
##
## Configurar em Project > Project Settings > Autoload:
##   Name: MobRegistry
##   Path: res://Scripts/enemies/mob_registry.gd

var _mobs_by_id: Dictionary = {}  ## id (String) -> MobData
var _mobs_by_tier: Dictionary = {}  ## tier (int) -> Array[MobData]

const MOBS_FOLDER := "res://data/mobs/"

func _ready() -> void:
	_register_mobs_from_folder(MOBS_FOLDER)

func _register_mobs_from_folder(folder_path: String) -> void:
	var dir = DirAccess.open(folder_path)
	if not dir:
		push_warning("MobRegistry: pasta não encontrada: %s" % folder_path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path = folder_path + file_name
			var res = load(full_path) as MobData
			if res:
				var key = res.id if res.id != "" else file_name.get_basename()
				_mobs_by_id[key] = res
				if not _mobs_by_tier.has(res.difficulty_tier):
					_mobs_by_tier[res.difficulty_tier] = []
				_mobs_by_tier[res.difficulty_tier].append(res)
		file_name = dir.get_next()
	dir.list_dir_end()

## Retorna o MobData pelo id. Retorna null se não existir.
func get_mob(id: String) -> MobData:
	return _mobs_by_id.get(id, null)

## Retorna todos os mobs do tier (e opcionalmente tiers inferiores).
func get_mobs_by_tier(tier: int, include_lower_tiers: bool = false) -> Array:
	var out: Array[MobData] = []
	if include_lower_tiers:
		for t in _mobs_by_tier:
			if int(t) <= tier:
				for m in _mobs_by_tier[t]:
					out.append(m)
	else:
		if _mobs_by_tier.has(tier):
			for m in _mobs_by_tier[tier]:
				out.append(m)
	return out

## Retorna todos os IDs registrados
func get_all_mob_ids() -> Array:
	var ids: Array = []
	for k in _mobs_by_id:
		ids.append(k)
	return ids
