# enemy_drop.gd
# Attach no seu inimigo (ou chama via código quando ele morre).
# Gera drops no mundo: moedas e recursos.
#
# Como usar:
#   Opção A — Attach diretamente no inimigo e chama no death:
#       func _on_death():
#           $EnemyDrop.drop()
#
#   Opção B — Chama via código sem attach:
#       var drop_script = preload("res://scripts/enemy_drop.gd")
#       ... ou simplesmente instancia o pickup diretamente (veja abaixo)
#
# IMPORTANTE:
#   Você precisa criar uma Scene separada pra o pickup no mundo (pickup.tscn)
#   Essa scene vai ser instanciada aqui. Veja como criar no final do script.

extends Node3D

# ================= EXPORTS =================
# Scene do pickup que aparece no mundo quando o inimigo morre
@export var pickup_scene: PackedScene   # Arrasta pickup.tscn aqui no Inspector

# Moedas que esse inimigo dropa (mínimo e máximo — pega um valor aleatório)
@export var coins_min: int = 5
@export var coins_max: int = 15

# Chance de dropar um recurso além das moedas (0.0 a 1.0)
@export var resource_drop_chance: float = 0.5

# Recursos possíveis que esse inimigo pode dropar
# Cada entrada é um dicionário: { "item": Item (.tres), "weight": int }
# Weight define a probabilidade relativa entre os recursos
@export var possible_drops: Array = []

# ================= FUNÇÕES =================

## Executa o drop — chama isso quando o inimigo morre
func drop() -> void:
	if pickup_scene == null:
		push_warning("EnemyDrop: pickup_scene não assignado!")
		return

	var spawn_pos = get_parent().global_position

	# --- Sempre dropa moedas ---
	_spawn_pickup(spawn_pos, null, randf_range(coins_min, coins_max))

	# --- Chance de dropar recurso ---
	if randf() <= resource_drop_chance:
		var resource_item = _pick_random_drop()
		if resource_item != null:
			# Offset pequeno pra não empilhar no mesmo ponto das moedas
			var offset = Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
			_spawn_pickup(spawn_pos + offset, resource_item, 1)

## Instancia um pickup no mundo
## Se item for null, é moedas (amount = quantidade de moedas)
func _spawn_pickup(position: Vector3, item: Item, amount: int) -> void:
	var pickup = pickup_scene.instantiate()
	pickup.global_position = position 
	get_tree().current_scene.add_child(pickup)

	# Passa os dados pra o pickup via setup()
	if pickup.has_method("setup"):
		pickup.setup(item, amount)

## Escolhe um drop aleatório baseado nos pesos
func _pick_random_drop() -> Item:
	if possible_drops.is_empty():
		return null

	var total_weight = 0
	for drop in possible_drops:
		total_weight += drop["weight"]

	var roll = randi_range(1, total_weight)
	var cumulative = 0

	for drop in possible_drops:
		cumulative += drop["weight"]
		if roll <= cumulative:
			return drop["item"]

	return null
