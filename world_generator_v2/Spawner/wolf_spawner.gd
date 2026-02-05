extends Node3D

@export var animal_scene: PackedScene
@export var max_animals: int = 5
@export var spawn_radius: float = 20.0
@export var spawn_cooldown: float = 3.0
@export var activation_distance: float = 50.0

var alive_animals: int = 0
var cooldown_timer: float = 0.0

func _process(delta):
	cooldown_timer -= delta
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	if distance < activation_distance and cooldown_timer <= 0:
		if alive_animals < max_animals:
			spawn_animal()
			cooldown_timer = spawn_cooldown

func spawn_animal():
	var angle = randf() * TAU
	var distance = randf_range(5.0, spawn_radius)
	var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
	
	var animal = animal_scene.instantiate()
	animal.global_position = global_position + offset
	animal.tree_exited.connect(_on_animal_died)
	get_tree().root.add_child(animal)
	alive_animals += 1

func _on_animal_died():
	alive_animals -= 1
