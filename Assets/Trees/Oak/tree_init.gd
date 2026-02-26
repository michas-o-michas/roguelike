extends StaticBody3D

@onready var trees: Array[MeshInstance3D]
@export var colors: Array[Color] = [Color.LIME_GREEN]

func _ready() -> void:
	var color = colors[randi_range(0,colors.size() - 1)]
	var material =  StandardMaterial3D.new()
	material.albedo_color = color
	for tree:MeshInstance3D in trees:
		tree.set_surface_override_material(1, material)
	
