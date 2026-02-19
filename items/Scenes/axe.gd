extends Node3D
@onready var skeleton: Skeleton3D = %Skeleton
var bone_idx: int

func _ready():
	bone_idx = skeleton.find_bone("RightHand") # coloque o nome exato

func _process(delta):
	var pose = skeleton.get_bone_global_pose(bone_idx)

	# Mantém a posição
	var new_transform = pose
	new_transform.basis = Basis() # zera rotação

	skeleton.set_bone_global_pose_override(
		bone_idx,
		new_transform,
		1.0,
		true
	)
