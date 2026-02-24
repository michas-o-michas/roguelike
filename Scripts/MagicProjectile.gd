# MagicProjectile.gd
# Projétil mágico do cajado. Chamado pelo WeaponHandler com setup(direction, speed, damage, projectile_type).
# Colide com inimigos (dano direto + AOE splash se area_radius > 0) e com o mundo (desaparece).

extends Area3D

var _direction: Vector3 = Vector3.ZERO
var _speed: float = 20.0
var _damage: int = 10
var _projectile_type: int = 0  # Weapon.ProjectileType (FIREBALL, RICOCHET, SPLIT)
var _max_lifetime: float = 5.0
var _lifetime: float = 0.0
var _area_radius: float = 0.0  ## 0 = sem splash; >0 = dano em área ao impactar


## Chamado pelo ProjectileLauncher ao instanciar.
func setup(direction: Vector3, speed: float, damage: int, projectile_type: int) -> void:
	_direction = direction.normalized()
	_speed = speed
	_damage = damage
	_projectile_type = projectile_type


## Define o raio de splash AOE (opcional, chamado após setup se a magia tiver área).
func set_area(radius: float) -> void:
	_area_radius = radius


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_mask = 1  # Ajuste se seus inimigos estiverem em outra layer


func _physics_process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= _max_lifetime:
		queue_free()
		return
	global_position += _direction * _speed * delta


func _on_body_entered(body: Node3D) -> void:
	if not is_instance_valid(body):
		queue_free()
		return
	# Ignorar jogador (evita auto-dano)
	if body.is_in_group("player"):
		return
	# Inimigo direto: dano completo
	if body.is_in_group("enemy") or body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			var player: Node = get_tree().get_first_node_in_group("player")
			body.take_damage(float(_damage), player)
	# AOE splash: acerta inimigos próximos com 60% do dano
	if _area_radius > 0.0:
		_do_area_damage(global_position, body)
	queue_free()


func _do_area_damage(center: Vector3, direct_hit: Node3D) -> void:
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = _area_radius
	params.shape = shape
	params.transform = Transform3D(Basis(), center)
	params.collision_mask = collision_mask
	var results := space.intersect_shape(params, 16)
	var player: Node = get_tree().get_first_node_in_group("player")
	for result: Dictionary in results:
		var hit: Object = result.get("collider")
		if not hit or not is_instance_valid(hit):
			continue
		if hit == direct_hit:
			continue  # já recebeu dano direto completo
		if hit.is_in_group("player"):
			continue
		if (hit.is_in_group("enemy") or hit.is_in_group("enemies")) and hit.has_method("take_damage"):
			hit.take_damage(float(_damage) * 0.6, player)
