# item.gd
# Recurso base para todos os itens do jogo.
# Herdar este script em: weapon.gd, tool_item.gd, resource_item.gd, etc.
#
# Como usar:
#   1. No editor, cria um novo Resource
#   2. Assing este script
#   3. Preenche os exports no Inspector
#   --------------------
#   Para criar um item novo rapidamente:
#   Duplica um .tres existente no editor e muda os valores — não precisa mexer em código.

class_name Item
extends Resource

# ================= ENUMS =================
enum Type {
	WEAPON,     # Espada, Maça, Machado (pode atacar)
	TOOL,       # Picareta, Machado (só mineração/utilidade)
	RESOURCE,   # Madeira, Ferro, Cristal, etc.
	CURRENCY,   # Moedas
	CONSUMABLE, # Poções, comida (futuro)
}

enum Rarity {
	COMMON,     # Tier 1 — verde
	UNCOMMON,   # Tier 2 — azul
	RARE,       # Tier 3 — roxo
}

# ================= EXPORTS =================
@export var item_name: String = ""
@export var item_icon: Texture2D                    # Ícone no inventário
@export var type: Type = Type.RESOURCE
@export var rarity: Rarity = Rarity.COMMON
@export var stack_size: int = 1                     # 1 = não empilha (armas), >1 = empilha (recursos)
@export var max_stack: int = 64                     # Máximo por pilha
@export var sell_value: int = 0                     # Valor em moedas ao vender (opcional)
@export var description: String = ""                # Descrição curta pra tooltip

# ================= FUNÇÕES UTILITÁRIAS =================

## Retorna a cor do rarity pra usar na UI
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:   return Color("#5a9c6a")   # verde
		Rarity.UNCOMMON: return Color("#5a8aaf")   # azul
		Rarity.RARE:     return Color("#8a6aaf")   # roxo
	return Color.WHITE

## Retorna o nome do rarity em texto
func get_rarity_label() -> String:
	match rarity:
		Rarity.COMMON:   return "Comum"
		Rarity.UNCOMMON: return "Incomum"
		Rarity.RARE:     return "Raro"
	return ""

## Verifica se o item pode empilhar
func is_stackable() -> bool:
	return max_stack > 1
