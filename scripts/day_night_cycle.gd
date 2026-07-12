class_name DayNightCycle
extends Node

@export var enabled := true
@export_range(10.0, 3600.0, 1.0, "or_greater") var cycle_length_seconds := 480.0
@export_range(0.0, 1.0, 0.001) var time_of_day := 0.18
@export var day_ambient_multiplier := 1.08
@export var night_ambient_multiplier := 0.38
@export var day_light_multiplier := 1.0
@export var night_light_multiplier := 0.42
@export var dawn_tint := Color(1.0, 0.62, 0.38, 1.0)
@export var day_tint := Color(0.9, 0.96, 1.0, 1.0)
@export var night_tint := Color(0.32, 0.42, 0.75, 1.0)

var target_level: Node3D
var world_environment: WorldEnvironment
var environment: Environment
var base_background_color := Color.BLACK
var base_ambient_color := Color.BLACK
var base_ambient_energy := 0.0
var light_defaults := {}


func _ready() -> void:
	set_process(enabled)


func _process(delta: float) -> void:
	if not enabled:
		return

	time_of_day = fposmod(time_of_day + delta / cycle_length_seconds, 1.0)
	_apply_cycle()


func set_target_level(level: Node3D) -> void:
	target_level = level
	_cache_level_lighting()
	_apply_cycle()


func set_cycle_length(seconds: float) -> void:
	cycle_length_seconds = max(seconds, 10.0)


func get_cycle_length() -> float:
	return cycle_length_seconds


func set_enabled(is_enabled: bool) -> void:
	enabled = is_enabled
	set_process(enabled)
	if enabled:
		_apply_cycle()


func _cache_level_lighting() -> void:
	light_defaults.clear()
	world_environment = null
	environment = null
	if not target_level:
		return

	world_environment = target_level.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_environment and world_environment.environment:
		environment = world_environment.environment.duplicate() as Environment
		world_environment.environment = environment
		base_background_color = environment.background_color
		base_ambient_color = environment.ambient_light_color
		base_ambient_energy = environment.ambient_light_energy

	for child in target_level.find_children("*", "Light3D", true, false):
		var light := child as Light3D
		light_defaults[light] = {
			"energy": light.light_energy,
			"color": light.light_color,
		}


func _apply_cycle() -> void:
	var night_factor: float = _get_night_factor()
	var dawn_factor: float = _get_dawn_factor()
	var ambient_multiplier: float = lerp(day_ambient_multiplier, night_ambient_multiplier, night_factor)
	var light_multiplier: float = lerp(day_light_multiplier, night_light_multiplier, night_factor)
	var tint: Color = day_tint.lerp(night_tint, night_factor).lerp(dawn_tint, dawn_factor * 0.45)

	if environment:
		environment.ambient_light_energy = base_ambient_energy * ambient_multiplier
		environment.ambient_light_color = base_ambient_color.lerp(tint, 0.22)
		environment.background_color = base_background_color.lerp(tint, 0.08 + night_factor * 0.1)

	for light_key in light_defaults.keys():
		var light := light_key as Light3D
		if not is_instance_valid(light):
			continue
		var defaults: Dictionary = light_defaults[light]
		light.light_energy = float(defaults["energy"]) * light_multiplier
		light.light_color = (defaults["color"] as Color).lerp(tint, 0.16 + night_factor * 0.12)


func _get_night_factor() -> float:
	var wave: float = cos(time_of_day * TAU)
	return smoothstep(-0.15, 0.82, wave)


func _get_dawn_factor() -> float:
	var dawn: float = 1.0 - min(abs(time_of_day - 0.23), abs(time_of_day - 0.77)) / 0.12
	return clamp(dawn, 0.0, 1.0)
