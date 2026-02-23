extends Interactable

## Emitidos para você conectar som, fade ou UI (ex.: pad.teleported.connect(_on_pad_teleport)).
signal teleported(interactor: Node, from_pos: Vector3, to_pos: Vector3)
signal dungeon_entered(interactor: Node, dungeon: Node)
signal dungeon_exited(interactor: Node)

enum PadType {
	IN,
	OUT
}

enum DungeonMode {
	NONE,
	ENTRANCE,
	EXIT
}

## Teleporte normal: pad de destino (deixe em NONE se usar dungeon).
@export var destination_pad: Node3D
@export var pad_type: PadType = PadType.IN

## Se ativo, este pad entra na dungeon (desliga mapa, liga dungeon e teleporta para spawn).
@export var dungeon_mode: DungeonMode = DungeonMode.NONE
@export var dungeon_path: NodePath = NodePath("Main/Dungeon_Lv1")
@export var spawn_marker_path: NodePath = NodePath("Main/Dungeon_Lv1/EntranceMarker")

## Segundos antes de poder usar o pad de novo (evita spam de E).
@export var cooldown_seconds: float = 0.5
var _last_use_time: float = -999.0

## Sons vêm apenas do SoundManager (IDs: teleport, dungeon_enter, dungeon_exit).

## Partículas (opcional): nó filho GPUParticles3D/CPUParticles3D; será disparado ao usar o pad.
@export var particles_node: NodePath = NodePath("")

## Duração do fade ao entrar/sair (rápido).
@export var fade_duration: float = 0.2

## Tempo com tela preta/loading antes de fazer a transição e o fade in (dungeon).
@export var loading_hold_duration: float = 0.8

## No teleporte entre pads: usar fade rápido (fade_duration).
@export var use_fade_on_teleport: bool = false

func _get_destination() -> Node3D:
	if destination_pad and is_instance_valid(destination_pad):
		return destination_pad
	return null

## Texto calculado na hora; usado pelo prompt [E] e pela label 3D do pad.
## Só usa interact_label se for texto customizado (não vazio e não o padrão "Interact").
func get_display_label() -> String:
	var custom: String = interact_label.strip_edges()
	if custom.length() > 0 and custom != "Interact":
		return custom
	match dungeon_mode:
		DungeonMode.ENTRANCE:
			return "Entrar na dungeon"
		DungeonMode.EXIT:
			return "Voltar ao mapa"
		_:
			return "Teleportar" if pad_type == PadType.IN else "Voltar"

func _ready() -> void:
	call_deferred("_apply_label_text")
	if dungeon_mode == DungeonMode.ENTRANCE:
		var root := get_tree().root
		if not root.get_node_or_null(dungeon_path):
			push_warning("Landingpad: dungeon_path inválido em _ready: %s" % dungeon_path)
		if not root.get_node_or_null(spawn_marker_path):
			push_warning("Landingpad: spawn_marker_path inválido em _ready: %s" % spawn_marker_path)

func _apply_label_text() -> void:
	var lbl: Label = get_node_or_null("SubViewport/Label") as Label
	if lbl:
		lbl.text = get_display_label()

func _play_sfx_id(id: StringName) -> void:
	if SoundManager and SoundManager.has_sfx(id):
		SoundManager.play_sfx_id(id)

func _trigger_particles() -> void:
	if particles_node.is_empty():
		return
	var p = get_node_or_null(particles_node)
	if p == null:
		return
	if p is GPUParticles3D:
		p.restart()
		p.emitting = true
	elif p is CPUParticles3D:
		p.restart()
		p.emitting = true

func _do_enter_dungeon(body: Node, dungeon: Node, spawn_marker: Node3D) -> void:
	if DungeonManager:
		DungeonManager.enter_dungeon(dungeon, spawn_marker.global_position)
	if fade_duration > 0.0:
		var sf = get_node_or_null("/root/ScreenFade")
		if sf:
			sf.fade_in(fade_duration)
	dungeon_entered.emit(body, dungeon)

func _do_exit_dungeon(body: Node) -> void:
	if DungeonManager:
		DungeonManager.exit_dungeon()
	if fade_duration > 0.0:
		var sf = get_node_or_null("/root/ScreenFade")
		if sf:
			sf.fade_in(fade_duration)
	dungeon_exited.emit(body)

func _do_teleport(body: CharacterBody3D, target_pos: Vector3, do_fade_in: bool = false) -> void:
	var from_pos := body.global_position
	if body.has_method("request_teleport"):
		body.request_teleport(target_pos)
	else:
		body.global_position = target_pos
		body.velocity = Vector3.ZERO
	if do_fade_in:
		var sf = get_node_or_null("/root/ScreenFade")
		if sf:
			sf.fade_in(fade_duration)
	teleported.emit(body, from_pos, target_pos)

func interact(interactor: Node) -> void:
	var body: CharacterBody3D = interactor as CharacterBody3D
	if not body:
		body = interactor.get_node_or_null("..") as CharacterBody3D
	if not body or not body.is_in_group("player"):
		return

	var t := Time.get_ticks_msec() / 1000.0
	if (t - _last_use_time) < cooldown_seconds:
		return
	_last_use_time = t

	# ——— Saída da dungeon ———
	if dungeon_mode == DungeonMode.EXIT:
		#_play_sfx_id(&"dungeon_exit")
		_play_sfx_id(&"teleport")
		_trigger_particles()
		if DungeonManager:
			if fade_duration > 0.0:
				var sf = get_node_or_null("/root/ScreenFade")
				if sf:
					sf.fade_out_then(fade_duration, func(): _do_exit_dungeon(body), loading_hold_duration)
				else:
					_do_exit_dungeon(body)
			else:
				_do_exit_dungeon(body)
		return

	# ——— Entrada na dungeon ———
	if dungeon_mode == DungeonMode.ENTRANCE:
		if not DungeonManager:
			push_warning("Landingpad: DungeonManager não encontrado.")
			return
		var root := get_tree().root
		var dungeon: Node = root.get_node_or_null(dungeon_path)
		var spawn_marker: Node3D = root.get_node_or_null(spawn_marker_path) as Node3D
		if not dungeon:
			push_warning("Landingpad: dungeon não encontrado: %s" % dungeon_path)
			return
		if not spawn_marker:
			push_warning("Landingpad: spawn marker não encontrado: %s" % spawn_marker_path)
			return
		#_play_sfx_id(&"dungeon_enter")
		_play_sfx_id(&"teleport")
		_trigger_particles()
		if fade_duration > 0.0:
			var sf = get_node_or_null("/root/ScreenFade")
			if sf:
				sf.fade_out_then(fade_duration, func(): _do_enter_dungeon(body, dungeon, spawn_marker), loading_hold_duration)
			else:
				_do_enter_dungeon(body, dungeon, spawn_marker)
		else:
			_do_enter_dungeon(body, dungeon, spawn_marker)
		return

	# ——— Teleporte normal entre pads ———
	var dest := _get_destination()
	if not dest:
		push_warning("Landingpad: destination_pad não definido.")
		return
	var target_pos := dest.global_position
	target_pos.y += 1
	_play_sfx_id(&"teleport")
	_trigger_particles()
	if use_fade_on_teleport and fade_duration > 0.0:
		var sf = get_node_or_null("/root/ScreenFade")
		if sf:
			sf.fade_out_then(fade_duration, func(): _do_teleport(body, target_pos, true))
		else:
			_do_teleport(body, target_pos, false)
	else:
		_do_teleport(body, target_pos, false)

func on_focus_enter() -> void:
	var lbl: Label = get_node_or_null("SubViewport/Label") as Label
	if lbl:
		lbl.text = get_display_label()
		lbl.show()

func on_focus_exit() -> void:
	if has_node("SubViewport/Label"):
		$SubViewport/Label.hide()
