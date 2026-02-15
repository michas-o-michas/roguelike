extends Resource
class_name SubBiomeItem

@export var item_name: String = "Sub-item"

@export_group("Spawn")
@export_range(0.0, 1.0) var spawn_chance: float = 0.5
@export_range(1, 20) var spawn_count: int = 1 ## Quantos sub-itens ao redor (ex: flores juntas)
@export var spawn_radius: float = 2.0
@export var height_offset: float = 0.05

@export_group("Escala")
@export var min_scale: float = 0.7
@export var max_scale: float = 1.3

@export_group("Variantes")
@export var variants: Array[ItemVariant] = []

@export_group("Descrição")
@export_multiline var description: String = "Ex: Cogumelos que crescem ao redor de árvores escuras"
