extends Resource
class_name PropVariantSet

## Conjunto de variantes visuais (árvores, pedras, moitas, etc.).
## Use com PropWithVariants: ao iniciar, uma variante é escolhida ao acaso.

@export var variant_name: String = "Variante"
@export var variant_scenes: Array[PackedScene] = []

## Retorna uma cena aleatória da lista, ou null se vazia.
func get_random_variant() -> PackedScene:
	if variant_scenes.is_empty():
		return null
	return variant_scenes[randi() % variant_scenes.size()]

func has_variants() -> bool:
	return not variant_scenes.is_empty()
