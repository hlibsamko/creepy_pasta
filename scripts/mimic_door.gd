class_name MimicDoor
extends Area3D

signal killed_player(reason: String)
signal observed

@export var active := true
@export var observation_distance := 3.2
@export var death_reason := "The false doorway closed around you"
@export var journal_entry_id := "mimic"
@export_range(0, 3, 1) var journal_fact_index_on_observation := 2
@export var pulse_cycle_seconds := 3.6
@export var learned_reveal_distance := 5.4
@export var disguise_color := Color(1.0, 0.78, 0.28, 1.0)

@onready var tell_light: OmniLight3D = $TellLight
@onready var glow_mesh: MeshInstance3D = $Glow

var observation_reported := false
var pulse_elapsed := 0.0
var base_tell_energy := 0.0
var base_tell_color := Color.WHITE
var glow_material: StandardMaterial3D
var base_glow_albedo := Color.WHITE
var base_glow_emission := Color.WHITE
var knowledge_behavior_tier := 0


func _ready() -> void:
	add_to_group("monsters")
	body_entered.connect(_on_body_entered)
	base_tell_energy = tell_light.light_energy
	base_tell_color = tell_light.light_color
	var source_material := glow_mesh.get_surface_override_material(0) as StandardMaterial3D
	if source_material:
		glow_material = source_material.duplicate() as StandardMaterial3D
		glow_mesh.set_surface_override_material(0, glow_material)
		base_glow_albedo = glow_material.albedo_color
		base_glow_emission = glow_material.emission


func _process(delta: float) -> void:
	if not active:
		return
	pulse_elapsed = fmod(pulse_elapsed + delta, maxf(pulse_cycle_seconds, 0.5))
	_apply_double_pulse()
	if not observation_reported and _has_nearby_controlled_player():
		observation_reported = true
		observed.emit()


func stop_chase() -> void:
	active = false
	monitoring = false
	if tell_light:
		tell_light.light_energy = 0.0


func set_knowledge_difficulty(completion_ratio: float) -> void:
	var difficulty := clampf(completion_ratio, 0.0, 1.0)
	pulse_cycle_seconds = lerpf(3.6, 4.4, difficulty)


func set_knowledge_profile(overall_completion: float, entry_completion: float) -> void:
	set_knowledge_difficulty(overall_completion)
	var learned_ratio := clampf(entry_completion, 0.0, 1.0)
	if learned_ratio >= 2.0 / 3.0:
		knowledge_behavior_tier = 2
	elif learned_ratio >= 1.0 / 3.0:
		knowledge_behavior_tier = 1
	else:
		knowledge_behavior_tier = 0
	_apply_double_pulse()


func get_knowledge_behavior_tier() -> int:
	return knowledge_behavior_tier


func get_knowledge_behavior_message() -> String:
	if knowledge_behavior_tier >= 2:
		return "The False Door now reveals its pulse only to someone who approaches carefully."
	if knowledge_behavior_tier >= 1:
		return "The False Door learned to borrow the warm glow of a real opening."
	return ""


func get_tell_intensity() -> float:
	return tell_light.light_energy if tell_light else 0.0


func get_tell_color() -> Color:
	return tell_light.light_color if tell_light else Color.BLACK


func get_glow_color() -> Color:
	return glow_material.emission if glow_material else Color.BLACK


func _apply_double_pulse() -> void:
	if not tell_light:
		return
	var phase := pulse_elapsed / maxf(pulse_cycle_seconds, 0.5)
	var is_pulse := phase < 0.055 or (phase >= 0.12 and phase < 0.175)
	var reveal_tell := knowledge_behavior_tier < 2 or _has_controlled_player_within(learned_reveal_distance)
	if knowledge_behavior_tier == 0:
		_apply_tell_colors(base_tell_color, base_glow_albedo, base_glow_emission)
		tell_light.light_energy = base_tell_energy if is_pulse else base_tell_energy * 0.18
	elif reveal_tell and is_pulse:
		_apply_tell_colors(base_tell_color, base_glow_albedo, base_glow_emission)
		tell_light.light_energy = base_tell_energy
	else:
		_apply_tell_colors(disguise_color, disguise_color * 0.62, disguise_color)
		tell_light.light_energy = base_tell_energy * 0.32


func _apply_tell_colors(light_color: Color, glow_albedo: Color, glow_emission: Color) -> void:
	tell_light.light_color = light_color
	if glow_material:
		glow_material.albedo_color = glow_albedo
		glow_material.emission = glow_emission


func _has_nearby_controlled_player() -> bool:
	return _has_controlled_player_within(observation_distance)


func _has_controlled_player_within(distance: float) -> bool:
	var max_distance_squared := distance * distance
	for player in get_tree().get_nodes_in_group("players"):
		if not player is Node3D:
			continue
		if player.has_method("has_control") and not player.has_control():
			continue
		if global_position.distance_squared_to((player as Node3D).global_position) <= max_distance_squared:
			return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if not active:
		return
	if not body.has_method("has_control") or not body.has_control():
		return
	active = false
	killed_player.emit(death_reason)
