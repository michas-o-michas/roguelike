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

# ── Sistema de upgrade ─────────────────────────────────────────────────────────

## Dano base do feitiço. Sobrescreve weapon.damage quando equipado.
@export var base_damage: float = 20.0
## Raio de splash em metros ao acertar (0 = sem AOE).
@export var area_radius: float = 0.0
## Nível de upgrade atual (0 = recém-desbloqueado).
@export var upgrade_level: int = 0

## Dano adicional por nível de upgrade.
@export var damage_per_upgrade: float = 8.0
## Metros de raio AOE adicionais por nível de upgrade.
@export var area_per_upgrade: float = 0.5
## Segundos de cooldown reduzidos por nível de upgrade.
@export var cooldown_reduction_per_upgrade: float = 0.05

# ── Getters computados ─────────────────────────────────────────────────────────

func get_damage() -> float:
	return base_damage + damage_per_upgrade * upgrade_level

func get_area() -> float:
	return area_radius + area_per_upgrade * upgrade_level

func get_effective_cooldown() -> float:
	return maxf(0.3, cooldown - cooldown_reduction_per_upgrade * upgrade_level)

func get_level_text() -> String:
	if upgrade_level == 0:
		return spell_name
	return "%s [Nv.%d]" % [spell_name, upgrade_level + 1]
