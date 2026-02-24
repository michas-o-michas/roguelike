# ProjectileLauncher.gd
# Dispara projéteis (staff/cajado) na direção do centro da tela.
# Filho do WeaponHandler; handler = get_parent().

extends Node

func _get_handler() -> Node:
	return get_parent()

## Dispara um projétil com a arma e magia atuais. Retorna true se disparou, false se falhou.
func launch() -> bool:
	var handler: Node = _get_handler()
	var weapon: Weapon = handler.get("equipped_weapon") as Weapon
	if not weapon:
		return false
	var spell: Spell = SpellManager.get_selected_spell() if SpellManager else null
	var proj_scene: PackedScene = weapon.projectile_scene
	if spell and spell.projectile_scene != null:
		proj_scene = spell.projectile_scene
	if proj_scene == null:
		push_warning("ProjectileLauncher: Staff sem projectile_scene assignada!")
		return false

	var projectile: Node = proj_scene.instantiate()
	handler.get_tree().current_scene.add_child(projectile)

	var player: Node = handler.get_parent()
	var cam: Node3D = handler.get("camera_node") as Node3D
	if not cam:
		cam = player.get_node_or_null("Camera3D") as Node3D
	if cam == null:
		push_warning("ProjectileLauncher: câmera não definida. Defina camera_node no WeaponHandler.")
		projectile.queue_free()
		return false

	var vp: Viewport = (cam as Camera3D).get_viewport()
	var center: Vector2 = vp.get_visible_rect().size / 2
	var direction: Vector3 = (cam as Camera3D).project_ray_normal(center).normalized()

	projectile.global_position = cam.global_position
	var ptype: int = weapon.projectile_type
	if spell:
		ptype = spell.projectile_type

	# Usa o dano e área da magia selecionada; cai de volta no dano da arma se sem magia.
	var actual_damage: int = int(spell.get_damage()) if spell else weapon.damage
	var area_radius: float  = spell.get_area()       if spell else 0.0

	if projectile.has_method("setup"):
		projectile.setup(direction, weapon.projectile_speed, actual_damage, ptype)
	if area_radius > 0.0 and projectile.has_method("set_area"):
		projectile.set_area(area_radius)
	return true
