extends Label

@export var node_a: Node3D
@export var node_b: Node3D
@export var label: Label

func _process(delta):
	if node_a and node_b:
		var distancia_y = abs(node_a.global_position.y - node_b.global_position.y)

		label.text = "Distância Y: " + str(distancia_y)
