extends Node
class_name SkillManager

# Listas de skills por raridade
@export var common_skills: Array[Skill] = []
@export var rare_skills: Array[Skill] = []
@export var epic_skills: Array[Skill] = []

# Aplica skill no player (usa HealthComponent quando disponível)
func apply_skill(player, skill: Skill) -> void:
	var health_comp: HealthComponent = player.get_health_component() if player.has_method("get_health_component") else null

	# Movimento e combate
	if skill.stackable:
		player.speed += skill.bonus_speed
		player.damage += skill.bonus_damage
		player.attack_speed += skill.bonus_attack_speed
		player.max_jumps += int(skill.bonus_jumps)
	else:
		player.speed = maxf(player.speed, player.base_speed + skill.bonus_speed)
		player.damage = maxi(player.damage, player.base_damage + skill.bonus_damage)
		player.attack_speed = maxf(player.attack_speed, player.base_attack_speed + skill.bonus_attack_speed)
		player.max_jumps = maxi(player.max_jumps, player.base_max_jumps + int(skill.bonus_jumps))

	# Vida: apenas via HealthComponent
	if health_comp:
		if skill.stackable:
			var extra := skill.bonus_health + int(health_comp.max_health * skill.bonus_health_percent / 100.0)
			health_comp.max_health += extra
			health_comp.current_health = minf(health_comp.current_health + extra, health_comp.max_health)
		else:
			var new_max := maxf(health_comp.max_health, player.base_health + skill.bonus_health)
			new_max = maxf(new_max, player.base_health * (1.0 + skill.bonus_health_percent / 100.0))
			health_comp.max_health = new_max
			health_comp.current_health = clampf(health_comp.current_health, 0, health_comp.max_health)

	player.apply_skill(skill)
