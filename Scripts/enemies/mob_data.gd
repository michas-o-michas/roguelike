extends Resource
class_name MobData

## "Receita" do mob: define qual cena instanciar + stats + comportamento.
## Usado pelo SPAWNER (wolf_spawner, etc.), não pela cena do mob. O spawner instancia mob_scene e chama set_mob_data(this).

## Identificador único (ex.: "wolf", "cow", "zombie")
@export var id: String = ""

## Nome exibido (UI, debug)
@export var display_name: String = ""

## Cena do mob a instanciar (ex.: wolf.tscn, cow.tscn). O spawner instancia isso e seta este MobData.
@export var mob_scene: PackedScene

enum AttackType {
	MELEE,   ## Ataque corpo a corpo (padrão)
	RANGED  ## Atira de longe — use cena com script que dispare projéteis (ex.: estender mob_base)
}

enum Behaviour {
	PASSIVE,           ## Não ataca; pode fugir ou ignorar
	AGGRESSIVE,        ## Persegue e ataca ao detectar
	PASSIVE_AGGRESSIVE,## Ataca só se for atacado ou jogador muito próximo
	NEUTRAL            ## Ataca só se atacado, sem perseguir longe
}

## Comportamento da AI
@export var behaviour: Behaviour = Behaviour.AGGRESSIVE

## Tipo de ataque: MELEE = perto (padrão), RANGED = atira de longe (implementar cena com lógica de projétil).
@export var attack_type: AttackType = AttackType.MELEE

## Stats aplicados quando o mob é criado
@export var max_health: float = 50.0
@export var damage: float = 10.0
@export var defense: float = 0.0
@export var speed: float = 5.0
## Raio de detecção (0 = usar padrão da cena). ~30+ para spawners longe.
@export var detection_radius: float = 0.0
@export var attack_radius: float = 0.0
@export var attack_cooldown: float = 0.0
## NEUTRAL: raio máximo de perseguição quando provocado (0 = usar padrão da cena, ex. 12).
@export var neutral_chase_radius: float = 0.0
@export var armor_piercing: float = 0.0

@export var loot_table_id: String = ""
@export_range(1, 10) var difficulty_tier: int = 1

## Animações: só se a cena usar nós com outro nome (ex.: "SharedAnim/AnimationTree").
@export var animation_tree_path_override: NodePath = NodePath("")
@export var animation_player_path_override: NodePath = NodePath("")

func is_hostile() -> bool:
	return (
		behaviour == Behaviour.AGGRESSIVE
		or behaviour == Behaviour.PASSIVE_AGGRESSIVE
		or behaviour == Behaviour.NEUTRAL
	)
