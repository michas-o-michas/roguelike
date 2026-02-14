extends CharacterBody3D

@onready var raycast = $Camera3D/RayCast3D
@onready var attack_point = $Camera3D/AttackPoint
@onready var magic_point = $Camera3D/MagicPoint
@onready var anim = $AnimationPlayer
@onready var audio = $AudioStreamPlayer3D

var equipped = "sword"
var can_attack := true


func try_attack():

	if not can_attack:
		return

	var weapon = WeaponSystem.get(equipped)
	if weapon == null:
		return

	can_attack = false

	match weapon.type:

		WeaponSystem.WeaponType.SWORD,WeaponSystem.WeaponType.MACE:
			melee_attack(weapon)

		WeaponSystem.WeaponType.STAFF:
			magic_attack(weapon)

	await get_tree().create_timer(1.0 / weapon.attack_speed).timeout
	can_attack = true


func melee_attack(weapon):

	play_animation_for(weapon)
	play_sound(weapon)

	if not raycast.is_colliding():
		return

	var collider = raycast.get_collider()

	if collider.has_method("take_damage"):
		collider.take_damage(weapon.damage)


func magic_attack(weapon):

	play_animation_for(weapon)
	play_sound(weapon)

	if weapon.projectile == null:
		return

	var spell = weapon.projectile.instantiate()
	get_tree().current_scene.add_child(spell)

	spell.global_position = magic_point.global_position
	spell.direction = -magic_point.global_transform.basis.z
	spell.damage = weapon.damage


func play_animation_for(weapon):
	var player = get_parent()
	if player.has_method("play_attack_animation"):
		match weapon.type:
			WeaponSystem.WeaponType.SWORD, WeaponSystem.WeaponType.MACE:
				player.play_attack_animation("Slash")
			WeaponSystem.WeaponType.STAFF:
				player.play_attack_animation("Cast")
			_:
				player.play_attack_animation("Slash")
	else:
		match weapon.type:
			WeaponSystem.WeaponType.SWORD:
				anim.play("attack_sword")
			WeaponSystem.WeaponType.MACE:
				anim.play("attack_mace")
			WeaponSystem.WeaponType.STAFF:
				anim.play("cast_magic")
			_:
				anim.play("attack_default")


func play_sound(weapon):

	if weapon.sound:
		audio.stream = weapon.sound
		audio.play()


func _input(event):

	if event.is_action_pressed("attack"):
		try_attack()

	if event.is_action_pressed("ui_select"):
		equip("sword")

	if event.is_action_pressed("ui_focus_next"):
		equip("staff")


func equip(id):
	equipped = id
	print("Equipado:", id)
