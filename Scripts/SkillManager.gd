extends Node
class_name SkillManager

# Listas de skills por raridade
@export var common_skills: Array[Skill] = []
@export var rare_skills: Array[Skill] = []
@export var epic_skills: Array[Skill] = []

# Aplica skill no player
func apply_skill(player, skill: Skill) -> void:
	if skill.stackable:
		player.speed += skill.bonus_speed
		player.health += skill.bonus_health
		player.damage += skill.bonus_damage
		player.attack_speed += skill.bonus_attack_speed
		player.health += int(player.base_health * skill.bonus_health_percent / 100)
		player.max_jumps += skill.bonus_jumps
		
	else:
		player.speed = max(player.speed, player.base_speed + skill.bonus_speed)
		player.health = max(player.health, player.base_health + skill.bonus_health)
		player.damage = max(player.damage, player.base_damage + skill.bonus_damage)
		player.attack_speed = max(player.attack_speed, player.base_attack_speed + skill.bonus_attack_speed)
		player.health = max(player.health, int(player.base_health * (1 + skill.bonus_health_percent / 100)))
		player.max_jumps =  max(player.max_jumps, player.max_jumps +  skill.bonus_jumps)
	player.apply_skill(skill)
