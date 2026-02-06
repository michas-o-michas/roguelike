extends Resource
class_name WorldTheme

## Define o tema visual e físico do mundo (Normal, Deserto, Lava, Neve, Alien, etc)

@export var theme_name: String = "Normal" ## Nome do tema (ex: "Normal", "Deserto", "Mundo de Lava", "Tundra")

@export_group("🌊 Líquido")
@export var liquid_type: LiquidType = LiquidType.WATER ## Tipo de líquido do mundo
@export var liquid_color: Color = Color(0.15, 0.5, 0.8, 0.6) ## Cor do líquido
@export var liquid_metallic: float = 0.8 ## Brilho metálico (0-1)
@export var liquid_roughness: float = 0.05 ## Rugosidade (0-1)

enum LiquidType {
	WATER,      ## Água azul normal
	LAVA,       ## Lava laranja/vermelha animada
	ACID,       ## Ácido verde
	OIL,        ## Óleo preto/escuro
	BLOOD,      ## Sangue vermelho
	CRYSTAL,    ## Cristal azul brilhante
	NONE        ## Sem líquido
}

@export_group("🎨 Cores do Terreno")
@export var use_custom_colors: bool = false ## Se false, usa cores padrão. Se true, usa as cores abaixo
@export var deep_water_color: Color = Color(0.08, 0.15, 0.35) ## Cor da água profunda (abaixo do nível)
@export var shallow_water_color: Color = Color(0.15, 0.3, 0.5) ## Cor da água rasa
@export var beach_color: Color = Color(0.85, 0.8, 0.65) ## Cor da praia/areia
@export var grass_low_color: Color = Color(0.4, 0.65, 0.35) ## Cor da grama baixa
@export var grass_high_color: Color = Color(0.28, 0.5, 0.25) ## Cor da grama alta/floresta
@export var rock_color: Color = Color(0.5, 0.5, 0.5) ## Cor da rocha/montanha
@export var snow_color: Color = Color(0.92, 0.92, 0.95) ## Cor da neve (picos altos)

@export_group("🌡️ Níveis de Altura")
@export var use_custom_levels: bool = false ## Se false, usa níveis padrão do WorldGenerator
@export var custom_water_level: float = -8.0 ## Nível da água/líquido
@export var custom_beach_level: float = -6.0 ## Nível da praia
@export var custom_grass_level: float = 2.0 ## Nível onde começa vegetação
@export var custom_mountain_level: float = 18.0 ## Nível de rocha/montanha

@export_group("☁️ Fog/Atmosfera")
@export var enable_custom_fog: bool = false ## Ativar névoa customizada
@export var fog_color: Color = Color(0.7, 0.75, 0.8) ## Cor da névoa
@export var fog_density: float = 0.01 ## Densidade (0-1)

@export_group("💡 Iluminação")
@export var enable_custom_lighting: bool = false ## Modificar luz direcional
@export var sun_color: Color = Color(1.0, 0.95, 0.8) ## Cor do sol
@export var sun_energy: float = 1.0 ## Intensidade (0-2)
@export var ambient_color: Color = Color(0.3, 0.3, 0.35) ## Cor ambiente

@export_group("Descrição")
@export_multiline var description: String = ""

# ========================================
# PRESETS PRONTOS:
# ========================================
#
# ===== MUNDO NORMAL =====
# theme_name: "Normal"
# liquid_type: WATER
# liquid_color: Color(0.15, 0.5, 0.8, 0.6)
# use_custom_colors: false
# → Mundo padrão, água azul, grama verde
#
# ===== MUNDO DESERTO =====
# theme_name: "Deserto"
# liquid_type: NONE
# use_custom_colors: true
# deep_water_color: Color(0.7, 0.6, 0.4)  # Areia escura
# beach_color: Color(0.9, 0.85, 0.6)      # Areia clara
# grass_low_color: Color(0.8, 0.75, 0.5)  # Areia com grama
# grass_high_color: Color(0.7, 0.65, 0.45) # Areia rochosa
# rock_color: Color(0.6, 0.5, 0.4)         # Rocha do deserto
# snow_color: Color(0.95, 0.9, 0.8)        # Areia muito clara (dunas)
# enable_custom_fog: true
# fog_color: Color(0.9, 0.85, 0.7)
# sun_energy: 1.5  # Sol forte
#
# ===== MUNDO DE LAVA =====
# theme_name: "Inferno"
# liquid_type: LAVA
# liquid_color: Color(1.0, 0.3, 0.1, 0.9)
# use_custom_colors: true
# deep_water_color: Color(0.2, 0.1, 0.1)   # Rocha vulcânica escura
# beach_color: Color(0.3, 0.2, 0.15)       # Rocha quente
# grass_low_color: Color(0.4, 0.3, 0.2)    # Rocha cinza
# grass_high_color: Color(0.35, 0.25, 0.2) # Rocha escura
# rock_color: Color(0.3, 0.2, 0.15)        # Rocha vulcânica
# snow_color: Color(0.5, 0.4, 0.3)         # Cinza de pico
# enable_custom_fog: true
# fog_color: Color(0.3, 0.15, 0.1)  # Névoa vermelha
# sun_color: Color(1.0, 0.5, 0.2)   # Sol alaranjado
# sun_energy: 1.3
#
# ===== MUNDO DE NEVE/TUNDRA =====
# theme_name: "Tundra Congelada"
# liquid_type: WATER
# liquid_color: Color(0.6, 0.7, 0.8, 0.85)  # Água gelada
# use_custom_colors: true
# deep_water_color: Color(0.3, 0.35, 0.4)   # Gelo escuro
# beach_color: Color(0.7, 0.75, 0.8)        # Neve/gelo
# grass_low_color: Color(0.75, 0.8, 0.85)   # Neve com grama
# grass_high_color: Color(0.65, 0.7, 0.75)  # Neve em floresta
# rock_color: Color(0.55, 0.6, 0.65)        # Rocha gelada
# snow_color: Color(0.95, 0.96, 0.98)       # Neve pura
# enable_custom_fog: true
# fog_color: Color(0.85, 0.9, 0.95)  # Névoa branca/azulada
# sun_color: Color(0.9, 0.95, 1.0)   # Sol frio
# sun_energy: 0.8  # Sol fraco
#
# ===== MUNDO ALIEN =====
# theme_name: "Planeta Alien"
# liquid_type: ACID
# liquid_color: Color(0.3, 0.9, 0.4, 0.7)  # Ácido verde
# use_custom_colors: true
# deep_water_color: Color(0.3, 0.2, 0.4)   # Rocha roxa
# beach_color: Color(0.5, 0.4, 0.6)        # Areia roxa
# grass_low_color: Color(0.6, 0.3, 0.7)    # Grama roxa
# grass_high_color: Color(0.5, 0.2, 0.6)   # Vegetação roxa escura
# rock_color: Color(0.4, 0.3, 0.5)         # Rocha alien
# snow_color: Color(0.7, 0.6, 0.8)         # Cristais roxos
# enable_custom_fog: true
# fog_color: Color(0.5, 0.3, 0.6)   # Névoa roxa
# sun_color: Color(0.8, 0.5, 1.0)   # Sol roxo
# sun_energy: 1.2
#
# ===== MUNDO PÓS-APOCALÍPTICO =====
# theme_name: "Terras Devastadas"
# liquid_type: OIL
# liquid_color: Color(0.15, 0.15, 0.12, 0.8)  # Óleo/poluição
# use_custom_colors: true
# deep_water_color: Color(0.2, 0.18, 0.15)    # Terra morta
# beach_color: Color(0.3, 0.28, 0.25)         # Areia tóxica
# grass_low_color: Color(0.35, 0.33, 0.28)    # Grama morta
# grass_high_color: Color(0.3, 0.28, 0.23)    # Vegetação morta
# rock_color: Color(0.4, 0.35, 0.3)           # Rocha cinza
# snow_color: Color(0.5, 0.48, 0.45)          # Cinza claro
# enable_custom_fog: true
# fog_color: Color(0.4, 0.35, 0.3)  # Névoa marrom/cinza
# sun_color: Color(0.8, 0.7, 0.6)   # Sol pálido
# sun_energy: 0.7
#
# ===== MUNDO CRISTALINO =====
# theme_name: "Reino de Cristal"
# liquid_type: CRYSTAL
# liquid_color: Color(0.4, 0.7, 1.0, 0.5)  # Líquido cristalino azul
# use_custom_colors: true
# deep_water_color: Color(0.3, 0.4, 0.6)   # Cristal escuro
# beach_color: Color(0.6, 0.7, 0.9)        # Cristal claro
# grass_low_color: Color(0.5, 0.7, 0.9)    # Cristais pequenos
# grass_high_color: Color(0.4, 0.6, 0.8)   # Cristais densos
# rock_color: Color(0.5, 0.6, 0.7)         # Rocha cristalina
# snow_color: Color(0.8, 0.9, 1.0)         # Cristais brancos
# enable_custom_fog: true
# fog_color: Color(0.7, 0.8, 0.95)  # Névoa azul clara
# sun_color: Color(0.9, 0.95, 1.0)
# sun_energy: 1.1
