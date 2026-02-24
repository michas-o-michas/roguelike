extends Node3D

signal night_started
signal day_started
signal new_day_started(day: int)

@export var startTime = 6
@export var dayLengthInSeconds:float = 24

@export var morningColorTop: Color = Color("5897fa")
@export var morningColorHorizon: Color = Color("d3916b")

@export var dayColorTop: Color = Color("1f6ddf")
@export var dayColorHorizon: Color = Color("56a9f5")

@export var afternoonColorTop: Color = Color("3d6fcd")
@export var afternoonColorHorizon: Color = Color("e98174")

@export var nightColorTop: Color = Color("090e14")
@export var nightColorHorizon: Color = Color("010049")

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sun: DirectionalLight3D = $Sun

var dayDuration = 24
var dayColorList = [
	{"top": morningColorTop, "horizon": morningColorHorizon, "startTime": 6},
	{"top": dayColorTop, "horizon": dayColorHorizon, "startTime": 8},
	{"top": afternoonColorTop, "horizon": afternoonColorHorizon, "startTime": 18},
	{"top": nightColorTop, "horizon": nightColorHorizon, "startTime": 20}
]
var currentDayState = 0
var durationMultiplier = 1.0
var is_night: bool = false
var current_hour: float = 0.0
var current_day: int = 1
var _initialized: bool = false

func _ready() -> void:
	add_to_group("day_night_cycle")
	world_environment.add_to_group("world_environment_apply")
	if SettingsManager:
		SettingsManager.apply_environment_to_scene()
	_change_duration()
	_set_sun()
	_set_current_state()
	_refresh_day_state()
	_day_change_animation()
	is_night = (currentDayState == 3)
	_initialized = true

func _change_duration():
	durationMultiplier = dayLengthInSeconds/24
	animation_player.speed_scale = 1.0 / durationMultiplier

func _set_sun():
	animation_player.play("day_and_night")
	animation_player.seek(startTime)

func _set_current_state():
	for i in dayColorList.size():
		if startTime < dayColorList[i].startTime:
			currentDayState = i -1
			return

func _refresh_day_state():
	var newState = false
	var prev_state = currentDayState

	for i in dayColorList.size():
		var sameState = i == currentDayState
		if not sameState and animation_player.current_animation_position > dayColorList[i].startTime:
			currentDayState = i
			newState = true

	if newState:
		_day_change_animation()
		_update_night_state(prev_state)

func _update_night_state(prev_state: int) -> void:
	if not _initialized:
		return
	var was_night := prev_state == 3
	var now_night = currentDayState == 3
	if not was_night and now_night:
		is_night = true
		night_started.emit()
	elif was_night and not now_night:
		is_night = false
		current_day += 1
		day_started.emit()
		new_day_started.emit(current_day)

func _day_change_animation():
	var topColor = dayColorList[currentDayState]["top"]
	var hoirzonColor = dayColorList[currentDayState]["horizon"]
	var tween = create_tween()
	
	var duration = durationMultiplier
	
	tween.tween_property(world_environment, "environment:sky:sky_material:sky_top_color", topColor, duration)
	tween.parallel()
	tween.tween_property(world_environment, "environment:sky:sky_material:sky_horizon_color", hoirzonColor, duration)
	tween.parallel()
	tween.tween_property(world_environment, "environment:sky:sky_material:ground_bottom_color", topColor, duration)
	tween.parallel()
	tween.tween_property(world_environment, "environment:sky:sky_material:ground_horizon_color", hoirzonColor, duration)

func _process(_delta: float) -> void:
	_refresh_day_state()
	current_hour = animation_player.current_animation_position
	if currentDayState in [0, 1] and sun.shadow_enabled == false:
		var tween = create_tween()
		tween.tween_property(sun, "light_energy", 0.8, durationMultiplier * 2)
		sun.shadow_enabled = true
	elif currentDayState == 3 and sun.shadow_enabled:
		sun.shadow_enabled = false
		var tween = create_tween()
		tween.tween_property(sun, "light_energy", 0.02, durationMultiplier)
