extends Resource
class_name BiomeData

@export var biome_name: String = "Bioma" ## Nome do bioma (ex: "Floresta Escura", "Montanha Nevada")

@export_group("Condições de Spawn")
@export var min_height: float = -5.0 ## 📏 Altura MÍNIMA do terreno. Água: -8, Planície: 0-10, Montanha: 12+
@export var max_height: float = 200.0 ## 📏 Altura MÁXIMA do terreno onde este bioma pode aparecer

@export_range(0.0, 1.0) var preferred_moisture: float = 0.5 ## 🌧️ UMIDADE preferida (0.0=Seco, 1.0=Úmido). Sistema escolhe bioma mais PRÓXIMO deste valor. Ex: Deserto=0.1, Pântano=0.9, Floresta=0.6

@export_range(0.0, 1.0) var preferred_temperature: float = 0.5 ## 🌡️ TEMPERATURA preferida (0.0=Frio, 1.0=Quente). Ex: Tundra=0.1, Selva=0.9, Temperado=0.5

@export_range(0.0, 1.0) var biome_noise_value: float = 0.5 ## 🗺️ Controla ONDE no mapa aparecer (0-1). Valores diferentes criam "ilhas" de biomas. Use 0.3-0.7 para criar sub-biomas dentro de outros!

@export_group("Itens do Bioma")
@export var biome_items: Array[BiomeItem] = [] ## 🌳 Lista de itens que spawnam (árvores, pedras, flores, etc). Cada um com suas próprias chances e variantes

@export_group("Descrição")
@export_multiline var description: String = "Ex: Floresta Escura, Tundra Gelada, Deserto"

# ========================================
# EXEMPLOS DE USO:
# ========================================
#
# FLORESTA NORMAL:
# - min_height: 0, max_height: 10
# - preferred_moisture: 0.6, temperature: 0.5
# - Items: Carvalhos (comum), Pinheiros (incomum)
#
# FLORESTA ESCURA:
# - min_height: 2, max_height: 8
# - preferred_moisture: 0.8, temperature: 0.4
# - biome_noise_value: 0.7 (aparece em áreas específicas)
# - Items: 
#   * Árvores Escuras (comum)
#     - Sub-items: Cogumelos vermelhos (50% chance, raio 2m)
#   * Troncos caídos (raro)
#
# MONTANHA ROCHOSA:
# - min_height: 12, max_height: 25
# - preferred_moisture: 0.3, temperature: 0.2
# - Items:
#   * Pedras Grandes (comum)
#   * Minério de Ferro (incomum)
#   * Minério de Ouro (raro)
#   * Cristais (épico)
