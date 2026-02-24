class_name SpellChest
extends Interactable

## Baú de recompensa da dungeon. Spawna após concluir todas as waves.
## Contém uma magia aleatória da lista possible_spells.
## Se o jogador já possui a magia sorteada, ela sobe de nível em vez de desbloquear.

var possible_spells: Array[Spell] = []

var _opened: bool = false
var _light: OmniLight3D


func _ready() -> void:
	super()
	interact_label = "Abrir Baú Mágico [E]"
	_build_visuals()
	_start_pulse()


# ── Interação ──────────────────────────────────────────────────────────────────

## Chamado pelo InteractionManager quando o jogador pressiona E.
func interact(_interactor: Node) -> void:
	_open()


func _open() -> void:
	if _opened or possible_spells.is_empty() or not SpellManager:
		return
	_opened = true

	# Escolhe: prefere magias novas; se todas já desbloqueadas, melhora uma aleatória.
	var new_spells: Array[Spell] = []
	for s: Spell in possible_spells:
		if not SpellManager.has_spell(s.id):
			new_spells.append(s)

	var chosen: Spell
	var action: String

	if new_spells.is_empty():
		# Todas já desbloqueadas — melhora uma aleatória da lista.
		chosen = possible_spells[randi() % possible_spells.size()]
		var upgraded: Spell = SpellManager.upgrade_spell(chosen.id)
		if upgraded:
			chosen = upgraded
		action = "melhorada"
	else:
		chosen = new_spells[randi() % new_spells.size()]
		SpellManager.unlock_spell(chosen)
		action = "desbloqueada"

	_show_result(chosen, action)
	_play_open_effect()
	await get_tree().create_timer(3.5).timeout
	if is_instance_valid(self):
		queue_free()


# ── Visuais ────────────────────────────────────────────────────────────────────

func _build_visuals() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color               = Color(0.72, 0.50, 0.08)
	mat.roughness                  = 0.35
	mat.metallic                   = 0.65
	mat.emission_enabled           = true
	mat.emission                   = Color(0.55, 0.35, 0.02)
	mat.emission_energy_multiplier = 1.0

	# Corpo
	var body_mi    := MeshInstance3D.new()
	var body_box   := BoxMesh.new()
	body_box.size  = Vector3(1.2, 0.75, 0.85)
	body_box.material = mat
	body_mi.mesh   = body_box
	body_mi.position = Vector3(0.0, 0.375, 0.0)
	add_child(body_mi)

	# Tampa
	var lid_mi    := MeshInstance3D.new()
	var lid_box   := BoxMesh.new()
	lid_box.size  = Vector3(1.24, 0.32, 0.88)
	lid_box.material = mat
	lid_mi.mesh   = lid_box
	lid_mi.position = Vector3(0.0, 0.91, 0.0)
	add_child(lid_mi)

	# Faixa dourada no meio
	var band_mi    := MeshInstance3D.new()
	var band_box   := BoxMesh.new()
	band_box.size  = Vector3(1.22, 0.08, 0.87)
	var band_mat   := StandardMaterial3D.new()
	band_mat.albedo_color = Color(1.0, 0.80, 0.1)
	band_mat.metallic     = 1.0
	band_mat.roughness    = 0.2
	band_box.material = band_mat
	band_mi.mesh   = band_box
	band_mi.position = Vector3(0.0, 0.76, 0.0)
	add_child(band_mi)

	# StaticBody para o raycast do InteractionManager detectar
	var sb  := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh  := BoxShape3D.new()
	sh.size = Vector3(1.2, 1.2, 0.85)
	col.shape = sh
	sb.position = Vector3(0.0, 0.6, 0.0)
	sb.add_child(col)
	add_child(sb)

	# Luz pulsante
	_light = OmniLight3D.new()
	_light.position         = Vector3(0.0, 1.5, 0.0)
	_light.light_color      = Color(1.0, 0.78, 0.22)
	_light.light_energy     = 3.5
	_light.omni_range       = 7.0
	_light.omni_attenuation = 1.4
	_light.shadow_enabled   = false
	add_child(_light)


func _start_pulse() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_light, "light_energy", 5.5, 1.1).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_light, "light_energy", 2.5, 1.1).set_ease(Tween.EASE_IN_OUT)


func _play_open_effect() -> void:
	if is_instance_valid(_light):
		_light.light_energy = 10.0
		_light.light_color  = Color(1.0, 1.0, 0.7)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.18, 1.18, 1.18), 0.10)
	tween.tween_property(self, "scale", Vector3(1.0,  1.0,  1.0),  0.18)


# ── HUD resultado ──────────────────────────────────────────────────────────────

func _show_result(spell: Spell, action: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	get_tree().current_scene.add_child(layer)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.offset_top  = 120
	lbl.offset_left = -450
	lbl.offset_right = 450

	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 3)

	var level_txt := " → Nível %d" % (spell.upgrade_level + 1) if action == "melhorada" else ""
	lbl.text = "✨  %s %s!%s" % [spell.spell_name, action, level_txt]
	layer.add_child(lbl)

	# Sub-texto com stats atuais
	var sub := Label.new()
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.offset_top  = 162
	sub.offset_left = -450
	sub.offset_right = 450
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	sub.add_theme_constant_override("shadow_offset_x", 1)
	sub.add_theme_constant_override("shadow_offset_y", 2)
	sub.text = "Dano: %.0f  |  Área: %.1fm" % [spell.get_damage(), spell.get_area()]
	layer.add_child(sub)

	lbl.modulate.a = 0.0
	sub.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.35)
	tw.tween_property(sub, "modulate:a", 1.0, 0.35)
	await get_tree().create_timer(3.0).timeout
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw2.tween_property(sub, "modulate:a", 0.0, 0.5)
	await tw2.finished
	layer.queue_free()
