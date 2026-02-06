extends Resource
class_name BiomeData

@export var biome_name: String = "Bioma" ## Nome do bioma (ex: "Floresta Normal", "Floresta Sombria")

@export_group("Dificuldade e Raridade")
@export_range(1, 10) var difficulty_tier: int = 1 ## ⭐ Tier de dificuldade do bioma. Tier 1 = comum/fácil, Tier 3+ = raro/difícil. Biomas com tier alto só aparecem longe do spawn!
@export_range(0.0, 1.0) var biome_rarity: float = 1.0 ## 🎲 Raridade do bioma (1.0 = comum, 0.1 = muito raro). Use para biomas especiais como "Floresta Cogumelo"

@export_group("Condições de Spawn")
@export var min_height: float = -5.0 ## ⛰️ Altura mínima do terreno
@export var max_height: float = 20.0 ## ⛰️ Altura máxima do terreno
@export_range(0.0, 1.0) var preferred_moisture: float = 0.5 ## 🌧️ Umidade preferida (0 = seco, 1 = úmido). Ex: Deserto = 0.2, Pântano = 0.9
@export_range(0.0, 1.0) var preferred_temperature: float = 0.5 ## 🌡️ Temperatura preferida (0 = frio, 1 = quente). Ex: Tundra = 0.2, Deserto = 0.9
@export_range(0.0, 1.0) var biome_noise_value: float = 0.5 ## 🗺️ Valor de ruído espacial (0-1). Use para criar "ilhas" de biomas específicos

@export_group("Itens do Bioma")
@export var biome_items: Array[BiomeItem] = [] ## 🌳 Árvores, pedras, plantas que spawnam neste bioma

@export_group("POIs e Spawners Específicos")
@export var biome_pois: Array[POIData] = [] ## 📍 POIs exclusivos deste bioma (ex: Altar Sombrio só em Floresta Escura). Respeitam difficulty_tier!
@export var biome_spawners: Array[AnimalSpawnerData] = [] ## 🐾 Spawners exclusivos deste bioma (ex: Lobos Sombrios só em Floresta Escura)

@export_group("Descrição")
@export_multiline var description: String = ""

# ========================================
# SISTEMA DE TIERS PARA BIOMAS:
# ========================================
#
# TIER 1 - COMUM (0-500m):
# - Floresta Normal (moisture: 0.6, temp: 0.5)
# - Planície (moisture: 0.4, temp: 0.6)
# - Colinas (moisture: 0.5, temp: 0.5)
#
# TIER 2 - INTERMEDIÁRIO (500-1500m):
# - Floresta Densa (moisture: 0.7, temp: 0.4)
# - Pântano (moisture: 0.9, temp: 0.5)
# - Montanha Baixa (moisture: 0.3, temp: 0.3)
#
# TIER 3 - AVANÇADO (1500-3000m):
# - Floresta Sombria (moisture: 0.8, temp: 0.3)
# - Deserto (moisture: 0.1, temp: 0.9)
# - Montanha Alta (moisture: 0.2, temp: 0.1)
#
# TIER 4 - DIFÍCIL (3000-5000m):
# - Floresta Corrompida (moisture: 0.7, temp: 0.2)
# - Vulcânico (moisture: 0.1, temp: 1.0)
# - Pico Nevado (moisture: 0.4, temp: 0.0)
#
# TIER 5 - EXTREMO (5000+m):
# - Floresta Amaldiçoada (biome_rarity: 0.3)
# - Terras Devastadas (biome_rarity: 0.2)
# - Dimensão Sombria (biome_rarity: 0.1)
#
# ========================================
# EXEMPLOS COM TIER:
# ========================================
#
# FLORESTA NORMAL (Tier 1 - Comum):
# biome_name: "Floresta Normal"
# difficulty_tier: 1
# biome_rarity: 1.0 (sempre aparece)
# min_height: 0, max_height: 12
# preferred_moisture: 0.6, temperature: 0.5
# biome_items: [Carvalho (comum), Pinheiro (incomum)]
# biome_pois: [Cabana Abandonada]
# biome_spawners: [Veados, Coelhos]
#
# FLORESTA ESCURA (Tier 2 - Intermediário):
# biome_name: "Floresta Escura"
# difficulty_tier: 2
# biome_rarity: 0.8 (um pouco raro)
# min_height: 2, max_height: 10
# preferred_moisture: 0.8, temperature: 0.4
# biome_noise_value: 0.7 (em áreas específicas)
# biome_items: [Árvore Sombria + Cogumelos (sub-item)]
# biome_pois: [Altar Sombrio, Torre Abandonada]
# biome_spawners: [Lobos, Aranhas Gigantes]
#
# FLORESTA CORROMPIDA (Tier 4 - Difícil):
# biome_name: "Floresta Corrompida"
# difficulty_tier: 4
# biome_rarity: 0.5 (raro)
# min_height: 0, max_height: 15
# preferred_moisture: 0.7, temperature: 0.2
# biome_noise_value: 0.8
# biome_items: [Árvore Corrompida (rara), Cristal Sombrio (épico)]
# biome_pois: [Santuário Corrompido, Boss Arena]
# biome_spawners: [Demônios, Esqueletos Negros]
#
# ========================================
# COMO O SISTEMA FUNCIONA:
# ========================================
#
# 1. Sistema calcula difficulty_tier baseado na distância
# 2. Filtra biomas: só considera biomas com tier <= tier_atual
# 3. Entre os biomas válidos, escolhe por moisture/temp/noise
# 4. Aplica biome_rarity para biomas especiais
# 5. POIs e spawners do bioma respeitam allowed_biomes
#
# RESULTADO:
# - Perto do spawn: Floresta Normal, Planície
# - Longe do spawn: Floresta Sombria, Deserto
# - MUITO longe: Floresta Corrompida, Dimensão Sombria
#
# POIs específicos:
# - Altar Sombrio SÓ em Floresta Escura
# - Boss Arena SÓ em Floresta Corrompida
# - Cada bioma tem seu próprio conteúdo único!
