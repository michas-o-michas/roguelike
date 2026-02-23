# WorldGeneratorTerrainHeight.gd
# Módulo de altura e cor do terreno — filho de InfiniteWorldGenerator.
# Centraliza cache e cálculo de get_terrain_height / get_terrain_color.

extends Node

const TERRAIN_BEACH_ZONE_TOP := 15.0
const TERRAIN_DEEP_THRESHOLD := -5.0
const TERRAIN_BEACH_SMOOTH_DIST := 12.0
const TERRAIN_RAMP_FACTOR_ABOVE := 0.2
const TERRAIN_SMOOTH_STRENGTH_MAX := 0.7
const TERRAIN_FINAL_TRANSITION_ZONE := 10.0
const TERRAIN_FINAL_RAMP := 0.25
const TERRAIN_BOTTOM_SMOOTH_ZONE := 3.0
const HEIGHT_CACHE_MAX_SIZE := 500000

var _height_cache: Dictionary = {}
var _rock_start_cached: float = 99999.0
var _rock_end_cached: float = 99999.0
var _snow_start_cached: float = 99999.0

func _ready() -> void:
	_cache_layer_values()

func _cache_layer_values() -> void:
	var g = _generator()
	if not g:
		return
	_rock_start_cached = g.rock_start_height if g.enable_rock_layer else 99999.0
	_rock_end_cached = _rock_start_cached + g.rock_thickness if g.enable_rock_layer else 99999.0
	if g.enable_snow_layer:
		_snow_start_cached = (g.rock_start_height + g.rock_thickness) if g.snow_start_height < 0 else g.snow_start_height
	else:
		_snow_start_cached = 99999.0

func _generator() -> InfiniteWorldGenerator:
	return get_parent() as InfiniteWorldGenerator

## Limpa cache se exceder tamanho (chamado após unload de chunks).
func clear_height_cache_if_needed() -> void:
	if _height_cache.size() > HEIGHT_CACHE_MAX_SIZE:
		_height_cache.clear()

func get_terrain_height(x: float, z: float) -> float:
	var g := _generator()
	if not g:
		return 0.0
	clear_height_cache_if_needed()
	var cache_key := Vector2i(int(x * 10.0), int(z * 10.0))
	if _height_cache.has(cache_key):
		return _height_cache[cache_key]
	var h := _compute_terrain_height(x, z)
	_height_cache[cache_key] = h
	return h

func _compute_terrain_height(x: float, z: float) -> float:
	var g := _generator()
	if not g or not g.noise:
		return 0.0
	var noise_value := g.noise.get_noise_2d(x, z)
	var amplitude := g.noise_amplitude
	var frequency := 1.0
	var height := noise_value * amplitude

	for i in range(1, g.octaves):
		frequency *= g.lacunarity
		amplitude *= g.persistence
		height += g.noise.get_noise_2d(x * frequency, z * frequency) * amplitude

	if height > 0:
		var normalized := height / g.noise_amplitude
		normalized = pow(normalized, g.height_redistribution)
		height = normalized * g.noise_amplitude
	else:
		var normalized = abs(height) / g.noise_amplitude
		normalized = pow(normalized, 1.5)
		height = -normalized * g.noise_amplitude

	height += 3.0

	if g.enable_water:
		var distance_from_water := height - g.water_level
		var deep_water_zone := -g.water_depth_limit

		if distance_from_water >= deep_water_zone and distance_from_water <= TERRAIN_BEACH_ZONE_TOP:
			var smooth_distance = abs(distance_from_water)
			if distance_from_water < TERRAIN_DEEP_THRESHOLD:
				var depth_factor := clampf((abs(distance_from_water) - (-TERRAIN_DEEP_THRESHOLD)) / (g.water_depth_limit - (-TERRAIN_DEEP_THRESHOLD)), 0.0, 1.0)
				depth_factor = depth_factor * depth_factor
				var deep_noise := g.noise.get_noise_2d(x * 0.0004, z * 0.0004)
				var target_depth := g.water_level - 4.0 + (deep_noise * 2.0)
				height = lerpf(height, target_depth, depth_factor * 0.8)
			elif distance_from_water >= TERRAIN_DEEP_THRESHOLD and distance_from_water <= TERRAIN_BEACH_ZONE_TOP:
				var smooth_strength := 1.0 - clampf(smooth_distance / TERRAIN_BEACH_SMOOTH_DIST, 0.0, 1.0)
				smooth_strength = smooth_strength * smooth_strength
				var beach_noise := g.noise.get_noise_2d(x * 0.0006, z * 0.0006)
				var target_height: float
				if distance_from_water > 0:
					target_height = g.water_level + (distance_from_water * TERRAIN_RAMP_FACTOR_ABOVE) + (beach_noise * 1.2)
				else:
					var depth_t = abs(distance_from_water) / (-TERRAIN_DEEP_THRESHOLD)
					depth_t = depth_t * depth_t
					target_height = lerpf(g.water_level - 1.0, g.water_level - 3.0, depth_t) + (beach_noise * 1.2)
				height = lerpf(height, target_height, smooth_strength * TERRAIN_SMOOTH_STRENGTH_MAX)

		var min_height := g.water_level - g.water_depth_limit
		if height < min_height:
			height = min_height

		distance_from_water = height - g.water_level
		if distance_from_water >= -TERRAIN_BOTTOM_SMOOTH_ZONE and distance_from_water <= TERRAIN_FINAL_TRANSITION_ZONE:
			var smooth_noise_val := g.noise.get_noise_2d(x * 0.0005, z * 0.0005)
			var water_proximity := 1.0 - clampf(abs(distance_from_water) / TERRAIN_FINAL_TRANSITION_ZONE, 0.0, 1.0)
			water_proximity = water_proximity * water_proximity
			var smooth_height: float
			if distance_from_water > 0:
				smooth_height = g.water_level + (distance_from_water * TERRAIN_FINAL_RAMP) + (smooth_noise_val * 0.8)
			else:
				smooth_height = g.water_level - 1.5 + (smooth_noise_val * 0.8)
			height = lerpf(height, smooth_height, water_proximity * 0.6)

		if height < g.water_level - TERRAIN_BOTTOM_SMOOTH_ZONE:
			var depth_noise := g.noise.get_noise_2d(x * 0.0008, z * 0.0008)
			var depth_factor := clampf((g.water_level - TERRAIN_BOTTOM_SMOOTH_ZONE - height) / 5.0, 0.0, 1.0)
			var smooth_bottom := g.water_level - TERRAIN_BOTTOM_SMOOTH_ZONE + (depth_noise * 1.5)
			height = lerpf(height, smooth_bottom, depth_factor * 0.6)

	return height

func get_terrain_color(x: float, z: float, height: float) -> Color:
	var g := _generator()
	if not g:
		return Color.GRAY
	var moisture := (g.moisture_noise.get_noise_2d(x, z) + 1.0) * 0.5
	var w_level := g.water_level
	var expanded_beach_level := g.beach_level + 3.0
	var g_level := g.grass_level
	var m_level := g.rock_start_height
	var rock_start := _rock_start_cached
	var rock_end := _rock_end_cached
	var s_start := _snow_start_cached

	if g.show_layer_debug:
		if height < w_level: return Color.BLUE
		if height < expanded_beach_level: return Color.YELLOW
		if height < g_level: return Color.GREEN
		if height < rock_start: return Color.DARK_GREEN
		if height < rock_end: return Color.GRAY
		return Color.WHITE

	if height < w_level:
		var depth := (w_level - height) / g.water_depth_limit
		depth = clampf(depth, 0.0, 1.0)
		return Color(0.15, 0.3, 0.5).lerp(Color(0.05, 0.1, 0.2), depth * depth)

	if height < expanded_beach_level:
		var t := (height - w_level) / (expanded_beach_level - w_level)
		t = clampf(t, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		var shallow_water := Color(0.15, 0.3, 0.5)
		var wet_sand := Color(0.6, 0.55, 0.45)
		var dry_sand := Color(0.85, 0.8, 0.65)
		if t < 0.3:
			var st := t / 0.3
			st = st * st
			return shallow_water.lerp(wet_sand, st)
		var st := (t - 0.3) / 0.7
		st = st * st * (3.0 - 2.0 * st)
		return wet_sand.lerp(dry_sand, st)

	if height < g_level + 5.0:
		var t := (height - expanded_beach_level) / ((g_level + 5.0) - expanded_beach_level)
		t = clampf(t, 0.0, 1.0)
		t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
		var sand := Color(0.85, 0.8, 0.65)
		var grass := Color(0.4, 0.65, 0.35).lerp(Color(0.35, 0.6, 0.3), moisture)
		return sand.lerp(grass, t)

	if height < m_level * 0.4:
		return Color(0.35, 0.6, 0.3).lerp(Color(0.28, 0.5, 0.25), moisture * 0.5)

	if height < m_level * 0.7:
		var t := (height - m_level * 0.4) / (m_level * 0.3)
		t = clampf(t, 0.0, 1.0)
		return Color(0.28, 0.5, 0.25).lerp(Color(0.3, 0.48, 0.25), t)

	if height < rock_start:
		var distance_to_rock := rock_start - (m_level * 0.7)
		if distance_to_rock > 0:
			var t := (height - m_level * 0.7) / distance_to_rock
			t = clampf(t, 0.0, 1.0)
			t = t * t
			return Color(0.3, 0.48, 0.25).lerp(Color(0.35, 0.4, 0.3), t)
		return Color(0.3, 0.48, 0.25)

	if height < rock_end:
		return Color(0.5, 0.5, 0.5)

	if height < s_start + g.snow_transition:
		var t := (height - rock_end) / g.snow_transition
		t = clampf(t, 0.0, 1.0)
		t = t * t
		return Color(0.5, 0.5, 0.5).lerp(Color(0.92, 0.92, 0.95), t)

	return Color(0.92, 0.92, 0.95)
