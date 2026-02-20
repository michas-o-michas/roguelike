# pickup.gd
# Usado pela cena pickup.tscn (drop de inimigos, etc.).
# Chame setup(item, amount) após instanciar: item = null = moedas, amount = qtd.

extends Area3D

var _item: Item = null
var _amount: int = 0

func setup(item: Item, amount: int) -> void:
	_item = item
	_amount = amount

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _item == null:
		InventoryManager.add_coins(_amount)
	else:
		InventoryManager.add_item(_item, _amount)
	queue_free()
