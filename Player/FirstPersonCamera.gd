extends Camera3D
## Câmera primeira pessoa — profissional.
## Attach na Camera3D filha de CameraRig (filho de Player).
## CameraRig (Node3D) gerencia o pitch (rotation_degrees.x via Player.gd).
## Esta câmera fica fixa em (0,0,0) relativo ao CameraRig e adiciona apenas bob e FOV.

# ── FOV dinâmico ──────────────────────────────────────────────────────────────
@export_group("FOV")
@export var fov_base: float = 75.0
@export var fov_sprint_add: float = 5.0
@export var fov_speed_threshold: float = 10.0
@export var fov_smooth: float = 6.0

# ── Head bob ──────────────────────────────────────────────────────────────────
@export_group("Head Bob")
@export var bob_enabled: bool = true
@export var bob_walk_freq: float  = 1.8   ## ciclos/s caminhando
@export var bob_run_freq: float   = 2.6   ## ciclos/s correndo
@export var bob_walk_amp: float   = 0.022 ## amplitude vertical (metros) ao caminhar
@export var bob_run_amp: float    = 0.038 ## amplitude vertical (metros) ao correr
@export var bob_tilt_deg: float   = 0.40  ## oscilação lateral máxima (graus)
@export var bob_fade_speed: float = 8.0   ## velocidade de fade-out quando para

# ── Internas ──────────────────────────────────────────────────────────────────
var _bob_t: float    = 0.0   # tempo acumulado do bob
var _bob_y: float    = 0.0   # posição Y suavizada
var _bob_tilt: float = 0.0   # rotação Z suavizada
var _cur_fov: float  = 75.0
var _player: CharacterBody3D = null


func _ready() -> void:
	fov = fov_base
	_cur_fov = fov_base
	# Hierarquia: Camera3D → CameraRig → Player
	var rig := get_parent()
	if rig:
		_player = rig.get_parent() as CharacterBody3D
	if not _player:
		push_warning("FirstPersonCamera: Player não encontrado. Esperado: Player/CameraRig/Camera3D.")


func _process(delta: float) -> void:
	_update_fov(delta)
	if bob_enabled:
		_update_bob(delta)


# ── FOV ───────────────────────────────────────────────────────────────────────

func _update_fov(delta: float) -> void:
	if not _player:
		return
	var speed := _player.velocity.length()
	var t := clampf((speed - fov_speed_threshold) / 6.0, 0.0, 1.0)
	var target_fov := fov_base + fov_sprint_add * t
	var k := 1.0 - exp(-fov_smooth * delta)
	_cur_fov = lerpf(_cur_fov, target_fov, k)
	fov = _cur_fov


# ── Head Bob ──────────────────────────────────────────────────────────────────

func _update_bob(delta: float) -> void:
	if not _player:
		return

	var horz_speed := Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()
	var grounded   := _player.is_on_floor()

	if horz_speed > 0.5 and grounded:
		var running := horz_speed > 9.0
		var freq    := bob_run_freq  if running else bob_walk_freq
		var amp     := bob_run_amp   if running else bob_walk_amp

		_bob_t += delta * freq * TAU
		var raw_y    := sin(_bob_t) * amp
		var raw_tilt := sin(_bob_t) * bob_tilt_deg

		# Suavização rápida ao entrar no bob
		_bob_y    = lerpf(_bob_y,    raw_y,    0.25)
		_bob_tilt = lerpf(_bob_tilt, raw_tilt, 0.25)
	else:
		# Fade-out suave ao parar
		var k := 1.0 - exp(-bob_fade_speed * delta)
		_bob_y    = lerpf(_bob_y,    0.0, k)
		_bob_tilt = lerpf(_bob_tilt, 0.0, k)

	position.y         = _bob_y
	rotation_degrees.z = _bob_tilt
