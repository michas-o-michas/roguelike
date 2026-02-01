extends Control
class_name SkillsHUD

@export var skill_icon_scene: PackedScene   # referencie aqui o SkillIcon.tscn
@onready var grid: GridContainer = $SkillGrid

var skill_containers: Dictionary = {}  # guarda key -> SkillIcon instanciado

func update_skills(player):
	# Contar stacks considerando se é stackable ou não
	var skill_count := {}
	for s in player.skills:
		if not s.stackable and s.name in skill_count:
			# skill não empilhável, já existe, ignora
			continue
		
		if s.name in skill_count:
			skill_count[s.name]["count"] += 1
		else:
			skill_count[s.name] = {"skill": s, "count": 1}

	# Atualizar ou criar ícones
	for key in skill_count.keys():
		var data = skill_count[key]
		var skill: Skill = data.skill
		var count: int = data.count

		if key in skill_containers:
			# Atualiza apenas o Label
			var icon = skill_containers[key]
			var label = icon.get_node("Label")
			if label:
				label.text = str(count) if count > 1 else ""
		else:
			# Instancia SkillIcon.tscn
			var icon = skill_icon_scene.instantiate()
			icon.get_node("TextureRect").texture = skill.icon
			icon.get_node("Label").text = str(count) if count > 1 else ""
			grid.add_child(icon)
			skill_containers[key] = icon

	# Remover skills que o player perdeu (caso tenha)
	for key in skill_containers.keys():
		if not skill_count.has(key):
			skill_containers[key].queue_free()
			skill_containers.erase(key)
