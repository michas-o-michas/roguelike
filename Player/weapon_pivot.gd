extends Node3D

func _process(delta):
	var rot = global_rotation
	global_rotation = Vector3(0, 0, rot.z)
