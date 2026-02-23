# StatsManager.gd
# Autoload — pontos para distribuir, compra com moedas, bônus por atributo.
# Registrar em Project Settings > Autoload como "StatsManager".

extends Node

# ================= SINAIS =================
signal points_changed(points: int)
signal stats_changed()

# ================= IDs DOS ATRIBUTOS =================
enum Stat {
	HEALTH,      # Vida máxima
	DAMAGE,      # Dano base
	SPEED,       # Velocidade de movimento
	JUMPS,       # Pulos extras
	DEFENSE,     # Redução de dano
	ATTACK_SPEED # Velocidade de ataque
}

# Nomes para exibição na UI
const STAT_NAMES: Dictionary = {
	Stat.HEALTH: "Vida",
	Stat.DAMAGE: "Dano",
	Stat.SPEED: "Velocidade",
	Stat.JUMPS: "Pulos",
	Stat.DEFENSE: "Defesa",
	Stat.ATTACK_SPEED: "Vel. Ataque"
}

# Quanto cada nível adiciona ao valor base (valor por ponto gasto)
const BONUS_PER_LEVEL: Dictionary = {
	Stat.HEALTH: 10.0,
	Stat.DAMAGE: 2,
	Stat.SPEED: 0.5,
	Stat.JUMPS: 1,
	Stat.DEFENSE: 2.0,
	Stat.ATTACK_SPEED: 0.05
}

# ================= CONFIGURAÇÃO =================
## Pontos livres para distribuir (ganhos por level up, etc.)
var points_available: int = 0

## Custo em moedas para comprar 1 ponto
@export var coins_per_point: int = 50

## Níveis comprados em cada atributo (quantos pontos foram gastos)
var _stat_levels: Dictionary = {}

# ================= API =================

func _ready() -> void:
	_init_stat_levels()

func _init_stat_levels() -> void:
	for s in Stat.values():
		if not _stat_levels.has(s):
			_stat_levels[s] = 0

## Retorna quantos pontos livres o jogador tem
func get_points_available() -> int:
	return points_available

## Adiciona pontos (ex.: level up, recompensa)
func add_points(amount: int) -> void:
	points_available += amount
	emit_signal("points_changed", points_available)

## Retorna o nível (quantidade de pontos gastos) de um atributo
func get_stat_level(stat: Stat) -> int:
	return _stat_levels.get(stat, 0)

## Retorna o bônus numérico de um atributo (nível * valor por nível)
func get_stat_bonus(stat: Stat) -> float:
	var lvl: int = get_stat_level(stat)
	var per: float = BONUS_PER_LEVEL.get(stat, 0.0)
	return float(lvl) * per

## Gasta 1 ponto livre e adiciona 1 nível ao atributo. Retorna true se conseguiu.
func spend_point_on_stat(stat: Stat) -> bool:
	if points_available <= 0:
		return false
	points_available -= 1
	_stat_levels[stat] = _stat_levels.get(stat, 0) + 1
	emit_signal("points_changed", points_available)
	emit_signal("stats_changed")
	return true

## Compra 1 ponto com moedas e opcionalmente já gasta no atributo (use -1 para só comprar).
## Retorna true se conseguiu.
func buy_point_with_coins(spend_on_stat: int = -1) -> bool:
	if not InventoryManager:
		return false
	if not InventoryManager.spend_coins(coins_per_point):
		return false
	points_available += 1
	emit_signal("points_changed", points_available)
	if spend_on_stat >= 0 and spend_on_stat <= Stat.ATTACK_SPEED:
		return spend_point_on_stat(spend_on_stat as Stat)
	return true

## Apenas compra 1 ponto (sem gastar em atributo)
func buy_point() -> bool:
	return buy_point_with_coins(-1)

## Aplica todos os bônus no jogador (vida, dano, velocidade, etc.)
func apply_to_player(player: Node) -> void:
	if not is_instance_valid(player):
		return

	var health_comp: HealthComponent = null
	if player.has_method("get_health_component"):
		health_comp = player.get_health_component()

	# Vida: base + bônus no HealthComponent
	if health_comp:
		var base_hp: float = player.base_health if "base_health" in player else 100.0
		health_comp.max_health = base_hp + get_stat_bonus(Stat.HEALTH)
		health_comp.current_health = minf(health_comp.current_health, health_comp.max_health)
		# Força a UI da barra de vida a atualizar (max_health mudou)
		health_comp.health_changed.emit(health_comp.current_health, health_comp.current_health)

	# Dano base (usado por skills/arma)
	if "base_damage" in player and "damage" in player:
		player.damage = player.base_damage + int(get_stat_bonus(Stat.DAMAGE))

	# Velocidade
	if "base_speed" in player and "speed" in player:
		player.speed = player.base_speed + get_stat_bonus(Stat.SPEED)
	if "sprint_speed" in player:
		var base_sprint: float = 14.0
		if "base_speed" in player:
			base_sprint = player.base_speed * (14.0 / 8.0)
		player.sprint_speed = base_sprint + get_stat_bonus(Stat.SPEED) * 1.2

	# Pulos
	if "base_max_jumps" in player and "max_jumps" in player:
		player.max_jumps = player.base_max_jumps + int(get_stat_bonus(Stat.JUMPS))

	# Defesa (HealthComponent)
	if health_comp:
		health_comp.defense = get_stat_bonus(Stat.DEFENSE)

	# Velocidade de ataque
	if "base_attack_speed" in player and "attack_speed" in player:
		player.attack_speed = player.base_attack_speed + get_stat_bonus(Stat.ATTACK_SPEED)
