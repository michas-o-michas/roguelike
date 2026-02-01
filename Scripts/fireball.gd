extends Node3D

@export var speed := 20.0
var damage := 0
var direction: Vector3 = Vector3.ZERO


func _physics_process(delta):
	if direction != Vector3.ZERO:
		translate(direction.normalized() * speed * delta)


func _on_body_entered(body):

	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
