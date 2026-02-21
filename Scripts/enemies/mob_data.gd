extends Resource
class_name MobData

## Identificador único do mob (ex.: "wolf", "rabbit")
@export var id: String = ""

## Nome exibido (UI, debug)
@export var display_name: String = ""

## Cena do mob (CharacterBody3D com HealthComponent e mob_base.gd)
@export var mob_scene: PackedScene

## Tipo de comportamento da AI
@export var behaviour: Behaviour = Behaviour.AGGRESSIVE

## Stats aplicados no _ready do mob
@export var max_health: float = 50.0
@export var damage: float = 10.0
@export var defense: float = 0.0
@export var speed: float = 5.0
## Raio de detecção do jogador (0 = usar o padrão da cena do mob). Use ~30+ pois spawners ficam longe.
@export var detection_radius: float = 0.0

## ID da tabela de loot (opcional, para loot futuro)
@export var loot_table_id: String = ""

## Tier de dificuldade (1-10), alinhado ao AnimalSpawnerData
@export_range(1, 10) var difficulty_tier: int = 1

enum Behaviour {
	PASSIVE,           ## Não ataca; pode fugir ou ignorar
	AGGRESSIVE,        ## Persegue e ataca ao detectar
	PASSIVE_AGGRESSIVE,## Ataca só se for atacado ou jogador muito próximo
	NEUTRAL            ## Ataca só se atacado, sem perseguir longe
}

func is_hostile() -> bool:
	return (
		behaviour == Behaviour.AGGRESSIVE
		or behaviour == Behaviour.PASSIVE_AGGRESSIVE
		or behaviour == Behaviour.NEUTRAL
	)
