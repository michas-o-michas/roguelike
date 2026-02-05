# weapon.gd
# Recurso de arma — herda de Item.
# Usado para: Espadas, Maças, Machados e Staffs.
#
# Como usar:
#   1. Cria um novo Resource no editor
#   2. Assign este script
#   3. Preenche os exports no Inspector
#   4. Salva como .tres (ex: iron_sword.tres)
#
# Exemplo de uso no código:
#   var sword = preload("res://items/iron_sword.tres")
#   print(sword.item_name)  # "Espada de Ferro"
#   print(sword.damage)     # 12

class_name Weapon
extends Item

# ================= ENUMS =================
enum WeaponType {
	MELEE,      # Corpo a corpo (Espada, Maça, Machado)
	RANGED,     # Rangeado (Staff)
}

enum AttackEffect {
	NONE,           # Sem efeito especial
	SPARKS,         # Partículas de faíscas (Espada de Aço)
	DARK_AURA,      # Aura negra + knockback (Espada de Obsidiana)
	STUN_SHORT,     # Stun 0.3s (Maça de Ferro)
	STUN_MEDIUM,    # Stun 0.6s (Maça de Pedra)
	STUN_LONG_AOE,  # Stun longo + shockwave AoE (Maça de Cristal)
	MINE_FAST,      # Mineração rápida (Machado de Ferro)
	MINE_VERY_FAST, # Mineração muito rápida + dano AoE pequeno (Machado de Aço)
	MINE_EXPLODE,   # Explosão ao mineração + dano AoE grande (Machado de Titanio)
}

enum ProjectileType {
	FIREBALL,       # Projétil básico (Staff de Madeira)
	RICOCHET,       # Projétil que ricochet 1x (Staff de Cristal)
	SPLIT,          # Projétil que se divide em 3 (Staff de Sombra)
}

# ================= EXPORTS =================
# -- Modelo visual --
@export var model_scene: PackedScene     # Scene que contém o modelo .glb da arma

# -- Tipo e comportamento --
@export var weapon_type: WeaponType = WeaponType.MELEE

# -- Dano e velocidade --
@export var damage: int = 10
@export var attack_speed: float = 0.6     # Tempo em segundos entre cada ataque

# -- Som --
@export var attack_sound: AudioStream   # Arrasta o .wav aqui no Inspector

# -- Efeito ao atacar --
@export var effect: AttackEffect = AttackEffect.NONE

# -- Projétil (só pra staffs/ranged) --
@export var projectile_scene: PackedScene   # Scene do projétil — deixa vazio se for melee
@export var projectile_type: ProjectileType = ProjectileType.FIREBALL
@export var projectile_speed: float = 20.0  # Velocidade do projétil

# -- Knockback (usado por alguns efeitos) --
@export var knockback_force: float = 0.0    # 0 = sem knockback

# ================= FUNÇÕES UTILITÁRIAS =================

## Retorna se essa arma pode mineração (Machados)
func can_mine() -> bool:
	return effect in [
		AttackEffect.MINE_FAST,
		AttackEffect.MINE_VERY_FAST,
		AttackEffect.MINE_EXPLODE,
	]

## Retorna se essa arma tem efeito de stun
func has_stun() -> bool:
	return effect in [
		AttackEffect.STUN_SHORT,
		AttackEffect.STUN_MEDIUM,
		AttackEffect.STUN_LONG_AOE,
	]

## Retorna a duração do stun baseado no efeito
func get_stun_duration() -> float:
	match effect:
		AttackEffect.STUN_SHORT:    return 0.3
		AttackEffect.STUN_MEDIUM:   return 0.6
		AttackEffect.STUN_LONG_AOE: return 1.0
	return 0.0

## Retorna se o ataque é AoE (área)
func is_aoe() -> bool:
	return effect in [
		AttackEffect.STUN_LONG_AOE,
		AttackEffect.MINE_VERY_FAST,
		AttackEffect.MINE_EXPLODE,
	]
