extends Resource
class_name POIData

@export var poi_name: String = "POI"
@export var scene: PackedScene

@export_group("Quantidade e Distância")
@export var count: int = 3
@export var min_distance_from_center: float = 100.0
@export var max_distance_from_center: float = 400.0

@export_group("Restrições de Altura")
@export var min_height: float = 0.0
@export var max_height: float = 15.0
@export var height_offset: float = 0.0

@export_group("Descrição")
@export_multiline var description: String = "Ex: Ruínas antigas, Torres, Aldeias abandonadas"

# ========================================
# EXEMPLOS DE USO:
# ========================================
#
# TORRE DE VIGIA:
# - count: 5
# - min_distance: 150, max_distance: 450
# - min_height: 5, max_height: 12 (em colinas)
#
# RUÍNA SUBAQUÁTICA:
# - count: 3
# - min_distance: 200, max_distance: 500
# - min_height: -10, max_height: -5 (debaixo d'água)
#
# ACAMPAMENTO ABANDONADO:
# - count: 8
# - min_distance: 80, max_distance: 350
# - min_height: 0, max_height: 10 (planícies)
