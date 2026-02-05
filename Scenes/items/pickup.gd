# pickup.gd
# Scene do pickup no mundo — o item que aparece quando inimigo morre.
#
# Como criar a Scene (pickup.tscn):
#   1. Nova Scene > Node raiz: Area3D
#   2. Filho: CollisionShape3D (SphereShape3D, raio 0.8)
#   3. Filho: MeshInstance3D (esfera pequena — placeholder visual)
#   4. Assign este script no Area3D
#   5. No Inspector do Area3D: marca "Monitorable" e "Monitoring"
#   6. Salva como pickup.tscn

extends Area3D

# ================= EXPORTS =================
@export var magnet_radius: float = 4.0      # Distância pra começar a ser atraído pelo player
@export var magnet_speed: float = 8.0       # Velocidade de atração
@export var collect_radius: float = 0.6     # Distância pra ser coletado automaticamente
@export var bob_speed: float = 3.0          # Velocidade do movimento up/down (flutuar)
@export var bob_height: float = 0.15        # Altura do movimento de flutuar

# ================= ESTADO =================
var item: Item = null       # O item que esse pickup representa (null = moedas)
var amount: int = 0         # Quantidade (moedas ou recursos)
var player: Node3D = null   # Referência ao player quando entra no raio
var start_y: float = 0.0    # Posição Y inicial (pra o bob)
var bob_timer: float = 0.0  # Timer do movimento de flutuar

# ================= INICIALIZAÇÃO =================
func _ready():
	# Conecta o sinal de corpo entrando na área
	body_entered.connect(_on_body_entered)
	start_y = global_position.y
	print(start_y)

## Recebe os dados do drop (chamado pelo enemy_drop.gd)
func setup(drop_item: Item, drop_amount: int) -> void:
	item = drop_item
	amount = drop_amount

# ================= PROCESSO =================
func _process(delta):
	bob_timer += delta
	# Movimento de flutuar (bob up/down)
	global_position.y = start_y + sin(bob_timer * bob_speed) * bob_height

	# Se o player tá perto, atrai em direção a ele
	if player != null:
		var dir = (player.global_position - global_position).normalized()
		var dist = global_position.distance_to(player.global_position)

		# Dentro do raio de coleta automática — coleta
		if dist <= collect_radius:
			_collect()
			return

		# Dentro do raio de magnet — move em direção ao player
		if dist <= magnet_radius:
			global_position += dir * magnet_speed * delta

# ================= DETECÇÃO =================

## Quando algo entra na área do pickup
func _on_body_entered(body: Node3D) -> void:
	# Só se for o player
	if body.is_in_group("player"):
		player = body

# ================= COLETA =================

## Coleta o pickup e adiciona ao InventoryManager
func _collect() -> void:
	if item == null:
		# É moedas
		InventoryManager.add_coins(amount)
	else:
		# É um recurso
		InventoryManager.add_item(item, amount)

	queue_free()
