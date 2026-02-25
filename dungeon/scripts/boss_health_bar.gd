extends CanvasLayer
## BossHealthBar — HUD dedicado ao chefe da dungeon.
## Cena: dungeon/scenes/boss_health_bar.tscn
## Conectado pelo DungeonWaveManager via connect_to_boss().

const COLOR_PHASE1 := Color(0.75, 0.15, 0.10)
const COLOR_PHASE2 := Color(1.00, 0.35, 0.00)
const FILL_NORMAL  := Color(0.80, 0.10, 0.05)
const FILL_PHASE2  := Color(1.00, 0.40, 0.00)

@onready var _name_label:  Label      = $Margin/VBox/BossNameLabel
@onready var _fill_bar:    ColorRect  = $Margin/VBox/BarContainer/FillBar
@onready var _damage_bar:  ColorRect  = $Margin/VBox/BarContainer/DamageBar
@onready var _phase_label: Label      = $Margin/VBox/PhaseLabel

var _hc: HealthComponent = null


## Chamado pelo DungeonWaveManager após spawnar o boss.
func connect_to_boss(boss: Node, boss_display_name: String) -> void:
	_name_label.text = "⚔  %s  ⚔" % boss_display_name.to_upper()

	_hc = boss.get_node_or_null("HealthComponent") as HealthComponent
	if _hc:
		_hc.health_changed.connect(_on_health_changed)
		_hc.died.connect(_on_boss_died)

	if boss.has_signal("boss_phase_changed"):
		boss.boss_phase_changed.connect(_on_phase_changed)


func _on_health_changed(_old: float, new_val: float) -> void:
	var max_hp := _hc.max_health if _hc else 1.0
	var ratio  := clampf(new_val / max_hp, 0.0, 1.0)

	# FillBar vai imediatamente para o novo HP
	create_tween().tween_property(_fill_bar, "anchor_right", ratio, 0.08)

	# DamageBar segue com atraso (trail visual)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(_damage_bar):
		create_tween().set_trans(Tween.TRANS_SINE) \
			.tween_property(_damage_bar, "anchor_right", ratio, 0.4)


func _on_phase_changed(new_phase: int) -> void:
	if new_phase != 2:
		return

	# Troca cores para laranja enraivecido
	_name_label.add_theme_color_override("font_color", COLOR_PHASE2)
	_fill_bar.color  = FILL_PHASE2

	# Mensagem de fase com fade
	_phase_label.text = "⚠  FASE 2 — ENRAIVECIDO!  ⚠"
	var tw := create_tween()
	tw.tween_property(_phase_label, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.5)
	tw.tween_property(_phase_label, "modulate:a", 0.0, 0.5)

	# Flash amarelo na barra
	var flash := create_tween()
	flash.tween_property(_fill_bar, "color", Color(1, 1, 0.2), 0.15)
	flash.tween_property(_fill_bar, "color", FILL_PHASE2,      0.25)


func _on_boss_died() -> void:
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
