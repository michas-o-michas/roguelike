extends Node
class_name HealthComponent

signal health_changed(old_value: float, new_value: float)
signal health_depleted()
signal damage_taken(amount: float)
signal healed(amount: float)
signal died()
signal invincibility_changed(is_invincible: bool)

@export_group("Configuração Básica")
@export var max_health: float = 100.0
@export var start_with_max: bool = true
@export var auto_destroy_on_death: bool = false
@export var destroy_delay: float = 3.0

@export_group("Defesa")
@export var defense: float = 0.0
@export var armor_piercing_resistance: float = 0.0

@export_group("Status")
@export var is_invincible: bool = false
@export var can_take_damage: bool = true
@export var can_be_healed: bool = true


# IMPORTANTE: setter para reagir a mudanças no inspector
@export var current_health: float:
	set(value):
		var old = current_health
		current_health = clamp(value, 0, max_health)

		if Engine.is_editor_hint():
			# No editor, só atualiza sem lógica de morte
			health_changed.emit(old, current_health)
		else:
			if old != current_health:
				health_changed.emit(old, current_health)

			if current_health <= 0 and not is_dead:
				die()


var is_dead: bool = false


func _ready():
	if start_with_max:
		current_health = max_health
	else:
		current_health = clamp(current_health, 0, max_health)

	# Emitir estado inicial correto
	health_changed.emit(current_health, current_health)


func take_damage(amount: float, armor_piercing: float = 0.0, attacker: Node = null) -> float:
	if is_dead or not can_take_damage or is_invincible:
		return 0.0

	var piercing_damage = amount * armor_piercing
	var regular_damage = amount * (1.0 - armor_piercing)

	piercing_damage *= (1.0 - armor_piercing_resistance)
	regular_damage = max(regular_damage - defense, 0.0)

	var total_damage = piercing_damage + regular_damage

	if total_damage > 0 and total_damage < 1:
		total_damage = 1.0

	var old_health = current_health
	current_health = max(current_health - total_damage, 0.0)

	health_changed.emit(old_health, current_health)
	damage_taken.emit(total_damage)

	if current_health <= 0 and not is_dead:
		die()

	return total_damage


func heal(amount: float) -> float:
	if is_dead or not can_be_healed:
		return 0.0

	var old_health = current_health
	var actual_heal = min(amount, max_health - current_health)

	if actual_heal > 0:
		current_health += actual_heal
		health_changed.emit(old_health, current_health)
		healed.emit(actual_heal)

	return actual_heal


func die():
	if is_dead:
		return

	is_dead = true
	died.emit()

	if auto_destroy_on_death:
		var parent = get_parent()
		if parent:
			await get_tree().create_timer(destroy_delay).timeout
			parent.queue_free()



func get_health_percentage() -> float:
	return current_health / max_health


func is_alive() -> bool:
	return not is_dead and current_health > 0
