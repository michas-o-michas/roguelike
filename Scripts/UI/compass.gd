# compass.gd
# Bússola 2D na UI: aponta para um alvo (base/spawn ou Norte).
# Quando target_position está definido, a agulha aponta na direção do alvo no plano XZ.

extends Control

## Posição no mundo para onde a agulha aponta (ex.: Root Camp, spawn). Se não definido, aponta para Norte (0,0,-1).
var target_position: Vector3 = Vector3.ZERO

## Se true, usa target_position; se false e target_position é zero, aponta para Norte.
var use_target: bool = true

## Raio do círculo da bússola em pixels
@export var compass_radius: int = 44

## Cor da borda externa (dourado/âmbar)
@export var border_color: Color = Color(0.55, 0.42, 0.28, 1.0)

## Cor do fundo do mostrador
@export var fill_color: Color = Color(0.14, 0.11, 0.08, 0.95)

## Cor do anel interno (relevo)
@export var inner_ring_color: Color = Color(0.22, 0.17, 0.12, 1.0)

## Cor da agulha (direção do alvo) — destaque
@export var needle_color: Color = Color(0.92, 0.72, 0.35, 1.0)

## Cor da sombra/contorno da agulha
@export var needle_outline_color: Color = Color(0.25, 0.18, 0.1, 1.0)

## Cor dos marcadores cardeais (N, traços)
@export var tick_color: Color = Color(0.5, 0.42, 0.32, 0.9)

var _player: Node3D
var _home_set_once: bool = false

func _ready() -> void:
	call_deferred("_find_player")
	# Opcional: definir "casa" como posição do jogador após spawn (após 1.5s)
	await get_tree().create_timer(1.5).timeout
	_set_home_from_player_if_needed()

func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	# Se estiver como filho do Player, subir na árvore
	if not _player:
		var p: Node = get_parent()
		while p:
			if p is CharacterBody3D and p.is_in_group("player"):
				_player = p as Node3D
				break
			p = p.get_parent()

## Define o alvo da bússola como a posição atual do jogador (útil para marcar "base").
func set_home_from_player() -> void:
	if _player and is_instance_valid(_player):
		target_position = _player.global_position
		use_target = true

func _set_home_from_player_if_needed() -> void:
	if not _home_set_once and _player and is_instance_valid(_player):
		target_position = _player.global_position
		use_target = true
		_home_set_once = true

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var r := minf(compass_radius, minf(size.x, size.y) * 0.45)

	# ——— Mostrador (estilo “relógio antigo”) ———
	# Sombra suave atrás (offset 2px)
	draw_arc(center + Vector2(2, 2), r + 2, 0, TAU, 48, Color(0, 0, 0, 0.35), 4.0)
	# Borda externa dourada (2px)
	draw_arc(center, r + 1, 0, TAU, 48, border_color, 2.5)
	# Fundo principal
	draw_circle(center, r - 0.5, fill_color)
	# Anel interno (relevo)
	draw_arc(center, r - 4, 0, TAU, 48, inner_ring_color, 2.0)
	# Centro escuro
	draw_circle(center, r - 8, Color(0.08, 0.06, 0.04, 1.0))

	# ——— Marcadores cardeais (traços) ———
	var tick_len_short := 5.0
	var tick_len_north := 8.0
	for i in 4:
		var angle := TAU * float(i) / 4.0 - PI/2.0  # N no topo
		var from := center + Vector2(sin(angle), -cos(angle)) * (r - 2)
		var tlen := tick_len_north if i == 0 else tick_len_short
		var to := center + Vector2(sin(angle), -cos(angle)) * (r - 2 - tlen)
		draw_line(from, to, tick_color)

	# ——— Ângulo da agulha ———
	var needle_rad: float = 0.0
	if _player and is_instance_valid(_player):
		var dir_to_target: Vector3
		if use_target and target_position.distance_squared_to(_player.global_position) > 0.01:
			var delta := target_position - _player.global_position
			delta.y = 0.0
			dir_to_target = delta.normalized()
		else:
			dir_to_target = Vector3(0, 0, -1)
		var angle_to_target := atan2(dir_to_target.x, dir_to_target.z)
		var forward := -_player.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var player_angle := atan2(forward.x, forward.z)
		needle_rad = angle_to_target - player_angle

	# ——— Agulha em forma de seta (polígono) ———
	var needle_len := r * 0.78
	var tip := center + Vector2(sin(needle_rad), -cos(needle_rad)) * needle_len
	var back_width := 6.0
	var back_dist := needle_len * 0.35
	var back_center := center + Vector2(sin(needle_rad), -cos(needle_rad)) * -back_dist
	var perp := Vector2(cos(needle_rad), sin(needle_rad)) * back_width
	var p1 := back_center + perp
	var p2 := back_center - perp
	# Contorno da agulha (um pouco maior)
	var outline_scale := 1.12
	var tip_out := center + (tip - center) * outline_scale
	var p1_out := center + (p1 - center) * outline_scale
	var p2_out := center + (p2 - center) * outline_scale
	draw_polygon(PackedVector2Array([tip_out, p1_out, p2_out]), PackedColorArray([needle_outline_color, needle_outline_color, needle_outline_color]))
	# Agulha preenchida
	draw_polygon(PackedVector2Array([tip, p1, p2]), PackedColorArray([needle_color, needle_color, needle_color]))
	# Linha central sutil (opcional)
	draw_line(center, tip, Color(needle_color.r * 0.6, needle_color.g * 0.6, needle_color.b * 0.6, 0.6))

	# ——— Pivô central (bolinha) ———
	draw_circle(center, 4, needle_outline_color)
	draw_circle(center, 3, needle_color)
