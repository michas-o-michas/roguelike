extends Node3D

@export var trees: Array[MeshInstance3D]
@export var colors: Array[Color] = [Color.LIME_GREEN]

func _enter_tree() -> void:
	var color = colors[randi_range(0,colors.size() - 1)]
	var material =  StandardMaterial3D.new()
	material.albedo_color = color
	for tree:MeshInstance3D in trees:
		tree.material_override = material
	
