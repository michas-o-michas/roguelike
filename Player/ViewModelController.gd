extends Node3D
## ViewModelController — anima a arma em primeira pessoa.
## Attach no ViewModelPivot (filho direto da Camera3D).
## A posição/rotação BASE é definida diretamente no nó pelo editor.
##
## Hierarquia: Player → CameraRig → Camera3D → ViewModelPivot (este script)

# ── Bob (arma oscila ao andar) ────────────────────────────────────────────────
@export_group("Bob (andar/correr)")
@export var bob_enabled    := true
@export var bob_walk_freq  := 1.8    ## ciclos/s ao caminhar
@export var bob_run_freq   := 2.6    ## ciclos/s ao correr
@export var bob_walk_amp   := 0.010  ## amplitude Y ao caminhar
@export var bob_run_amp    := 0.018  ## amplitude Y ao correr
@export var bob_side_mult  := 0.5    ## balanço lateral (X)
@export var bob_fade       := 8.0    ## velocidade de fade ao parar

# ── Sway (arma reage ao mouse) ────────────────────────────────────────────────
@export_group("Sway (mouse)")
@export var sway_enabled   := true
@export var sway_h         := 0.005  ## deslocamento X por px do mouse
@export var sway_v         := 0.003  ## deslocamento Y por px do mouse
@export var sway_max       := 0.05   ## deslocamento máximo (metros)
@export var sway_return    := 9.0    ## velocidade de retorno ao centro

# ── Animação de golpe ─────────────────────────────────────────────────────────
@export_group("Swing (ataque)")
## Rotação extra em X durante o swing (para frente; negativo = "desce a espada")
@export var swing_rot_x    := -55.0
## Rotação extra em Z durante o swing (lateral; para espada cruzar a tela)
@export var swing_rot_z    := 25.0
## Empurrão para frente durante o swing (metros)
@export var swing_thrust_z := -0.06
## Empurrão lateral durante o swing
@export var swing_thrust_x := -0.06
## Duração da ida (impacto)
@export var swing_go_time  := 0.10
## Duração da volta (retorno)
@export var swing_back_time := 0.28

# ── Internas ──────────────────────────────────────────────────────────────────
var _player: CharacterBody3D = null

## Transform base capturado do editor em _ready (nunca muda)
var _base_pos: Vector3
var _base_rot: Vector3

## Offsets acumulados (adicionados ao base a cada frame)
var _bob_t:   float = 0.0
var _bob_y:   float = 0.0
var _bob_x:   float = 0.0
var _sway:    Vector3 = Vector3.ZERO
var _swing_pos: Vector3 = Vector3.ZERO
var _swing_rot: Vector3 = Vector3.ZERO

var _swinging := false
var _tween: Tween = null


func _ready() -> void:
	# Salva o transform base definido no editor
	_base_pos = position
	_base_rot = rotation_degrees

	# Localiza o player pela hierarquia: ViewModelPivot → Camera3D → CameraRig → Player
	var cam := get_parent() as Camera3D
	if cam:
		var rig := cam.get_parent()
		if rig:
			_player = rig.get_parent() as CharacterBody3D
	if not _player:
		push_warning("ViewModelController: Player não encontrado. Hierarquia esperada: Player/CameraRig/Camera3D/ViewModelPivot.")


func _input(event: InputEvent) -> void:
	if not sway_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var dx := (event as InputEventMouseMotion).relative.x
		var dy := (event as InputEventMouseMotion).relative.y
		_sway.x -= dx * sway_h
		_sway.y += dy * sway_v
		_sway = _sway.clampf(-sway_max, sway_max)


func _process(delta: float) -> void:
	_update_bob(delta)
	_update_sway(delta)
	_apply_transform()


# ── Animação de golpe (chamada pelo WeaponHandler) ────────────────────────────

## Dispara a animação de swing. Pode ser chamado externamente pelo WeaponHandler.
func play_swing() -> void:
	if _swinging:
		_cancel_swing()

	_swinging = true
	_tween = create_tween().set_trans(Tween.TRANS_QUINT)

	# --- Ida: balança para frente rapidamente ---
	_tween.tween_method(_set_swing_pos, _swing_pos, Vector3(swing_thrust_x, 0.0, swing_thrust_z), swing_go_time)
	_tween.parallel().tween_method(_set_swing_rot, _swing_rot, Vector3(swing_rot_x, 0.0, swing_rot_z), swing_go_time)

	# --- Volta: retorna ao repouso com easing suave ---
	_tween.tween_method(_set_swing_pos, Vector3(swing_thrust_x, 0.0, swing_thrust_z), Vector3.ZERO, swing_back_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_method(_set_swing_rot, Vector3(swing_rot_x, 0.0, swing_rot_z), Vector3.ZERO, swing_back_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.tween_callback(func(): _swinging = false)


func _cancel_swing() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_swing_pos = Vector3.ZERO
	_swing_rot = Vector3.ZERO
	_swinging  = false


func _set_swing_pos(v: Vector3) -> void:
	_swing_pos = v

func _set_swing_rot(v: Vector3) -> void:
	_swing_rot = v


# ── Bob ───────────────────────────────────────────────────────────────────────

func _update_bob(delta: float) -> void:
	if not _player:
		return
	var horz := Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()
	var grounded := _player.is_on_floor()

	if bob_enabled and horz > 0.5 and grounded:
		var running := horz > 9.0
		var freq := bob_run_freq if running else bob_walk_freq
		var amp  := bob_run_amp  if running else bob_walk_amp
		_bob_t += delta * freq * TAU
		_bob_y = lerpf(_bob_y, sin(_bob_t) * amp,                      0.25)
		_bob_x = lerpf(_bob_x, sin(_bob_t * 0.5) * amp * bob_side_mult, 0.25)
	else:
		var k := 1.0 - exp(-bob_fade * delta)
		_bob_y = lerpf(_bob_y, 0.0, k)
		_bob_x = lerpf(_bob_x, 0.0, k)


# ── Sway ──────────────────────────────────────────────────────────────────────

func _update_sway(delta: float) -> void:
	_sway = _sway.lerp(Vector3.ZERO, sway_return * delta)


# ── Aplicação final ───────────────────────────────────────────────────────────

func _apply_transform() -> void:
	position        = _base_pos + Vector3(_bob_x + _sway.x, _bob_y + _sway.y, 0.0) + _swing_pos
	rotation_degrees = _base_rot + _swing_rot
