class_name WatcherMonster
extends Node3D

signal killed_player(reason: String)
signal observed
signal gaze_warning(progress: float, seconds_remaining: float)
signal gaze_cleared
signal advanced(position: Vector3)

@export var active := true
@export var trigger_distance := 10.0
@export_range(0.75, 1.0, 0.01) var gaze_dot_threshold := 0.94
@export var stare_time_to_kill := 3.0
@export var calm_decay_speed := 1.8
@export var attention_hold_seconds := 0.8
@export var learned_step_distance := 0.75
@export var learned_step_minimum_range := 2.5
@export var death_reason := "The watcher noticed you staring"
@export var journal_entry_id := "watcher"
@export_range(0, 3, 1) var journal_fact_index_on_observation := 2

var stare_time := 0.0
var observation_reported := false
var base_stare_time_to_kill := 0.0
var gaze_warning_active := false
var knowledge_behavior_tier := 0
var attention_hold_remaining := 0.0
var last_observer_position := Vector3.ZERO
var can_advance_after_gaze := false


func _ready() -> void:
	add_to_group("monsters")
	base_stare_time_to_kill = stare_time_to_kill


func _process(delta: float) -> void:
	if not active:
		stare_time = 0.0
		_clear_gaze_warning()
		return

	var observer := _find_watching_player()
	var watched := observer != null

	if watched:
		last_observer_position = (observer as Node3D).global_position
		attention_hold_remaining = attention_hold_seconds if knowledge_behavior_tier >= 1 else 0.0
		can_advance_after_gaze = knowledge_behavior_tier >= 2
		gaze_warning_active = true
		if not observation_reported:
			observation_reported = true
			observed.emit()
		stare_time += delta
		gaze_warning.emit(
			clampf(stare_time / maxf(stare_time_to_kill, 0.001), 0.0, 1.0),
			maxf(stare_time_to_kill - stare_time, 0.0)
		)
		if stare_time >= stare_time_to_kill:
			_kill_player()
	else:
		if knowledge_behavior_tier >= 1 and stare_time > 0.0 and attention_hold_remaining > 0.0:
			attention_hold_remaining = maxf(attention_hold_remaining - delta, 0.0)
			gaze_warning.emit(
				clampf(stare_time / maxf(stare_time_to_kill, 0.001), 0.0, 1.0),
				maxf(stare_time_to_kill - stare_time, 0.0)
			)
			return
		_clear_gaze_warning()
		stare_time = max(stare_time - delta * calm_decay_speed, 0.0)
		if knowledge_behavior_tier >= 2 and can_advance_after_gaze:
			can_advance_after_gaze = false
			_advance_toward_last_observer()


func stop_chase() -> void:
	active = false
	stare_time = 0.0
	attention_hold_remaining = 0.0
	can_advance_after_gaze = false
	_clear_gaze_warning()


func set_knowledge_difficulty(completion_ratio: float) -> void:
	var difficulty := clampf(completion_ratio, 0.0, 1.0)
	stare_time_to_kill = maxf(base_stare_time_to_kill * lerpf(1.0, 0.9, difficulty), 3.0)


func set_knowledge_profile(overall_completion: float, entry_completion: float) -> void:
	set_knowledge_difficulty(overall_completion)
	var learned_ratio := clampf(entry_completion, 0.0, 1.0)
	if learned_ratio >= 2.0 / 3.0:
		knowledge_behavior_tier = 2
	elif learned_ratio >= 1.0 / 3.0:
		knowledge_behavior_tier = 1
	else:
		knowledge_behavior_tier = 0
	if knowledge_behavior_tier == 0:
		attention_hold_remaining = 0.0
		can_advance_after_gaze = false


func get_knowledge_behavior_tier() -> int:
	return knowledge_behavior_tier


func get_knowledge_behavior_message() -> String:
	if knowledge_behavior_tier >= 2:
		return "The Watcher learned to follow the place where your gaze broke."
	if knowledge_behavior_tier >= 1:
		return "The Watcher now remembers your attention after you look away."
	return ""


func _find_watching_player() -> Node3D:
	for player in get_tree().get_nodes_in_group("players"):
		if _is_watched_by_player(player):
			return player as Node3D
	return null


func _is_watched_by_player(player: Node) -> bool:
	if not player is Node3D:
		return false
	if player.has_method("has_control") and not player.has_control():
		return false

	var player_node := player as Node3D
	var camera := player_node.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		return false

	var offset := global_position - camera.global_position
	if offset.length_squared() > trigger_distance * trigger_distance:
		return false

	var direction_to_watcher := offset.normalized()
	var camera_forward := -camera.global_basis.z.normalized()
	if camera_forward.dot(direction_to_watcher) < gaze_dot_threshold:
		return false

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, global_position)
	query.exclude = []
	if player_node is CollisionObject3D:
		query.exclude.append((player_node as CollisionObject3D).get_rid())
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	var collider := hit.get("collider") as Node
	return collider == self or is_ancestor_of(collider)


func _advance_toward_last_observer() -> void:
	var target := Vector3(last_observer_position.x, global_position.y, last_observer_position.z)
	var offset := target - global_position
	var distance := offset.length()
	if distance <= learned_step_minimum_range:
		return

	var step_distance := minf(learned_step_distance, distance - learned_step_minimum_range)
	var destination := global_position + offset.normalized() * step_distance
	var query := PhysicsRayQueryParameters3D.create(global_position, destination)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return
	global_position = destination
	advanced.emit(global_position)


func _kill_player() -> void:
	active = false
	attention_hold_remaining = 0.0
	can_advance_after_gaze = false
	_clear_gaze_warning()
	killed_player.emit(death_reason)


func _clear_gaze_warning() -> void:
	if not gaze_warning_active:
		return
	gaze_warning_active = false
	gaze_cleared.emit()
