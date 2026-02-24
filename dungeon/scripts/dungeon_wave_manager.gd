class_name DungeonWaveManager
extends Node
## Gerencia waves de mobs dentro de uma dungeon.
## Adicione como filho do nó Room e configure via inspetor ou pelo sistema padrão.
## Início: room.checkin() → start(); Reset: room.checkout() → reset_state().

## Emitido quando uma wave começa (0-based).
signal wave_started(wave_index: int, total_waves: int)
## Emitido quando todos os mobs de uma wave morrem.
signal wave_cleared(wave_index: int)
## Emitido quando todas as waves são concluídas.
signal all_waves_cleared()
## Emitido a cada morte de mob.
signal mob_count_changed(alive: int)

## Waves em ordem. Se vazio, gera automaticamente com base em dungeon_level.
@export var waves: Array[WaveData] = []

## Node3D pai dos Marker3D usados como pontos de spawn (ex.: NodePath("../SpawnPoints")).
@export var spawn_points_parent: NodePath = NodePath("")

## NodePath para o Landingpad de saída — bloqueado até todas as waves completarem.
@export var exit_pad_path: NodePath = NodePath("")

## Nível da dungeon, usado para gerar as waves padrão (1 = lv1, 2 = lv2, …).
@export var dungeon_level: int = 1

## Delay em segundos antes da primeira wave (permite ao player se orientar).
@export var first_wave_delay: float = 4.0

## Delay em segundos entre waves consecutivas.
@export var between_wave_delay: float = 6.0

## Se true: re-entrar na dungeon reinicia as waves do zero.
@export var reset_on_reenter: bool = true

## Magias disponíveis como recompensa. Se vazio, usa as padrão por nível.
@export var reward_spells: Array[Spell] = []

var _current_wave: int = -1
var _reward_chest: Node = null
var _alive_mobs: int = 0
var _active_mobs: Array[Node] = []
var _started: bool = false
var _completed: bool = false

# ── HUD interno ───────────────────────────────────────────────────────────────
var _hud_layer: CanvasLayer
var _announce_label: Label
var _status_label: Label
var _tween_announce: Tween


func _ready() -> void:
	_build_hud()
	_show_hud(false)
	_lock_exit()
	if waves.is_empty():
		_setup_default_waves()


# ─── API pública ──────────────────────────────────────────────────────────────

## Inicia as waves. Chamado por room.checkin().
func start() -> void:
	# Dungeon já concluída sem reset: só libera saída e mostra HUD final.
	if _completed and not reset_on_reenter:
		_show_hud(true)
		_set_status("Dungeon já concluída. Saída liberada!")
		_unlock_exit()
		return
	# Já em andamento (não deveria acontecer, mas protege contra dupla chamada).
	if _started:
		return
	_started = true
	_completed = false
	_current_wave = -1
	_alive_mobs = 0
	_active_mobs.clear()
	_lock_exit()
	_show_hud(true)
	_announce("Prepara-te...", first_wave_delay)
	_set_status("")
	await get_tree().create_timer(first_wave_delay).timeout
	if not _started:
		return
	_next_wave()


## Para e limpa todas as waves. Chamado por room.checkout().
func reset_state() -> void:
	_started = false
	for mob in _active_mobs:
		if is_instance_valid(mob):
			mob.queue_free()
	_active_mobs.clear()
	_alive_mobs = 0
	_show_hud(false)
	if is_instance_valid(_reward_chest):
		_reward_chest.queue_free()
		_reward_chest = null
	if not _completed:
		_current_wave = -1
		_lock_exit()


# ─── Fluxo de waves ───────────────────────────────────────────────────────────

func _next_wave() -> void:
	_current_wave += 1
	if _current_wave >= waves.size():
		_complete()
		return
	var wave: WaveData = waves[_current_wave]
	var total := waves.size()
	wave_started.emit(_current_wave, total)
	_announce("ONDA %d / %d" % [_current_wave + 1, total], wave.spawn_delay)
	_set_status("Aguardando...")
	await get_tree().create_timer(wave.spawn_delay).timeout
	if not _started:
		return
	_spawn_wave(wave)


func _spawn_wave(wave: WaveData) -> void:
	var pts := _get_spawn_points()
	if pts.is_empty():
		push_warning("DungeonWaveManager: nenhum spawn point em '%s'." % spawn_points_parent)
	var pt_idx := 0
	for entry in wave.entries:
		if entry.mob_id.is_empty():
			continue
		if not MobRegistry:
			push_warning("DungeonWaveManager: MobRegistry não encontrado.")
			continue
		var mob_data: MobData = MobRegistry.get_mob(entry.mob_id)
		if not mob_data:
			push_warning("DungeonWaveManager: mob_id '%s' não registrado." % entry.mob_id)
			continue
		if not mob_data.mob_scene:
			push_warning("DungeonWaveManager: mob_id '%s' sem mob_scene." % entry.mob_id)
			continue
		for _i in entry.count:
			var mob = mob_data.mob_scene.instantiate()
			if not mob:
				continue
			var pt: Node3D
			if pts.size() > 0:
				pt = pts[pt_idx % pts.size()]
				pt_idx += 1
			else:
				pt = get_parent() as Node3D
			# add_child primeiro — global_position só funciona após estar na árvore.
			get_parent().add_child(mob)
			mob.global_position = pt.global_position + Vector3(
				randf_range(-2.5, 2.5), 0.15, randf_range(-2.5, 2.5)
			)
			if mob.has_method("set_mob_data"):
				mob.set_mob_data(mob_data)
			# Aplica escalonamento via pseudo-day se há multiplicadores.
			if wave.hp_multiplier != 1.0 or wave.damage_multiplier != 1.0:
				var pseudo_day := _mult_to_pseudo_day(wave.hp_multiplier)
				var dmg_per_day := 0.05 if wave.damage_multiplier != 1.0 else 0.0
				mob.call_deferred("apply_day_scaling", pseudo_day, 0.1, dmg_per_day)
			_alive_mobs += 1
			_active_mobs.append(mob)
			var hc := mob.get_node_or_null("HealthComponent")
			if hc and hc.has_signal("died"):
				hc.died.connect(func(): _on_mob_died(mob), CONNECT_ONE_SHOT)
	mob_count_changed.emit(_alive_mobs)
	_set_status("Inimigos: %d" % _alive_mobs)


## Converte hp_multiplier em pseudo-day para apply_day_scaling(day, 0.1, …).
## hp_mult = 1.0 + (day-1) * 0.1  →  day = (hp_mult - 1.0) / 0.1 + 1
func _mult_to_pseudo_day(hp_mult: float) -> int:
	return maxi(1, roundi((hp_mult - 1.0) / 0.1) + 1)


func _on_mob_died(mob: Node) -> void:
	if not _started:
		return
	_active_mobs.erase(mob)
	_alive_mobs = maxi(0, _alive_mobs - 1)
	mob_count_changed.emit(_alive_mobs)
	_set_status("Inimigos: %d" % _alive_mobs)
	if _alive_mobs > 0:
		return
	wave_cleared.emit(_current_wave)
	var is_last := (_current_wave >= waves.size() - 1)
	if is_last:
		await get_tree().create_timer(1.5).timeout
		_complete()
	else:
		_announce("Onda %d concluída!" % (_current_wave + 1), between_wave_delay)
		_run_countdown(between_wave_delay)
		await get_tree().create_timer(between_wave_delay).timeout
		if _started:
			_next_wave()


func _complete() -> void:
	_completed = true
	all_waves_cleared.emit()
	_announce("DUNGEON COMPLETA!", 5.0)
	_set_status("Saída liberada!")
	_unlock_exit()
	_spawn_reward_chest()
	await get_tree().create_timer(5.5).timeout
	_set_status("")
	_show_hud(false)


## Atualiza o label de status com contagem regressiva a cada segundo.
func _run_countdown(seconds: float) -> void:
	var t := seconds
	while t > 0.5 and _started and not _completed:
		_set_status("Próxima onda em %ds..." % int(ceil(t)))
		await get_tree().create_timer(1.0).timeout
		t -= 1.0


# ─── Exit pad ─────────────────────────────────────────────────────────────────

func _lock_exit() -> void:
	var pad := _get_exit_pad()
	if not pad:
		return
	pad.visible = false
	_set_collisions(pad, true)


func _unlock_exit() -> void:
	var pad := _get_exit_pad()
	if not pad:
		return
	pad.visible = true
	_set_collisions(pad, false)


func _get_exit_pad() -> Node:
	if exit_pad_path.is_empty():
		return null
	return get_node_or_null(exit_pad_path)


## Habilita/desabilita todos os CollisionShape3D dentro de `node` recursivamente.
func _set_collisions(node: Node, disabled: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = disabled
	for child in node.get_children():
		_set_collisions(child, disabled)


# ─── Spawn points ─────────────────────────────────────────────────────────────

func _get_spawn_points() -> Array[Node3D]:
	var pts: Array[Node3D] = []
	if spawn_points_parent.is_empty():
		return pts
	var parent := get_node_or_null(spawn_points_parent)
	if not parent:
		return pts
	for child in parent.get_children():
		if child is Node3D:
			pts.append(child as Node3D)
	return pts


# ─── Waves padrão ─────────────────────────────────────────────────────────────

func _setup_default_waves() -> void:
	waves.clear()
	match dungeon_level:
		1:
			# Dungeon Lv1 — 3 ondas: sentinelas + guardiões
			waves.append(_make_wave([["dungeon_sentinel", 3]], 1.5))
			waves.append(_make_wave([["dungeon_sentinel", 4], ["dungeon_brute", 1]], 2.0))
			waves.append(_make_wave([["dungeon_sentinel", 5], ["dungeon_brute", 2]], 2.0, 1.3, 1.1))
		2:
			# Dungeon Lv2 — 4 ondas: mais intensas
			waves.append(_make_wave([["dungeon_sentinel", 4]], 1.5))
			waves.append(_make_wave([["dungeon_sentinel", 5], ["dungeon_brute", 2]], 2.0))
			waves.append(_make_wave([["dungeon_sentinel", 4], ["dungeon_brute", 3]], 2.0, 1.2, 1.0))
			waves.append(_make_wave([["dungeon_sentinel", 3], ["dungeon_brute", 4]], 2.5, 1.5, 1.2))
		_:
			# Genérico: escala com dungeon_level
			var n := dungeon_level
			waves.append(_make_wave([["dungeon_sentinel", n + 2]], 1.5))
			waves.append(_make_wave([["dungeon_sentinel", n + 2], ["dungeon_brute", n]], 2.0))
			waves.append(_make_wave([["dungeon_brute", n + 2]], 2.0, 1.5, 1.2))


## Cria um WaveData programaticamente.
## entries: Array de [mob_id: String, count: int].
func _make_wave(
	entries: Array,
	spawn_delay: float = 1.5,
	hp_mult: float = 1.0,
	dmg_mult: float = 1.0
) -> WaveData:
	var wd := WaveData.new()
	wd.spawn_delay = spawn_delay
	wd.hp_multiplier = hp_mult
	wd.damage_multiplier = dmg_mult
	for e in entries:
		var entry := WaveMobEntry.new()
		entry.mob_id = e[0]
		entry.count = e[1]
		wd.entries.append(entry)
	return wd


# ─── HUD interno ──────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 11
	_hud_layer.name = "WaveHUD"
	add_child(_hud_layer)

	# Anúncio central grande (transiente)
	_announce_label = Label.new()
	_announce_label.name = "AnnounceLabel"
	_announce_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_announce_label.add_theme_font_size_override("font_size", 40)
	_announce_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.22))
	_announce_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_announce_label.add_theme_constant_override("shadow_offset_x", 2)
	_announce_label.add_theme_constant_override("shadow_offset_y", 2)
	_announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_label.offset_top = 75
	_announce_label.offset_left = -320
	_announce_label.offset_right = 320
	_announce_label.modulate.a = 0.0
	_hud_layer.add_child(_announce_label)

	# Status persistente (topo esquerdo)
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	_status_label.offset_top = 12
	_status_label.offset_left = 12
	_status_label.offset_right = 340
	_status_label.offset_bottom = 90
	_hud_layer.add_child(_status_label)


func _show_hud(v: bool) -> void:
	if _hud_layer:
		_hud_layer.visible = v


## Exibe anúncio grande com fade in/out.
## display_for: duração total em segundos (fade in 0.35 + hold + fade out 0.45).
func _announce(text: String, display_for: float = 3.0) -> void:
	if not _announce_label:
		return
	_announce_label.text = text
	if _tween_announce and _tween_announce.is_valid():
		_tween_announce.kill()
	_announce_label.modulate.a = 0.0
	_tween_announce = create_tween().set_parallel(false)
	_tween_announce.tween_property(_announce_label, "modulate:a", 1.0, 0.35)
	var hold := display_for - 0.8
	if hold > 0.0:
		_tween_announce.tween_interval(hold)
	_tween_announce.tween_property(_announce_label, "modulate:a", 0.0, 0.45)


func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


# ─── Recompensa: Baú de Magia ─────────────────────────────────────────────────

func _spawn_reward_chest() -> void:
	if is_instance_valid(_reward_chest):
		return  # já existe

	var chest_script: Script = load("res://dungeon/scripts/spell_chest.gd")
	if not chest_script:
		push_error("DungeonWaveManager: spell_chest.gd não encontrado.")
		return

	_reward_chest = chest_script.new()
	if not _reward_chest:
		push_error("DungeonWaveManager: falha ao instanciar SpellChest.")
		return

	# Passa a lista de magias antes do add_child (antes do _ready).
	_reward_chest.set("possible_spells", _get_reward_spells())

	# Posição: à frente do exit pad, no centro da arena.
	var pad := _get_exit_pad() as Node3D
	var chest_pos := Vector3(0.0, 0.0, -6.0)
	if is_instance_valid(pad):
		chest_pos = pad.global_position + Vector3(0.0, 0.0, -6.0)

	get_parent().add_child(_reward_chest)
	_reward_chest.global_position = chest_pos


func _get_reward_spells() -> Array[Spell]:
	if not reward_spells.is_empty():
		return reward_spells
	# Gera padrão por nível de dungeon.
	var out: Array[Spell] = []
	out.append(_make_spell(
		"fireball",        "Bola de Fogo",
		25.0, 1.5, 1.2,   10.0, 0.6,
		Color(0.95, 0.30, 0.05)
	))
	out.append(_make_spell(
		"ice_shard",       "Estilhaço de Gelo",
		18.0, 0.8, 1.4,    7.0, 0.4,
		Color(0.30, 0.70, 1.0)
	))
	out.append(_make_spell(
		"thunder_bolt",    "Raio",
		38.0, 0.5, 1.8,   15.0, 0.3,
		Color(1.0, 0.90, 0.10)
	))
	if dungeon_level >= 2:
		out.append(_make_spell(
			"void_pulse",  "Pulso do Vazio",
			30.0, 2.5, 1.6,   12.0, 0.8,
			Color(0.55, 0.10, 0.85)
		))
	return out


## Cria um Spell com ícone de cor sólida (para uso sem .tres no editor).
func _make_spell(
	spell_id: String, name: String,
	base_dmg: float, base_area: float, base_cd: float,
	dmg_per_up: float, area_per_up: float,
	icon_color: Color
) -> Spell:
	var s := Spell.new()
	s.id                         = spell_id
	s.spell_name                 = name
	s.base_damage                = base_dmg
	s.area_radius                = base_area
	s.cooldown                   = base_cd
	s.damage_per_upgrade         = dmg_per_up
	s.area_per_upgrade           = area_per_up
	s.cooldown_reduction_per_upgrade = 0.05
	# Ícone: quadrado colorido 32×32 gerado em código.
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(icon_color)
	s.icon = ImageTexture.create_from_image(img)
	return s
