extends Node3D
class_name AnimalSpawner

## Script de exemplo para spawner de animais
## Cole isso em um Node3D e salve como cena (ex: wolf_spawner.tscn)

@export var animal_scene: PackedScene
@export var max_animals: int = 5
@export var spawn_radius: float = 20.0
@export var spawn_cooldown: float = 30.0
@export var activation_distance: float = 50.0
@export var check_interval: float = 2.0

var alive_animals: int = 0
var cooldown_timer: float = 0.0
var check_timer: float = 0.0

func _ready():
	# Opcional: adicionar um marcador visual para debug
	var marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	marker.mesh = sphere
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.5, 0.0, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	
	add_child(marker)
	print("🐾 Spawner criado em: ", global_position)

func _process(delta):
	cooldown_timer -= delta
	check_timer -= delta
	
	if check_timer > 0:
		return
	
	check_timer = check_interval
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Spawnar animais quando jogador está próximo
	if distance < activation_distance:
		if cooldown_timer <= 0 and alive_animals < max_animals:
			spawn_animal()
			cooldown_timer = spawn_cooldown

func spawn_animal():
	if not animal_scene:
		push_error("⚠️ animal_scene não configurado no spawner!")
		return
	
	# Posição aleatória ao redor do spawner
	var angle = randf() * TAU
	var distance = randf_range(5.0, spawn_radius)
	var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
	
	var animal = animal_scene.instantiate()
	animal.global_position = global_position + offset
	
	# Ajustar altura ao terreno (se houver raycast)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		animal.global_position + Vector3(0, 10, 0),
		animal.global_position + Vector3(0, -50, 0)
	)
	var result = space_state.intersect_ray(query)
	
	if result:
		animal.global_position.y = result.position.y
	
	# Conectar sinal de morte
	if animal.has_signal("died"):
		animal.died.connect(_on_animal_died)
	elif animal.has_signal("tree_exited"):
		animal.tree_exited.connect(_on_animal_died)
	
	get_tree().root.add_child(animal)
	alive_animals += 1
	
	print("🐾 Animal spawned! Total vivo: ", alive_animals, "/", max_animals)

func _on_animal_died():
	alive_animals = max(0, alive_animals - 1)
	print("💀 Animal morreu. Total vivo: ", alive_animals, "/", max_animals)

# Desenhar área de spawn no editor
func _get_configuration_warnings():
	var warnings = []
	
	if not animal_scene:
		warnings.append("⚠️ Nenhuma cena de animal configurada!")
	
	return warnings
