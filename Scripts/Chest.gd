extends Node3D

enum Rarity { COMMON, RARE, EPIC }
@export var rarity: Rarity = Rarity.COMMON

# Custo para abrir o baú
@export var cost: int = 5

# Referência ao SkillManager na cena (NodePath)
@export var skill_manager_path: NodePath

var opened := false

func open(player):
	if opened:
		print('opened',opened)
		return

	# Verifica se o player tem moedas suficientes (via InventoryManager)
	if InventoryManager.get_coins() < cost:
		print("Você não tem moedas suficientes!")
		return

	if not InventoryManager.spend_coins(cost):
		return
	print("Baú aberto! Moedas gastas:", cost)

	# Pega o SkillManager da cena
	var manager: SkillManager = get_node(skill_manager_path)
	print(skill_manager_path)
	if manager == null:
		print("SkillManager não encontrado!")
		return

	var pool: Array[Skill] = []
	match rarity:
		Rarity.COMMON:
			pool = manager.common_skills
		Rarity.RARE:
			pool = manager.rare_skills
		Rarity.EPIC:
			pool = manager.epic_skills

	print(pool.size())

	if pool.size()<=0:
		print("Nenhuma skill disponível para esta raridade!")
		queue_free()
		return

	# Escolhe 3 skills aleatórias do pool
	var options: Array[Skill] = []
	for i in range(3):
		options.append(pool[randi() % pool.size()])

	# Seleciona uma skill (ou a primeira para teste)
	var selected: Skill = options[0]
	
	manager.apply_skill(player, selected)
	print("Skill adquirida:", selected.name)

	opened = true
	queue_free()
