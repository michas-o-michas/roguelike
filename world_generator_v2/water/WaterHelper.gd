# WaterHelper.gd
# Cria o plano de água e colisão. Usado por InfiniteWorldGenerator.

class_name WaterHelper

static func create_water(world_gen: InfiniteWorldGenerator) -> MeshInstance3D:
	if world_gen.world_theme and world_gen.world_theme.liquid_type == WorldTheme.LiquidType.NONE:
		return null

	var water_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(world_gen.water_size, world_gen.water_size)
	plane.subdivide_width = 50
	plane.subdivide_depth = 50
	water_mesh.mesh = plane

	var liquid_level := world_gen.water_level
	if world_gen.world_theme and world_gen.world_theme.use_custom_levels:
		liquid_level = world_gen.world_theme.custom_water_level
	const WATER_VISUAL_OFFSET := 0.12
	water_mesh.position = Vector3(0.0, liquid_level + WATER_VISUAL_OFFSET, 0.0)

	var water_mat: Material = null
	if world_gen.world_theme and "water_material" in world_gen.world_theme and world_gen.world_theme.water_material:
		water_mat = world_gen.world_theme.water_material
	else:
		water_mat = load("res://materials/Water.tres") as Material
	if water_mat:
		water_mesh.material_override = water_mat
	else:
		push_warning("Material res://materials/Water.tres não encontrado; água sem aparência.")
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_gen.add_child(water_mesh)

	var water_body := StaticBody3D.new()
	var water_collision := CollisionShape3D.new()
	var water_shape := BoxShape3D.new()
	water_shape.size = Vector3(world_gen.water_size, 0.5, world_gen.water_size)
	water_collision.shape = water_shape
	water_collision.position.y = liquid_level - 0.25
	water_body.add_child(water_collision)
	world_gen.add_child(water_body)

	return water_mesh


static func get_liquid_name(type: WorldTheme.LiquidType) -> String:
	match type:
		WorldTheme.LiquidType.WATER: return "Água"
		WorldTheme.LiquidType.LAVA: return "Lava"
		WorldTheme.LiquidType.ACID: return "Ácido"
		WorldTheme.LiquidType.OIL: return "Óleo"
		WorldTheme.LiquidType.BLOOD: return "Sangue"
		WorldTheme.LiquidType.CRYSTAL: return "Cristal Líquido"
		_: return "Desconhecido"
