@tool
extends EditorExportPlugin
## Adiciona ao PCK, na exportação, os arquivos que o Godot não inclui por padrão:
## - res://Recipes/recipes.json
## - res://items/*.tres
## Ative o addon "Export: Incluir Recipes e Items" em Projeto > Projeto > Plugins.

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	_add_file_if_exists("res://Recipes/recipes.json")
	var dir := DirAccess.open("res://items/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				_add_file_if_exists("res://items/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

func _add_file_if_exists(res_path: String) -> void:
	var f := FileAccess.open(res_path, FileAccess.READ)
	if not f:
		push_warning("Export: arquivo não encontrado: %s" % res_path)
		return
	var data := f.get_buffer(f.get_length())
	f.close()
	add_file(res_path, data, false)
	print("Export: incluído %s" % res_path)
