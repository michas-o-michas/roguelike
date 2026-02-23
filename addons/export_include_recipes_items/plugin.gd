@tool
extends EditorPlugin
## Registra o EditorExportPlugin que inclui Recipes/recipes.json e items/*.tres no exe.

var _export_plugin: EditorExportPlugin

func _enter_tree() -> void:
	_export_plugin = preload("res://addons/export_include_recipes_items/export_plugin.gd").new()
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	if _export_plugin:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
