extends Resource
class_name BiomeItem

@export var item_name: String = "Item"
@export_group("Spawn")
@export_range(0.0, 1.0) var spawn_chance: float = 0.3
@export var min_scale: float = 0.8
@export var max_scale: float = 1.4

@export_group("Variantes")
@export var variants: Array[ItemVariant] = []

@export_group("Sub-itens (Decoração ao redor)")
@export var sub_items: Array[SubBiomeItem] = []

@export_group("Descrição")
@export_multiline var description: String = "Ex: Árvore de carvalho, Pedra de ferro"
