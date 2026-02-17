extends Node3D
## Portal de transição de cena. Sempre usa cena empacotada (PackedScene).
## Ao entrar, define o marcador de spawn (MarkerIn / MarkerOut); a cena de destino
## deve ter um nó SpawnAtMarker e o nó do marcador (ex.: MarkerIn ou MarkerOut).

@export var target_scene: PackedScene
## Cena para onde ir (arraste a .tscn no Inspector)

@export var spawn_marker_name: String = "MarkerIn"
## Nome do nó na cena de destino onde o jogador deve aparecer. Use "MarkerIn" para entrar (dungeon/playground) e "MarkerOut" para voltar ao mundo.

@export var require_player_group: bool = true
## Só trocar cena se o body estiver no grupo "player"

@export var one_shot: bool = false
## Se true, o portal só funciona uma vez

@export var cooldown_seconds: float = 0.0
## Tempo mínimo entre trocas (evita trocar várias vezes ao ficar na área)

var _area: Area3D
var _last_trigger_time: float = -999.0

func _ready() -> void:
	_area = _find_area()
	if not _area:
		push_warning("ScenePortal: Nenhum Area3D encontrado em %s. Adicione um Area3D como filho." % get_path())
		return
	if not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)


func _find_area() -> Area3D:
	var n: Node = self
	if n is Area3D:
		return n as Area3D
	for c in get_children():
		if c is Area3D:
			return c as Area3D
	return null


func _on_body_entered(body: Node3D) -> void:
	if require_player_group and not body.is_in_group("player"):
		return
	if cooldown_seconds > 0.0 and (Time.get_ticks_msec() / 1000.0 - _last_trigger_time) < cooldown_seconds:
		return

	_last_trigger_time = Time.get_ticks_msec() / 1000.0
	_go_to_scene()


func _go_to_scene() -> void:
	if not target_scene:
		push_error("ScenePortal: target_scene não definido. Atribua a cena no Inspector.")
		return

	var portal_spawn = get_node_or_null("/root/PortalSpawn")
	if portal_spawn:
		portal_spawn.next_marker_name = spawn_marker_name
	var err: Error = get_tree().change_scene_to_packed(target_scene)

	if err != OK and portal_spawn:
		portal_spawn.next_marker_name = ""
		push_error("ScenePortal: Falha ao trocar cena (código %s)." % err)
		return

	if one_shot and _area and _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.disconnect(_on_body_entered)
