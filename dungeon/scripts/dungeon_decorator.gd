class_name DungeonDecorator
extends Node3D

## Decora a dungeon proceduralmente: pilares de pedra, tochas e atmosfera.
## Adicione como filho do nó Room. Configure arena_size para o scale do plano.

@export var arena_size: float = 100.0
@export var torch_energy: float = 5.0
@export var torch_range: float = 10.0
@export var fog_density: float = 0.022

const PILLAR_W := 1.4
const PILLAR_H := 4.8

## Posições base (arena 100-unit). Escaladas por arena_size/100.
const _PILLAR_OFFSETS: Array = [
	Vector2(-12.0,  -8.0),
	Vector2( 12.0,  -8.0),
	Vector2(-20.0, -18.0),
	Vector2( 20.0, -18.0),
	Vector2( -8.0, -28.0),
	Vector2(  8.0, -28.0),
	Vector2(-16.0, -40.0),
	Vector2( 16.0, -40.0),
	Vector2(  0.0, -44.0),
]

func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	_apply_atmosphere()
	_build_pillars()
	_build_wall_torches()


# ── Atmosfera ─────────────────────────────────────────────────────────────────

func _apply_atmosphere() -> void:
	var room: Node3D = get_parent()

	# Esmaecer luz direcional — tochas são a fonte principal
	var dir := room.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if dir:
		dir.light_energy = 0.25
		dir.light_color  = Color(0.50, 0.45, 0.55)

	# Ambiente escuro com névoa suave
	var we := room.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not (we and we.environment):
		return
	var e := we.environment
	e.background_mode      = Environment.BG_COLOR
	e.background_color     = Color(0.010, 0.005, 0.012)
	e.ambient_light_color  = Color(0.07, 0.05, 0.09)
	e.ambient_light_energy = 0.18
	e.fog_enabled          = true
	e.fog_light_color      = Color(0.04, 0.02, 0.05)
	e.fog_density          = fog_density
	e.glow_enabled         = true
	e.glow_intensity       = 1.2
	e.glow_bloom           = 0.12


# ── Pilares ───────────────────────────────────────────────────────────────────

func _build_pillars() -> void:
	var stone := _stone_mat()
	var sf    := arena_size / 100.0
	for off: Vector2 in _PILLAR_OFFSETS:
		var base := Vector3(off.x * sf, 0.0, off.y * sf)
		_place_pillar(base, stone)
		_place_torch(base + Vector3(0.0, PILLAR_H + 0.5, 0.0))


func _place_pillar(base: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.position = base + Vector3(0.0, PILLAR_H * 0.5, 0.0)

	var mi  := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size     = Vector3(PILLAR_W, PILLAR_H, PILLAR_W)
	box.material = mat
	mi.mesh      = box
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var sh  := BoxShape3D.new()
	sh.size   = Vector3(PILLAR_W, PILLAR_H, PILLAR_W)
	col.shape = sh
	body.add_child(col)

	add_child(body)


# ── Tochas ────────────────────────────────────────────────────────────────────

func _place_torch(world_pos: Vector3) -> void:
	# Chama animada (mesh emissivo)
	var mi  := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.20
	sph.height = 0.40
	var fm := StandardMaterial3D.new()
	fm.albedo_color               = Color(1.0, 0.65, 0.1)
	fm.emission_enabled           = true
	fm.emission                   = Color(1.0, 0.40, 0.05)
	fm.emission_energy_multiplier = 4.5
	sph.material = fm
	mi.mesh      = sph
	mi.position  = world_pos
	add_child(mi)

	# Luz pontual (sem sombra para performance)
	var omni := OmniLight3D.new()
	omni.position         = world_pos
	omni.light_color      = Color(1.0, 0.55, 0.18)
	omni.light_energy     = torch_energy
	omni.omni_range       = torch_range
	omni.omni_attenuation = 1.6
	omni.shadow_enabled   = false
	add_child(omni)


func _build_wall_torches() -> void:
	# Coloca tochas próximas às paredes laterais e fundos
	var r := arena_size * 0.82
	var h := 3.5
	var pts: Array[Vector3] = [
		Vector3(-r,       h,  0.0),
		Vector3( r,       h,  0.0),
		Vector3( 0.0,     h, -r),
		Vector3(-r * 0.5, h, -r * 0.75),
		Vector3( r * 0.5, h, -r * 0.75),
	]
	for pt: Vector3 in pts:
		_place_torch(pt)


# ── Materiais ─────────────────────────────────────────────────────────────────

func _stone_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.27, 0.24, 0.22)
	mat.roughness    = 0.92
	mat.metallic     = 0.0
	return mat
