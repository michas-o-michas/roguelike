extends Resource
class_name EnemyVariant

## 🐺 Variante de Inimigo
## Define diferentes tipos do mesmo inimigo base (ex: Lobo Cinza, Lobo Alpha, Lobo de Gelo)

@export_group("📋 Identificação")
@export var variant_name: String = "Lobo Comum" ## Nome da variante
@export var variant_id: String = "wolf_common" ## ID único
@export var difficulty_tier: int = 1 ## Tier de dificuldade (1-5)

@export_group("🎨 Aparência")
@export var base_color: Color = Color.GRAY ## Cor principal
@export var secondary_color: Color = Color.WHITE ## Cor secundária (opcional)
@export var use_gradient: bool = false ## Usar gradiente entre cores
@export var material_override: Material = null ## Material customizado (opcional)

@export_group("❤️ Stats Modificadores")
@export var health_multiplier: float = 1.0 ## Multiplicador de vida (1.0 = normal, 2.0 = dobro)
@export var damage_multiplier: float = 1.0 ## Multiplicador de dano
@export var speed_multiplier: float = 1.0 ## Multiplicador de velocidade
@export var defense_bonus: float = 0.0 ## Bônus de defesa (aditivo)

@export_group("💎 Raridade e Drops")
@export var rarity: Rarity = Rarity.COMMON ## Raridade da variante
@export var spawn_weight: float = 10.0 ## Peso de spawn (maior = mais comum)
@export var xp_multiplier: float = 1.0 ## Multiplicador de XP
@export var drop_chance_multiplier: float = 1.0 ## Multiplicador de chance de drop

enum Rarity {
	COMMON,      # Branco - 70% spawn
	UNCOMMON,    # Verde - 20% spawn
	RARE,        # Azul - 7% spawn
	EPIC,        # Roxo - 2% spawn
	LEGENDARY    # Laranja - 1% spawn
}

# Aplicar modificadores ao inimigo
func apply_to_enemy(enemy: Enemy):
	# Stats
	enemy.max_health *= health_multiplier
	enemy.current_health = enemy.max_health
	enemy.damage *= damage_multiplier
	enemy.walk_speed *= speed_multiplier
	enemy.run_speed *= speed_multiplier
	enemy.defense += defense_bonus
	
	# XP e drops
	enemy.drop_experience = int(enemy.drop_experience * xp_multiplier)
	enemy.drop_chance *= drop_chance_multiplier
	
	# Cor
	if material_override:
		apply_custom_material(enemy)
	else:
		apply_color(enemy)

func apply_color(enemy: Enemy):
	if not enemy.mesh_instance:
		return
	
	var material = StandardMaterial3D.new()
	
	if use_gradient:
		# TODO: Implementar shader de gradiente
		material.albedo_color = base_color.lerp(secondary_color, 0.5)
	else:
		material.albedo_color = base_color
	
	enemy.mesh_instance.set_surface_override_material(enemy.material_override_index, material)

func apply_custom_material(enemy: Enemy):
	if not enemy.mesh_instance or not material_override:
		return
	
	enemy.mesh_instance.set_surface_override_material(enemy.material_override_index, material_override)

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color.GREEN
		Rarity.RARE: return Color.BLUE
		Rarity.EPIC: return Color.PURPLE
		Rarity.LEGENDARY: return Color.ORANGE
	return Color.WHITE
