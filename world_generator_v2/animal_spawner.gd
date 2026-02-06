extends Resource
class_name AnimalSpawner

@export var spawner_name: String = "Animal Spawner" ## Nome do spawner (ex: "Lobos", "Ursos", "Boss Dragon")
@export var spawner_scene: PackedScene ## 🎬 Cena do spawner (.tscn) que controla spawn de animais

@export_group("Dificuldade (Mundo Infinito)")
@export_range(1, 10) var difficulty_tier: int = 1 ## ⭐ Tier de dificuldade. Tier 1 = animais fracos (0-500m), Tier 2 = médios (500-1500m), Tier 3+ = fortes/bosses

@export_group("Restrições de Altura")
@export var min_height: float = 0.0 ## ⛰️ Altura mínima para spawnar
@export var max_height: float = 20.0 ## ⛰️ Altura máxima

@export_group("Biomas Permitidos")
@export var allowed_biomes: Array[String] = [] ## 🌳 Lista de biomas onde pode spawnar (vazio = qualquer bioma). Ex: ["Floresta Normal", "Floresta Escura"]

@export_group("Descrição")
@export_multiline var description: String = ""

# ========================================
# SISTEMA DE TIERS PARA ANIMAIS:
# ========================================
#
# TIER 1 (0-500m) - INICIANTE:
# - Coelhos (passivos)
# - Veados (passivos)
# - Lobos Fracos (HP baixo, dano baixo)
# - Javalis Pequenos
#
# TIER 2 (500-1500m) - INTERMEDIÁRIO:
# - Lobos Normais
# - Ursos Marrons
# - Javalis Grandes
# - Aranhas Gigantes
#
# TIER 3 (1500-3000m) - AVANÇADO:
# - Lobos Alfa (pack leader)
# - Ursos Grandes
# - Trolls
# - Wyverns Jovens
#
# TIER 4 (3000-5000m) - DIFÍCIL:
# - Ursos Ancestrais
# - Wyverns Adultos
# - Ogros
# - Mini-Bosses
#
# TIER 5+ (5000+m) - EXTREMO:
# - Dragons
# - World Bosses
# - Criaturas Lendárias
#
# ========================================
# EXEMPLOS DE CONFIGURAÇÃO:
# ========================================
#
# COELHOS (Tier 1 - Passivos):
# spawner_name: "Coelhos"
# difficulty_tier: 1
# min_height: 0, max_height: 10
# allowed_biomes: ["Planície", "Floresta Normal"]
#
# LOBOS (Tier 1 - Fracos):
# spawner_name: "Lobos Fracos"
# difficulty_tier: 1
# min_height: 0, max_height: 15
# allowed_biomes: ["Floresta Normal"]
#
# URSOS (Tier 2 - Médios):
# spawner_name: "Ursos Marrons"
# difficulty_tier: 2
# min_height: 5, max_height: 18
# allowed_biomes: ["Floresta Escura", "Montanha"]
#
# LOBOS ALFA (Tier 3 - Fortes):
# spawner_name: "Lobos Alfa"
# difficulty_tier: 3
# min_height: 0, max_height: 20
# allowed_biomes: ["Floresta Escura"]
#
# DRAGON (Tier 5 - Boss):
# spawner_name: "Dragon Ancião"
# difficulty_tier: 5
# min_height: 10, max_height: 30
# allowed_biomes: [] # Qualquer bioma
#
# ========================================
# NOTA: O spawner_scene deve ter um script que:
# 1. Detecta quando o jogador está próximo (activation_distance)
# 2. Spawna animais ao redor do spawner
# 3. Mantém um número máximo de animais vivos (max_animals)
# 4. Respeita cooldowns entre spawns (spawn_cooldown)
# 5. Ver animal_spawner.gd para exemplo
