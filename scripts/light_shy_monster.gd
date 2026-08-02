class_name LightShyMonster
extends CharacterBody3D

signal killed_player(reason: String)
signal illumination_changed(is_illuminated: bool)
signal observed

@export var move_speed := 2.2
@export var target_local_player_only := true
@export var accept_remote_flashlights := true
@export var flashlight_path := NodePath("Head/Flashlight")
@export var stopping_light_group := "unlit_stopping_lights"
@export var illumination_hold_seconds := 0.12
@export var beam_edge_margin_degrees := 2.0
@export var death_reason := "Something from the unlit hall reached you"
@export var journal_entry_id := "unlit"
@export_range(0, 3, 1) var journal_fact_index_on_observation := 2
@export_multiline var observation_message := "The silhouette stops inside the beam. Keep the light on it."

@onready var kill_zone: Area3D = $KillZone
@onready var face_glow: MeshInstance3D = $Body/FaceGlow
@onready var tell_light: OmniLight3D = $Body/TellLight

var active := true
var illuminated := false
var illumination_hold_remaining := 0.0
var observation_reported := false
var kill_reported := false
var face_material: StandardMaterial3D
var authoritative_state_enabled := false


func _ready() -> void:
	add_to_group("monsters")
	kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	var source_material := face_glow.get_surface_override_material(0) as StandardMaterial3D
	if source_material:
		face_material = source_material.duplicate() as StandardMaterial3D
		for marker in $Body.find_children("FaceGlow*", "MeshInstance3D", false, false):
			(marker as MeshInstance3D).set_surface_override_material(0, face_material)
	_apply_illumination_visual()


func _physics_process(delta: float) -> void:
	if authoritative_state_enabled:
		velocity = Vector3.ZERO
		return
	if not active:
		velocity = Vector3.ZERO
		return

	var directly_lit := _is_inside_any_flashlight()
	if directly_lit:
		illumination_hold_remaining = illumination_hold_seconds
	else:
		illumination_hold_remaining = maxf(illumination_hold_remaining - delta, 0.0)
	_set_illuminated(directly_lit or illumination_hold_remaining > 0.0)
	if illuminated:
		velocity = Vector3.ZERO
		return

	var target := _find_target()
	if not target:
		velocity = Vector3.ZERO
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.01:
		velocity = Vector3.ZERO
		return
	look_at(global_position + offset, Vector3.UP)
	velocity = offset.normalized() * move_speed
	move_and_slide()


func stop_chase() -> void:
	active = false
	velocity = Vector3.ZERO
	set_physics_process(false)


func is_illuminated() -> bool:
	return illuminated


func apply_authoritative_state(state: Dictionary) -> void:
	authoritative_state_enabled = true
	var synced_position: Variant = state.get("position", global_position)
	if synced_position is Vector3:
		var authoritative_position: Vector3 = synced_position
		if authoritative_position.is_finite():
			global_position = authoritative_position
	velocity = Vector3.ZERO
	_set_illuminated(bool(state.get("illuminated", false)), false)


func clear_authoritative_state() -> void:
	authoritative_state_enabled = false
	_set_illuminated(false, false)


func is_authoritative_state_enabled() -> bool:
	return authoritative_state_enabled


func _find_target() -> Node3D:
	var nearest: Node3D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("players"):
		if not candidate is Node3D:
			continue
		if target_local_player_only and candidate.has_method("has_control") and not candidate.has_control():
			continue
		var distance := global_position.distance_squared_to((candidate as Node3D).global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _is_inside_any_flashlight() -> bool:
	for candidate in get_tree().get_nodes_in_group("players"):
		if not candidate is Node3D:
			continue
		if (
			not accept_remote_flashlights
			and candidate.has_method("has_control")
			and not candidate.has_control()
		):
			continue
		var flashlight := candidate.get_node_or_null(flashlight_path) as SpotLight3D
		if _is_inside_spotlight(flashlight, candidate as Node3D):
			return true
	for light in get_tree().get_nodes_in_group(stopping_light_group):
		if light is SpotLight3D and _is_inside_spotlight(light as SpotLight3D):
			return true
	return false


func _is_inside_spotlight(spotlight: SpotLight3D, source_body: Node3D = null) -> bool:
	if not spotlight or not spotlight.is_visible_in_tree() or spotlight.light_energy <= 0.0:
		return false
	var target_point := global_position + Vector3.UP * 0.55
	var offset := target_point - spotlight.global_position
	var distance := offset.length()
	if distance <= 0.01 or distance > spotlight.spot_range:
		return false
	var forward := -spotlight.global_basis.z.normalized()
	var safe_angle := maxf(spotlight.spot_angle - beam_edge_margin_degrees, 1.0)
	if forward.dot(offset / distance) < cos(deg_to_rad(safe_angle)):
		return false
	return _has_clear_light_path(source_body, spotlight.global_position, target_point)


func _has_clear_light_path(source_body: Node3D, origin: Vector3, target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_areas = false
	if source_body is CollisionObject3D:
		query.exclude = [(source_body as CollisionObject3D).get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == self


func _set_illuminated(value: bool, report_observation := true) -> void:
	if illuminated == value:
		return
	illuminated = value
	_apply_illumination_visual()
	illumination_changed.emit(illuminated)
	if illuminated and report_observation and not observation_reported:
		observation_reported = true
		observed.emit()


func _apply_illumination_visual() -> void:
	var color := Color(0.42, 0.92, 1.0, 1.0) if illuminated else Color(0.75, 0.08, 0.06, 1.0)
	if face_material:
		face_material.albedo_color = color * 0.45
		face_material.emission = color
	tell_light.light_color = color
	tell_light.light_energy = 0.65 if illuminated else 0.12


func _on_kill_zone_body_entered(body: Node3D) -> void:
	if authoritative_state_enabled or not active or kill_reported:
		return
	if not body.has_method("has_control") or not body.has_control():
		return
	kill_reported = true
	killed_player.emit(death_reason)
