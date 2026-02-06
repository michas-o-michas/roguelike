extends Resource
class_name POIData

@export var poi_name: String = "POI" ## Nome do POI (ex: "Torre Antiga", "Cabana Abandonada")
@export var scene: PackedScene ## 🎬 Cena do POI (.tscn)

@export_group("Dificuldade (Mundo Infinito)")
@export_range(1, 10) var difficulty_tier: int = 1 ## ⭐ Tier de dificuldade. Tier 1 = 0-500m (Iniciante), Tier 2 = 500-1500m, Tier 3 = 1500-3000m, Tier 4 = 3000-5000m, Tier 5+ = 5000+m

@export_group("Restrições de Altura")
@export var min_height: float = 0.0 ## ⛰️ Altura mínima do terreno para spawnar
@export var max_height: float = 20.0 ## ⛰️ Altura máxima
@export var height_offset: float = 0.0 ## ⬆️ Ajuste de altura após spawn (útil para elevar/afundar POI)

@export_group("Descrição")
@export_multiline var description: String = ""

# ========================================
# SISTEMA DE TIERS (BASEADO NA DISTÂNCIA DO SPAWN):
# ========================================
#
# TIER 1 (0-500m) - INICIANTE:
# - Cabanas Abandonadas
# - Fogueiras
# - Baús Comuns
# - Acampamentos Fracos
#
# TIER 2 (500-1500m) - INTERMEDIÁRIO:
# - Torres de Vigia
# - Acampamentos de Bandidos
# - Baús Raros
# - Altares Misteriosos
# - Minas Abandonadas
#
# TIER 3 (1500-3000m) - AVANÇADO:
# - Fortalezas
# - Boss Arenas
# - Dungeon Entrances
# - Baús Épicos
# - Templos Antigos
#
# TIER 4 (3000-5000m) - DIFÍCIL:
# - Castelos
# - Portal Dimensions
# - Raid Bosses
# - Baús Lendários
#
# TIER 5+ (5000+m) - EXTREMO:
# - World Bosses
# - End-game Dungeons
# - Artefatos Divinos
#
# ========================================
# EXEMPLOS DE CONFIGURAÇÃO:
# ========================================
#
# CABANA ABANDONADA (Tier 1):
# poi_name: "Cabana Abandonada"
# scene: cabana.tscn
# difficulty_tier: 1
# min_height: 0, max_height: 10
# height_offset: 0.0
#
# TORRE DE VIGIA (Tier 2):
# poi_name: "Torre de Vigia"
# scene: torre.tscn
# difficulty_tier: 2
# min_height: 5, max_height: 15
# height_offset: 0.5
#
# FORTALEZA (Tier 3):
# poi_name: "Fortaleza Abandonada"
# scene: fortaleza.tscn
# difficulty_tier: 3
# min_height: 3, max_height: 18
# height_offset: 0.0
#
# CASTELO DO BOSS (Tier 4):
# poi_name: "Castelo Sombrio"
# scene: castelo_boss.tscn
# difficulty_tier: 4
# min_height: 5, max_height: 25
# height_offset: 1.0
