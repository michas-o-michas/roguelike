extends Control

var overlay: ColorRect
var toast: Label
var _day_night: Node = null

const NIGHT_ALPHA = 0.22
const FADE_IN_TIME = 4.0
const FADE_OUT_TIME = 5.0
const TOAST_FADE_IN = 0.5
const TOAST_PAUSE = 4.0
const TOAST_FADE_OUT = 1.5

func _ready() -> void:
	_setup_nodes()
	await get_tree().process_frame
	_day_night = get_tree().get_first_node_in_group("day_night_cycle")
	if _day_night:
		_day_night.night_started.connect(_on_night_started)
		_day_night.day_started.connect(_on_day_started)
		if _day_night.is_night:
			overlay.color.a = NIGHT_ALPHA

func _setup_nodes() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.02, 0.08, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	toast = Label.new()
	toast.anchor_left = 0.0
	toast.anchor_right = 1.0
	toast.anchor_top = 0.0
	toast.anchor_bottom = 0.0
	toast.offset_left = 0.0
	toast.offset_right = 0.0
	toast.offset_top = 80.0
	toast.offset_bottom = 120.0
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate = Color(1.0, 1.0, 1.0, 0.0)
	toast.add_theme_font_size_override("font_size", 22)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)

func _on_night_started() -> void:
	_show_overlay(true)
	_show_toast("🌙  A noite chegou — os inimigos ficam mais perigosos!")

func _on_day_started() -> void:
	_show_overlay(false)
	_show_toast("☀️  Amanheceu. Você sobreviveu mais uma noite.")

func _show_overlay(night: bool) -> void:
	var tween = create_tween()
	var target_alpha = NIGHT_ALPHA if night else 0.0
	var duration = FADE_IN_TIME if night else FADE_OUT_TIME
	tween.tween_property(overlay, "color:a", target_alpha, duration)

func _show_toast(text: String) -> void:
	toast.text = text
	var tween = create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, TOAST_FADE_IN)
	tween.tween_interval(TOAST_PAUSE)
	tween.tween_property(toast, "modulate:a", 0.0, TOAST_FADE_OUT)
