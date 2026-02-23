# pickup.gd
# Usado pela cena pickup.tscn (drop de inimigos, etc.).
# Chame setup(item, amount) após instanciar: item = null = moedas, amount = qtd.

extends Area3D

var _item: Item = null
var _amount: int = 0

## Animação "pulo pra fora"
const POP_HEIGHT := 4.0
const POP_HORIZONTAL := 0.35
const POP_UP_DURATION := 1.0
const LAND_DURATION := 1.0
## Escala: começa menor, cresce no pop, estabiliza
const SCALE_START := 0.65
const SCALE_PEAK := 1.08
const SCALE_REST := 1.0
## Rotação no pop: giro (radianos) e inclinação
const SPIN_POP := 2.2 * TAU
const SPIN_LAND := 0.6 * TAU
const TILT_PEAK := 0.18
## Flutuação idle
const FLOAT_AMPLITUDE := 1.0
const FLOAT_CYCLE := 0.9
const FLOAT_SCALE_MIN := 0.97
const FLOAT_SCALE_MAX := 1.03
const IDLE_SPIN_SPEED := 0.4 * TAU  # radianos por ciclo de float

func setup(item: Item, amount: int) -> void:
	_item = item
	_amount = amount

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	call_deferred("_play_pop_animation")

func _play_pop_animation() -> void:
	var rest := global_position
	var peak := rest + Vector3(
		randf_range(-POP_HORIZONTAL, POP_HORIZONTAL),
		POP_HEIGHT,
		randf_range(-POP_HORIZONTAL, POP_HORIZONTAL)
	)
	scale = Vector3(SCALE_START, SCALE_START, SCALE_START)
	rotation = Vector3.ZERO

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	# Subida: posição, escala, giro e inclinação em paralelo
	tween.tween_property(self, "global_position", peak, POP_UP_DURATION)
	tween.parallel().tween_property(self, "scale", Vector3(SCALE_PEAK, SCALE_PEAK, SCALE_PEAK), POP_UP_DURATION)
	tween.parallel().tween_property(self, "rotation:y", SPIN_POP, POP_UP_DURATION)
	tween.parallel().tween_property(self, "rotation:x", TILT_PEAK, POP_UP_DURATION)

	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	# Queda: volta ao chão, escala estável, mais um giro, desinclina
	tween.tween_property(self, "global_position", rest, LAND_DURATION)
	tween.parallel().tween_property(self, "scale", Vector3(SCALE_REST, SCALE_REST, SCALE_REST), LAND_DURATION)
	tween.parallel().tween_property(self, "rotation:y", SPIN_POP + SPIN_LAND, LAND_DURATION)
	tween.parallel().tween_property(self, "rotation:x", 0.0, LAND_DURATION)

	tween.finished.connect(_play_idle_animation)

func _play_idle_animation() -> void:
	var mid_y := global_position.y
	var half := FLOAT_CYCLE / 2.0
	var start_rot_y := rotation.y
	var tween := create_tween()
	# Um ciclo: sobe/desce + escala + giro; ao terminar, chama de novo (loop contínuo)
	tween.tween_property(self, "global_position:y", mid_y + FLOAT_AMPLITUDE, half)
	tween.parallel().tween_property(self, "scale", Vector3(FLOAT_SCALE_MAX, FLOAT_SCALE_MAX, FLOAT_SCALE_MAX), half)
	tween.parallel().tween_property(self, "rotation:y", start_rot_y + IDLE_SPIN_SPEED, half)
	tween.tween_property(self, "global_position:y", mid_y, half)
	tween.parallel().tween_property(self, "scale", Vector3(FLOAT_SCALE_MIN, FLOAT_SCALE_MIN, FLOAT_SCALE_MIN), half)
	tween.parallel().tween_property(self, "rotation:y", start_rot_y + IDLE_SPIN_SPEED * 2.0, half)
	tween.finished.connect(_play_idle_animation)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _item == null:
		InventoryManager.add_coins(_amount)
	else:
		InventoryManager.add_item(_item, _amount)
	queue_free()
