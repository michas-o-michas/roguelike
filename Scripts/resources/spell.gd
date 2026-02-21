# spell.gd
# Recurso de magia para a hotbar do cajado.
# Criar .tres no editor e registrar no SpellManager.

class_name Spell
extends Resource

@export var id: String = ""
@export var spell_name: String = ""
@export var icon: Texture2D
@export var cooldown: float = 1.0
## Tipo de projétil (usa Weapon.ProjectileType para compatibilidade com staff)
@export var projectile_type: int = 0  # Weapon.ProjectileType.FIREBALL
## Cena do projétil (opcional; se vazio, usa o do staff com projectile_type)
@export var projectile_scene: PackedScene
