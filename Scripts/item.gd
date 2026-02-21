# item.gd
# Recurso base para todos os itens do jogo.
# Herdar este script em: weapon.gd (espada, cajado, machado, picareta), resource_item.gd, etc.
#
# Regra do jogo: só existem 4 itens equipáveis (slots fixos) — Espada, Cajado, Machado, Picareta.
# Todos são recurso Weapon com equipment_slot (MELEE, STAFF, AXE, PICKAXE). O resto é consumível,
# recurso de crafting ou moeda.

class_name Item
extends Resource

# ================= ENUMS =================
enum Type {
	WEAPON,     # Equipável em um dos 4 slots (só recurso Weapon: espada, cajado, machado, picareta)
	RESOURCE,   # Madeira, pedra, ferro, etc. (crafting, não equipável)
	CURRENCY,   # Moedas
	CONSUMABLE, # Poções, comida — uso rápido (hotbar), não equipável
	TOOL        # Obsoleto: use Weapon com AXE/PICKAXE. Mantido para .tres antigos.
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

## Retorna true apenas para itens que podem ir nos 4 slots de equipamento (Espada, Cajado, Machado, Picareta).
## Em Item retorna false; Weapon sobrescreve e retorna true.
func can_go_in_equipment_slot() -> bool:
	return false
