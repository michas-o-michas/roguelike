extends Resource
class_name AnimalSpawnerData

@export var spawner_name: String = "Animal Spawner"
@export var spawner_scene: PackedScene

@export_group("Quantidade e Distância")
@export var count: int = 5
@export var min_distance: float = 50.0
@export var max_distance: float = 400.0

@export_group("Restrições de Altura")
@export var min_height: float = 0.0
@export var max_height: float = 15.0

@export_group("Biomas Permitidos")
@export var allowed_biomes: Array[String] = []

@export_group("Descrição")
@export_multiline var description: String = "Ex: Lobos (Floresta), Ursos (Montanha), Coelhos (Planície)"

# ========================================
# EXEMPLOS DE USO:
# ========================================
#
# SPAWNER DE LOBOS:
# - count: 8
# - min_distance: 100, max_distance: 400
# - min_height: 2, max_height: 12
# - allowed_biomes: ["Floresta Normal", "Floresta Escura"]
# - spawner_scene: aponta para um node que spawna lobos periodicamente
#
# SPAWNER DE URSOS:
# - count: 3
# - min_distance: 150, max_distance: 450
# - min_height: 8, max_height: 18
# - allowed_biomes: ["Montanha Rochosa", "Floresta de Pinheiros"]
#
# SPAWNER DE COELHOS:
# - count: 15
# - min_distance: 30, max_distance: 300
# - min_height: 0, max_height: 8
# - allowed_biomes: ["Planície", "Floresta Normal"]
#
# NOTA: O spawner_scene deve ter um script que:
# 1. Detecta quando o jogador está próximo
# 2. Spawna animais ao redor do spawner
# 3. Mantém um número máximo de animais vivos
# 4. Respeita cooldowns entre spawns
