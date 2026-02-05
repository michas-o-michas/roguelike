extends Resource
class_name ItemVariant

enum Rarity {
	COMMON,      # 10.0 de peso (muito comum)
	UNCOMMON,    # 5.0 de peso
	RARE,        # 2.0 de peso
	EPIC,        # 0.5 de peso
	LEGENDARY    # 0.1 de peso (muito raro)
}

@export var variant_name: String = "Variante"
@export var scene: PackedScene
@export var rarity: Rarity = Rarity.COMMON
@export_multiline var description: String = ""
