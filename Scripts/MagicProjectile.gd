# MagicProjectile.gd
# Projétil mágico do cajado. Chamado pelo WeaponHandler com setup(direction, speed, damage, projectile_type).
# Colide com inimigos (dano) e com o mundo (desaparece).

extends Area3D

var _direction: Vector3 = Vector3.ZERO
var _speed: float = 20.0
var _damage: int = 10
var _projectile_type: int = 0  # Weapon.ProjectileType (FIREBALL, RICOCHET, SPLIT)
var _max_lifetime: float = 5.0
var _lifetime: float = 0.0

## Chamado pelo WeaponHandler ao instanciar. direction e speed em unidades do mundo.
func setup(direction: Vector3, speed: float, damage: int, projectile_type: int) -> void:
	_direction = direction.normalized()
	_speed = speed
	_damage = damage
	_projectile_type = projectile_type


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Não acertar o jogador (evita auto-dano se máscara incluir player)
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
	# Inimigo: aplicar dano (passar jogador como attacker para aggro)
	if body.is_in_group("enemy") or body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			var player: Node = get_tree().get_first_node_in_group("player")
			body.take_damage(float(_damage), player)
	# Qualquer outro corpo (parede, chão): destruir projétil
	queue_free()
