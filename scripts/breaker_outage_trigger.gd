class_name BreakerOutageTrigger
extends Area3D

signal outage_triggered(duration_seconds: float)
signal evidence_observed
signal outage_requested

@export var powered_light_path: NodePath
@export var outage_duration := 3.2
@export var one_shot := true
@export var requires_local_control := true
@export var ready_color := Color(0.95, 0.58, 0.12, 1.0)
@export var spent_color := Color(0.32, 0.08, 0.05, 1.0)
@export var journal_entry_id := "unlit"
@export_range(0, 3, 1) var journal_fact_index_on_observation := 3
@export_multiline var observation_message := "The work light died. Keep your own beam on the silhouette."

@onready var indicator: MeshInstance3D = $Panel/Indicator

var triggered := false
var authoritative_mode := false
var powered_light: Node
var indicator_material: StandardMaterial3D


func _ready() -> void:
	set_powered_light(get_node_or_null(powered_light_path))
	body_entered.connect(_on_body_entered)
	var source_material := indicator.get_active_material(0) as StandardMaterial3D
	if source_material:
		indicator_material = source_material.duplicate() as StandardMaterial3D
		indicator.set_surface_override_material(0, indicator_material)
	_apply_visual_state()


func trigger_outage() -> bool:
	if triggered and one_shot:
		return false
	if not is_instance_valid(powered_light):
		powered_light = get_node_or_null(powered_light_path)
	if not powered_light or not powered_light.has_method("trigger_outage"):
		return false

	triggered = true
	powered_light.call("trigger_outage", outage_duration)
	_apply_visual_state()
	outage_triggered.emit(outage_duration)
	evidence_observed.emit()
	return true


func reset_trigger() -> void:
	triggered = false
	_apply_visual_state()


func is_triggered() -> bool:
	return triggered


func set_authoritative_mode(enabled: bool) -> void:
	authoritative_mode = enabled


func get_trigger_state() -> Dictionary:
	return {"triggered": triggered}


func apply_trigger_state(state: Dictionary) -> void:
	triggered = bool(state.get("triggered", false))
	_apply_visual_state()


func get_sync_state() -> Dictionary:
	return get_trigger_state()


func apply_sync_state(state: Dictionary) -> void:
	apply_trigger_state(state)


func set_powered_light(light: Node) -> void:
	powered_light = light
	if is_inside_tree() and is_instance_valid(powered_light):
		powered_light_path = get_path_to(powered_light)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	if requires_local_control and body.has_method("has_control") and not body.has_control():
		return
	if authoritative_mode:
		if not triggered or not one_shot:
			outage_requested.emit()
		return
	trigger_outage()


func _apply_visual_state() -> void:
	if not indicator_material:
		return
	var color := spent_color if triggered else ready_color
	indicator_material.albedo_color = color.darkened(0.45)
	indicator_material.emission = color
