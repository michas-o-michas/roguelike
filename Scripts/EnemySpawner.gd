extends Node

@export var enemy_scene: PackedScene
@export var day_night_system: Node

var wave := 1

func _ready():
	day_night_system.night_started.connect(spawn_wave)

func spawn_wave():
	print("NOITE...")
	for i in range(3 + wave):
		var e = enemy_scene.instantiate()
		e.position = Vector3(randf_range(-40,40), 0, randf_range(-40,40))
		add_child(e)

	wave += 1
