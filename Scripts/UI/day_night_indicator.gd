# day_night_indicator.gd
# Indicador circular de dia/noite: mostra a posição atual no ciclo de 24h
# como um relógio — arco dourado (dia) no topo, arco azul (noite) na base.

extends Control

## Raio do círculo em pixels
@export var indicator_radius: int = 38

@export var border_color: Color = Color(0.55, 0.42, 0.28, 1.0)
@export var fill_color: Color = Color(0.14, 0.11, 0.08, 0.95)
@export var inner_ring_color: Color = Color(0.22, 0.17, 0.12, 1.0)
@export var tick_color: Color = Color(0.5, 0.42, 0.32, 0.9)
@export var day_color: Color = Color(0.95, 0.75, 0.25, 0.85)
@export var night_color: Color = Color(0.30, 0.42, 0.90, 0.85)

var _dnc: Node = null

func _ready() -> void:
	call_deferred("_find_dnc")

func _find_dnc() -> void:
	_dnc = get_tree().get_first_node_in_group("day_night_cycle")

func _process(_delta: float) -> void:
	if not is_instance_valid(_dnc):
		_find_dnc()
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var r := minf(float(indicator_radius), minf(size.x, size.y) * 0.45)
	var r_track := r * 0.72

	# ——— Mostrador (estilo igual à bússola) ———
	draw_arc(center + Vector2(2, 2), r + 2, 0, TAU, 48, Color(0, 0, 0, 0.35), 4.0)
	draw_arc(center, r + 1, 0, TAU, 48, border_color, 2.5)
	draw_circle(center, r - 0.5, fill_color)
	draw_arc(center, r - 4, 0, TAU, 48, inner_ring_color, 2.0)

	# Estado atual do ciclo
	var current_hour := 12.0
	var is_night := false
	if _dnc and is_instance_valid(_dnc):
		current_hour = float(_dnc.current_hour)
		is_night = bool(_dnc.is_night)

	# ——— Arcos do ciclo ———
	# Em Godot 2D: -PI/2 = cima, 0 = direita, PI/2 = baixo, ±PI = esquerda
	# De -PI→0 (passando por -PI/2 = cima): período do DIA (6h→18h pelo meio-dia)
	# De  0→PI (passando por PI/2 = baixo): período da NOITE (18h→6h pela meia-noite)
	var day_col := day_color if not is_night else Color(day_color.r, day_color.g, day_color.b, 0.22)
	var night_col := night_color if is_night else Color(night_color.r, night_color.g, night_color.b, 0.22)
	draw_arc(center, r_track, -PI, 0.0, 32, day_col, 5.0)
	draw_arc(center, r_track, 0.0, PI, 32, night_col, 5.0)

	# ——— Marcadores de hora (6h, 12h, 18h, 0h) ———
	for i in 4:
		var mark_hour := float(i) * 6.0
		var mark_angle := (mark_hour - 12.0) / 24.0 * TAU - PI / 2.0
		var from_p := center + Vector2(cos(mark_angle), sin(mark_angle)) * (r - 2.0)
		var to_p   := center + Vector2(cos(mark_angle), sin(mark_angle)) * (r - 8.0)
		draw_line(from_p, to_p, tick_color, 1.5)

	# ——— Sol / Lua na posição atual ———
	# Ângulo: H=12→cima, H=18→direita, H=0→baixo, H=6→esquerda
	var time_angle := (current_hour - 12.0) / 24.0 * TAU - PI / 2.0
	var dot_pos := center + Vector2(cos(time_angle), sin(time_angle)) * r_track

	if is_night:
		# Lua: círculo prateado com corte para efeito de crescente
		draw_circle(dot_pos, 6.5, Color(0.78, 0.85, 0.98, 1.0))
		draw_circle(dot_pos + Vector2(3.5, -2.5), 4.5, fill_color)
	else:
		# Sol: halo + círculo dourado
		draw_circle(dot_pos, 7.5, Color(1.0, 0.82, 0.22, 0.40))
		draw_circle(dot_pos, 5.5, Color(1.0, 0.93, 0.38, 1.0))

	# ——— Pivô central ———
	draw_circle(center, 3.5, inner_ring_color)
	draw_circle(center, 2.5, Color(0.38, 0.30, 0.22, 1.0))
