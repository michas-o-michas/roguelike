extends Resource
class_name Skill

@export var name: String = "Nova Skill"
@export var description: String = ""
@export var icon: Texture2D

enum SkillType { PASSIVE, ACTIVE }
@export var skill_type: SkillType = SkillType.PASSIVE

# Buffs
@export var bonus_speed: float = 0.0
@export var bonus_health: int = 0
@export var bonus_health_percent: float = 0.0
@export var bonus_damage: int = 0
@export var bonus_attack_speed: float = 0.0
@export var bonus_jumps: float = 0.0


# Acumulativo ou não
@export var stackable: bool = true
