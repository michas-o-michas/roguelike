extends StaticBody3D
class_name ResourceNode

@export var max_health := 5
@export var resource_id := "wood"
@export var drop_amount := 1

var health

func _ready():
	health = max_health

func take_hit(damage):
	health -= damage
	scale *= 0.95
	print(resource_id, " tomou dano:", damage, " vida restante:", health)
	if health <= 0:
		die()

func die():
	InventoryManager.add_item_by_id(resource_id, drop_amount)
	queue_free()
