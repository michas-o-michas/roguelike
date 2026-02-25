extends CanvasLayer
## BossHealthBar — HUD dedicado ao chefe da dungeon.
## Criado em código pelo DungeonWaveManager ao spawnar um boss.
## Conecta ao HealthComponent do boss e ao sinal boss_phase_changed do MobBase.

const COLOR_PHASE1 := Color(0.75, 0.15, 0.10)   ## vermelho escuro
const COLOR_PHASE2 := Color(1.00, 0.35, 0.00)   ## laranja enraivecido
const FILL_NORMAL  := Color(0.80, 0.10, 0.05)
const FILL_PHASE2  := Color(1.00, 0.40, 0.00)

var _boss_name_label:  Label
var _hp_bar_bg:        ColorRect
var _hp_bar_fill:      ColorRect
var _hp_bar_damage:    ColorRect   ## barra de dano (trail vermelho escuro)
var _phase_label:      Label
var _tween_damage:     Tween

var _max_hp: float = 1.0
var _current_fill_color: Color = FILL_NORMAL
var _hp_bar_width: float = 700.0

func _ready() -> void:
	layer = 12  # acima do WaveHUD (layer 11)
	_build_ui()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Nome do chefe
	_boss_name_label = Label.new()
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.add_theme_font_size_override("font_size", 22)
	_boss_name_label.add_theme_color_override("font_color", COLOR_PHASE1)
	_boss_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_boss_name_label.add_theme_constant_override("shadow_offset_x", 2)
	_boss_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_boss_name_label.text = "CHEFE"
	vbox.add_child(_boss_name_label)

	# Barra HP (bg + damage trail + fill)
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(0, 22)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(bar_container)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.05, 0.05, 0.05, 0.88)
	_hp_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_container.add_child(_hp_bar_bg)

	_hp_bar_damage = ColorRect.new()
	_hp_bar_damage.color = Color(0.55, 0.05, 0.03, 0.85)
	_hp_bar_damage.anchor_left   = 0.0
	_hp_bar_damage.anchor_top    = 0.0
	_hp_bar_damage.anchor_bottom = 1.0
	_hp_bar_damage.offset_right  = 0.0
	bar_container.add_child(_hp_bar_damage)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = FILL_NORMAL
	_hp_bar_fill.anchor_left   = 0.0
	_hp_bar_fill.anchor_top    = 0.0
	_hp_bar_fill.anchor_bottom = 1.0
	_hp_bar_fill.offset_right  = 0.0
	bar_container.add_child(_hp_bar_fill)

	# Label fase (aparece na transição)
	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 18)
	_phase_label.add_theme_color_override("font_color", COLOR_PHASE2)
	_phase_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_phase_label.add_theme_constant_override("shadow_offset_x", 1)
	_phase_label.add_theme_constant_override("shadow_offset_y", 1)
	_phase_label.modulate.a = 0.0
	vbox.add_child(_phase_label)


## Conecta ao boss (MobBase) e ao seu HealthComponent.
func connect_to_boss(boss: Node, boss_display_name: String) -> void:
	_boss_name_label.text = "⚔ %s ⚔" % boss_display_name.to_upper()

	# HealthComponent
	var hc := boss.get_node_or_null("HealthComponent")
	if hc:
		_max_hp = hc.max_health
		_set_fill(1.0)
		_hp_bar_damage.anchor_right = 1.0
		hc.health_changed.connect(_on_health_changed)
		hc.died.connect(_on_boss_died)

	# Fase 2
	if boss.has_signal("boss_phase_changed"):
		boss.boss_phase_changed.connect(_on_phase_changed)


func _on_health_changed(_old: float, new_val: float) -> void:
	var ratio := clampf(new_val / _max_hp, 0.0, 1.0)
	# Trail de dano: barra damage fica onde estava, fill vai para ratio
	_tween_damage = create_tween()
	_tween_damage.tween_property(_hp_bar_fill, "anchor_right", ratio, 0.08)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(_hp_bar_damage):
		_tween_damage = create_tween().set_trans(Tween.TRANS_SINE)
		_tween_damage.tween_property(_hp_bar_damage, "anchor_right", ratio, 0.4)


func _set_fill(ratio: float) -> void:
	if _hp_bar_fill:
		_hp_bar_fill.anchor_right = ratio
	if _hp_bar_damage:
		_hp_bar_damage.anchor_right = ratio


func _on_phase_changed(new_phase: int) -> void:
	if new_phase != 2:
		return
	# Troca de cor para laranja enraivecido
	_boss_name_label.add_theme_color_override("font_color", COLOR_PHASE2)
	_hp_bar_fill.color = FILL_PHASE2
	# Flash e mensagem de fase
	_phase_label.text = "⚠ FASE 2 — ENRAIVECIDO! ⚠"
	_phase_label.modulate.a = 0.0
	var tw := create_tween().set_parallel(false)
	tw.tween_property(_phase_label, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.5)
	tw.tween_property(_phase_label, "modulate:a", 0.0, 0.5)

	# Pisca a barra
	var flash := create_tween()
	flash.tween_property(_hp_bar_fill, "color", Color(1, 1, 0.2), 0.15)
	flash.tween_property(_hp_bar_fill, "color", FILL_PHASE2,      0.25)


func _on_boss_died() -> void:
	await get_tree().create_timer(2.5).timeout
	queue_free()
