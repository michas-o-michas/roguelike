extends Node3D
## Barra de vida 3D no estilo FloatingHealthBar: borda, fundo, barra de dano (vermelha, atraso) e vida (verde).
## Edite na cena: Border, Back, DamageBar, Fill (cores e tamanhos nos materiais e meshes).
## Posicione o nó na cena do mob. Billboard para a câmera.

@export var hide_when_full: bool = true
@export var damage_bar_tween_duration: float = 0.4

@onready var _back_mesh: MeshInstance3D = $Back
@onready var _damage_mesh: MeshInstance3D = $DamageBar
@onready var _fill_mesh: MeshInstance3D = $Fill

var _health_component: HealthComponent
var _max_health: float = 100.0
var _current_health: float = 100.0
var _bar_width: float = 0.8

func _ready() -> void:
	if _back_mesh and _back_mesh.mesh is QuadMesh:
		_bar_width = (_back_mesh.mesh as QuadMesh).size.x
	elif _fill_mesh and _fill_mesh.mesh is QuadMesh:
		_bar_width = (_fill_mesh.mesh as QuadMesh).size.x

func set_health_component(hc: HealthComponent) -> void:
	if _health_component:
		if _health_component.health_changed.is_connected(_on_health_changed):
			_health_component.health_changed.disconnect(_on_health_changed)
	_health_component = hc
	if not _health_component:
		return
	_max_health = _health_component.max_health
	_current_health = _health_component.current_health
	_health_component.health_changed.connect(_on_health_changed)
	_update_fill_transform()
	_update_damage_transform(_current_health / _max_health if _max_health > 0 else 1.0)
	if hide_when_full and _current_health >= _max_health:
		visible = false
		set_process(false)
	else:
		visible = true
		set_process(true)

func _on_health_changed(_old: float, new_val: float) -> void:
	_current_health = new_val
	var pct := clampf(_current_health / _max_health, 0.0, 1.0) if _max_health > 0 else 1.0
	_update_fill_transform()
	if _damage_mesh:
		var tween = create_tween()
		tween.tween_method(_update_damage_transform, _damage_mesh.scale.x, pct, damage_bar_tween_duration).set_trans(Tween.TRANS_CUBIC)
	if hide_when_full and _current_health >= _max_health:
		visible = false
		set_process(false)
	else:
		visible = true
		set_process(true)

func _update_fill_transform() -> void:
	if not _fill_mesh:
		return
	var pct := 1.0
	if _max_health > 0:
		pct = clampf(_current_health / _max_health, 0.0, 1.0)
	_fill_mesh.scale = Vector3(pct, 1.0, 1.0)
	_fill_mesh.position = Vector3(_bar_width * -0.5 * (1.0 - pct), 0.0, 0.01)

func _update_damage_transform(pct: float) -> void:
	if not _damage_mesh:
		return
	var p := clampf(pct, 0.0, 1.0)
	_damage_mesh.scale = Vector3(p, 1.0, 1.0)
	_damage_mesh.position = Vector3(_bar_width * -0.5 * (1.0 - p), 0.0, 0.0)

func _process(_delta: float) -> void:
	var cam = get_viewport().get_camera_3d()
	if cam:
		look_at(cam.global_position)
