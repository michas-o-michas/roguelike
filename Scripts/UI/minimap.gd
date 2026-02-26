extends Control
class_name Minimap
## Minimapa com fundo gerado proceduralmente a partir das cores do terreno.
## Estilo Minecraft: amostra get_terrain_color() do InfiniteWorldGenerator,
## aplica hillshading norte-sul para relevo topográfico.
## Mapa rotativo — ícone do player fixo no centro apontando para cima.

# ── Alcance e tamanho ─────────────────────────────────────────────────────────
@export_group("Tamanho / Alcance")
@export var map_radius: float = 80.0
@export var map_range:  float = 120.0
@export var dot_size:   float = 3.0

@export_group("Performance")
@export var refresh_interval: float = 0.15
## Resolução da textura do mapa (pixels). 128 = boa qualidade, 64 = mais leve.
@export var map_resolution: int = 128
## Linhas de textura geradas por frame (maior = mais rápido, mais pesado).
@export var rows_per_frame:  int = 6

@export_group("Camadas visíveis")
@export var show_enemies:   bool = true
@export var show_dungeons:  bool = true
@export var show_resources: bool = false

# ── Paleta UI ─────────────────────────────────────────────────────────────────
const C_BG       := Color(0.03, 0.05, 0.10, 0.92)
const C_GRID     := Color(1.00, 1.00, 1.00, 0.05)
const C_CROSS    := Color(1.00, 1.00, 1.00, 0.14)
const C_BORDER   := Color(0.50, 0.57, 0.68, 0.88)
const C_BORDER2  := Color(0.22, 0.27, 0.38, 0.60)
const C_PLAYER   := Color(1.00, 1.00, 1.00, 1.00)
const C_PLAYER_R := Color(0.45, 0.60, 1.00, 0.85)
const C_ENEMY    := Color(1.00, 0.22, 0.12, 1.00)
const C_RESOURCE := Color(0.28, 0.88, 0.38, 1.00)
const C_DUNGEON  := Color(0.72, 0.22, 1.00, 1.00)
const C_LABEL    := Color(0.65, 0.70, 0.80, 0.28)

const _SEGS := 64

# ── Geração de textura ────────────────────────────────────────────────────────
var _map_image:   Image             = null
var _map_texture: ImageTexture      = null
var _prev_row_h:  PackedFloat32Array = PackedFloat32Array()
var _gen_row:     int    = 0
var _gen_active:  bool   = false
var _gen_pp:      Vector3 = Vector3.ZERO
var _last_gen_pos: Vector3 = Vector3(INF, INF, INF)
const _REGEN_DIST := 8.0   # metros de movimento para disparar nova geração

# ── Estado geral ──────────────────────────────────────────────────────────────
var _player:    Node3D = null
var _world_gen: Node   = null
var _refresh_t: float  = 0.0
var _visible:   bool   = true

var _enemies:   Array = []
var _resources: Array = []
var _dungeons:  Array = []


func _ready() -> void:
	var side := int(map_radius + 2) * 2
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	if not InputMap.has_action("ui_minimap"):
		var ev := InputEventKey.new()
		ev.keycode = KEY_M
		InputMap.add_action("ui_minimap")
		InputMap.action_add_event("ui_minimap", ev)

	_map_image = Image.create(map_resolution, map_resolution, false, Image.FORMAT_RGB8)
	_prev_row_h.resize(map_resolution)
	_prev_row_h.fill(0.0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_minimap"):
		_visible = not _visible
		visible  = _visible


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	if not _world_gen:
		_world_gen = get_tree().get_first_node_in_group("world_generator")

	if is_instance_valid(_player) and _world_gen:
		# Inicia nova geração se player se moveu o suficiente
		if not _gen_active:
			if _player.global_position.distance_to(_last_gen_pos) > _REGEN_DIST:
				_start_generation()

		# Gera N linhas por frame (não trava o jogo)
		if _gen_active:
			_process_gen_rows()

	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = refresh_interval
		_refresh_entities()

	queue_redraw()


# ── Geração da textura do mapa ────────────────────────────────────────────────

func _start_generation() -> void:
	if not _world_gen or not is_instance_valid(_player):
		return
	_gen_pp       = _player.global_position
	_last_gen_pos = _gen_pp
	_gen_row      = 0
	_gen_active   = true
	_prev_row_h.fill(0.0)


func _process_gen_rows() -> void:
	var step: float = (map_range * 2.0) / float(map_resolution)
	var half: float = map_resolution * 0.5
	var end_row: int = mini(_gen_row + rows_per_frame, map_resolution)

	for py in range(_gen_row, end_row):
		for px in range(map_resolution):
			# Norte-up: py=0 = topo = Norte = -Z no mundo
			var wx: float = _gen_pp.x + (float(px) - half) * step
			var wz: float = _gen_pp.z + (float(py) - half) * step

			var height: float = _world_gen.call("get_terrain_height", wx, wz)
			var color:  Color = _world_gen.call("get_terrain_color",  wx, wz, height)

			# Hillshading norte→sul: encostas viradas a norte ficam mais claras,
			# viradas a sul mais escuras — idêntico ao estilo Minecraft
			var north_h: float  = _prev_row_h[px]
			var slope: float    = (height - north_h) / step * 0.18
			slope = clampf(slope, -0.45, 0.45)
			if slope > 0.0:
				color = color.lightened(slope)
			elif slope < 0.0:
				color = color.darkened(-slope)

			_map_image.set_pixel(px, py, color)
			_prev_row_h[px] = height

	_gen_row = end_row

	if _gen_row >= map_resolution:
		_gen_active = false
		if _map_texture == null:
			_map_texture = ImageTexture.create_from_image(_map_image)
		else:
			_map_texture.update(_map_image)


# ── Entidades ──────────────────────────────────────────────────────────────────

func _refresh_entities() -> void:
	if not is_instance_valid(_player):
		return
	var pp  := _player.global_position
	var rsq := map_range * map_range * 1.2

	if show_enemies:
		_enemies.clear()
		for node in get_tree().get_nodes_in_group("enemy"):
			if node is Node3D and is_instance_valid(node as Node3D):
				if (node as Node3D).global_position.distance_squared_to(pp) < rsq:
					_enemies.append(node)

	if show_resources:
		_resources.clear()
		for node in get_tree().get_nodes_in_group("interactable"):
			if node is Node3D and is_instance_valid(node as Node3D):
				if (node as Node3D).global_position.distance_squared_to(pp) < rsq:
					_resources.append(node)

	if show_dungeons:
		_dungeons.clear()
		for node in get_tree().get_nodes_in_group("portal"):
			if node is Node3D and is_instance_valid(node as Node3D):
				if (node as Node3D).global_position.distance_squared_to(pp) < rsq:
					_dungeons.append(node.global_position)


# ── Desenho ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not is_instance_valid(_player):
		return

	var center := Vector2(map_radius + 1.0, map_radius + 1.0)
	var pp     := _player.global_position
	var rot    := _player.rotation.y
	var scale  := map_radius / map_range
	var clip_r := map_radius - 4.0

	# Fundo escuro de fallback (antes da textura gerar)
	draw_circle(center, map_radius, C_BG)

	# ── Frame rotativo ────────────────────────────────────────────────────────
	draw_set_transform(center, rot, Vector2.ONE)

	# Textura do mapa (gerada do terreno, rotaciona com o mapa)
	if _map_texture:
		_draw_map_circle(_map_texture)

	# Grade sutil por cima da textura
	_draw_world_grid(pp, clip_r)

	# Cruz central de referência
	var arm := map_radius * 0.13
	draw_line(Vector2(-arm, 0.0), Vector2(arm, 0.0),  C_CROSS, 0.8)
	draw_line(Vector2(0.0, -arm), Vector2(0.0,  arm), C_CROSS, 0.8)

	# Entidades
	if show_resources:
		for node in _resources:
			if is_instance_valid(node):
				_dot(pp, (node as Node3D).global_position, scale, clip_r,
						C_RESOURCE, dot_size - 0.5)

	if show_dungeons:
		for world_pos: Vector3 in _dungeons:
			var mp := Vector2(world_pos.x - pp.x, world_pos.z - pp.z) * scale
			if mp.length_squared() < clip_r * clip_r:
				draw_circle(mp, dot_size + 1.5, C_DUNGEON)
				draw_arc(mp, dot_size + 5.0, 0.0, TAU, 16,
						Color(C_DUNGEON.r, C_DUNGEON.g, C_DUNGEON.b, 0.40), 1.0)

	if show_enemies:
		for node in _enemies:
			if is_instance_valid(node):
				_dot(pp, (node as Node3D).global_position, scale, clip_r,
						C_ENEMY, dot_size)

	# ── Sai do frame rotativo ─────────────────────────────────────────────────
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── UI fixa ───────────────────────────────────────────────────────────────
	_draw_player_arrow(center)
	draw_arc(center, map_radius - 3.5, 0.0, TAU, 64, C_BORDER2, 1.0)
	draw_arc(center, map_radius,       0.0, TAU, 64, C_BORDER,  2.0)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(center.x - 9.0, 11.0), "MAP",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_LABEL)


# ── Helpers ────────────────────────────────────────────────────────────────────

## Textura como polígono circular com UV mapeado — chamado no frame rotativo.
func _draw_map_circle(tex: Texture2D) -> void:
	var pts  := PackedVector2Array()
	var uvs  := PackedVector2Array()
	var cols := PackedColorArray()
	for i in range(_SEGS):
		var a := float(i) / _SEGS * TAU
		pts.append(Vector2(cos(a), sin(a)) * map_radius)
		uvs.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
		cols.append(Color.WHITE)
	draw_polygon(pts, cols, uvs, tex)


func _dot(player_pos: Vector3, world_pos: Vector3,
		scale: float, clip_r: float, color: Color, radius: float) -> void:
	var mp := Vector2(world_pos.x - player_pos.x, world_pos.z - player_pos.z) * scale
	if mp.length_squared() < clip_r * clip_r:
		draw_circle(mp, radius, color)


func _draw_world_grid(player_pos: Vector3, clip_r: float) -> void:
	var cell  := map_range / 3.0
	var scale := map_radius / map_range
	var ox    := fposmod(player_pos.x, cell) * scale
	var oz    := fposmod(player_pos.z, cell) * scale
	for i in range(-4, 5):
		var lx  := i * cell * scale - ox
		var dsc := clip_r * clip_r - lx * lx
		if dsc >= 0.0:
			var hh := sqrt(dsc)
			draw_line(Vector2(lx, -hh), Vector2(lx, hh), C_GRID, 0.65)
		var lz := i * cell * scale - oz
		dsc = clip_r * clip_r - lz * lz
		if dsc >= 0.0:
			var hw := sqrt(dsc)
			draw_line(Vector2(-hw, lz), Vector2(hw, lz), C_GRID, 0.65)


func _draw_player_arrow(center: Vector2) -> void:
	var tip := center + Vector2( 0.0, -9.5)
	var br  := center + Vector2( 5.5,  5.5)
	var mid := center + Vector2( 0.0,  2.0)
	var bl  := center + Vector2(-5.5,  5.5)
	var sh  := Vector2(0.8, 0.8)
	draw_colored_polygon(
		PackedVector2Array([tip + sh, br + sh, mid + sh, bl + sh]),
		Color(0.0, 0.0, 0.0, 0.35))
	draw_colored_polygon(PackedVector2Array([tip, br, mid, bl]), C_PLAYER)
	draw_polyline(PackedVector2Array([tip, br, mid, bl, tip]), C_PLAYER_R, 1.0)
