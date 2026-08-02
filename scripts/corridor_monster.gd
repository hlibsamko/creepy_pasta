class_name CorridorMonster
extends CharacterBody3D

signal killed_player(reason: String)
signal activated

const MAX_ORDINARY_CHASE_SPEED := 4.8

@export var move_speed := 4.8
@export var kill_distance := 0.9
@export var start_delay := 2.5
@export var death_reason := "Something in the corridor caught you"
@export var target_local_player_only := true
@export var sprint_hearing_range := 18.0
@export var sprint_speed_bonus := 1.35
@export var notes_required_to_activate := 0
@export var patrol_radius := 0.0
@export var patrol_wait_time := 1.2
@export var noisy_target_fixation_seconds := 3.5
@export var noise_search_seconds := 2.5
@export var intercept_lead_seconds := 0.45
@export var journal_entry_id := "listener"
@export_range(0, 3, 1) var journal_fact_index_on_activation := 2

@onready var kill_zone: Area3D = $KillZone

var active := true
var chase_started := false
var is_activated := false
var target: Node3D
var start_timer: Timer
var home_position := Vector3.ZERO
var patrol_target := Vector3.ZERO
var patrol_wait_timer := 0.0
var base_move_speed := 0.0
var base_sprint_hearing_range := 0.0
var knowledge_behavior_tier := 0
var fixated_target: Node3D
var fixation_remaining := 0.0
var noise_search_remaining := 0.0
var last_heard_position := Vector3.ZERO


func _ready() -> void:
	add_to_group("monsters")
	base_move_speed = move_speed
	base_sprint_hearing_range = sprint_hearing_range
	home_position = global_position
	patrol_target = home_position
	kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	if notes_required_to_activate > 0:
		_set_dormant()
	else:
		_activate()


func _physics_process(delta: float) -> void:
	if not active or not chase_started:
		velocity = Vector3.ZERO
		return

	_update_behavior_memory(delta)
	target = _find_target()
	if not target:
		if _update_noise_search():
			return
		_update_patrol(delta)
		return

	var offset := _get_chase_position(target) - global_position
	offset.y = 0.0
	if offset.length() <= kill_distance:
		_kill_player()
		return

	var speed := move_speed * sprint_speed_bonus if _is_target_sprinting(target) else move_speed
	speed = minf(speed, MAX_ORDINARY_CHASE_SPEED)
	velocity = offset.normalized() * speed
	_face_movement_direction(velocity)
	move_and_slide()


func _face_movement_direction(direction: Vector3) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return
	look_at(global_position + flat_direction.normalized(), Vector3.UP)


func stop_chase() -> void:
	active = false
	velocity = Vector3.ZERO
	_clear_behavior_memory()
	if start_timer and not start_timer.is_stopped():
		start_timer.stop()


func set_note_progress(collected_count: int, _total_count: int) -> void:
	if notes_required_to_activate <= 0 or is_activated:
		return
	if collected_count >= notes_required_to_activate:
		_activate()


func is_note_gated_activated() -> bool:
	return is_activated


func set_note_gated_activated(should_be_activated: bool) -> void:
	if should_be_activated:
		_activate()
	elif notes_required_to_activate > 0:
		_set_dormant()


func set_knowledge_difficulty(completion_ratio: float) -> void:
	var difficulty := clampf(completion_ratio, 0.0, 1.0)
	move_speed = base_move_speed * lerpf(1.0, 1.22, difficulty)
	sprint_hearing_range = base_sprint_hearing_range * lerpf(1.0, 1.18, difficulty)


func set_knowledge_profile(completion_ratio: float, entry_completion_ratio: float) -> void:
	set_knowledge_difficulty(completion_ratio)
	var entry_progress := clampf(entry_completion_ratio, 0.0, 1.0)
	var next_tier := 0
	if entry_progress >= 2.0 / 3.0:
		next_tier = 2
	elif entry_progress >= 1.0 / 3.0:
		next_tier = 1
	if next_tier < 1:
		_clear_behavior_memory()
	knowledge_behavior_tier = next_tier


func get_knowledge_behavior_tier() -> int:
	return knowledge_behavior_tier


func get_knowledge_behavior_message() -> String:
	match knowledge_behavior_tier:
		1:
			return "The Listener learned your rhythm. It now commits to the loudest footsteps."
		2:
			return "The Listener learned your routes. It now cuts ahead of sprinting prey."
	return ""


func _find_target() -> Node3D:
	if knowledge_behavior_tier >= 1 and _is_valid_fixated_target():
		return fixated_target

	var best_target: Node3D
	var best_distance := INF
	var loudest_target: Node3D
	var loudest_distance := INF
	for player in get_tree().get_nodes_in_group("players"):
		if target_local_player_only and player.has_method("has_control") and not player.has_control():
			continue
		if not player is Node3D:
			continue
		var distance := global_position.distance_squared_to((player as Node3D).global_position)
		if distance < best_distance:
			best_target = player
			best_distance = distance
		if (
			_is_target_sprinting(player as Node3D)
			and distance <= sprint_hearing_range * sprint_hearing_range
			and distance < loudest_distance
		):
			loudest_target = player
			loudest_distance = distance
	if loudest_target:
		if knowledge_behavior_tier >= 1:
			_remember_noisy_target(loudest_target)
		return loudest_target
	if knowledge_behavior_tier >= 1 and noise_search_remaining > 0.0:
		return null
	return best_target


func _remember_noisy_target(noisy_target: Node3D) -> void:
	fixated_target = noisy_target
	fixation_remaining = noisy_target_fixation_seconds
	noise_search_remaining = noise_search_seconds
	last_heard_position = noisy_target.global_position


func _is_valid_fixated_target() -> bool:
	if not is_instance_valid(fixated_target) or not fixated_target.is_inside_tree():
		fixated_target = null
		fixation_remaining = 0.0
		return false
	if target_local_player_only and fixated_target.has_method("has_control") and not fixated_target.has_control():
		fixated_target = null
		fixation_remaining = 0.0
		return false
	return fixation_remaining > 0.0


func _update_behavior_memory(delta: float) -> void:
	var remaining_delta := delta
	if fixation_remaining > 0.0:
		var fixation_step := minf(fixation_remaining, remaining_delta)
		fixation_remaining -= fixation_step
		remaining_delta -= fixation_step
		if fixation_remaining <= 0.0:
			fixated_target = null
	elif fixated_target:
		fixated_target = null
	if not fixated_target and noise_search_remaining > 0.0 and remaining_delta > 0.0:
		noise_search_remaining = maxf(noise_search_remaining - remaining_delta, 0.0)


func _update_noise_search() -> bool:
	if knowledge_behavior_tier < 1 or noise_search_remaining <= 0.0:
		return false
	var offset := last_heard_position - global_position
	offset.y = 0.0
	if offset.length() <= 0.3:
		velocity = Vector3.ZERO
		return true
	velocity = offset.normalized() * (move_speed * 0.72)
	_face_movement_direction(velocity)
	move_and_slide()
	return true


func _get_chase_position(candidate: Node3D) -> Vector3:
	var chase_position := candidate.global_position
	if knowledge_behavior_tier < 2 or not _is_target_sprinting(candidate):
		return chase_position
	var candidate_velocity: Variant = candidate.get("velocity")
	if candidate_velocity is Vector3:
		var horizontal_velocity: Vector3 = candidate_velocity
		horizontal_velocity.y = 0.0
		chase_position += horizontal_velocity * intercept_lead_seconds
	return chase_position


func _clear_behavior_memory() -> void:
	fixated_target = null
	fixation_remaining = 0.0
	noise_search_remaining = 0.0
	last_heard_position = global_position


func _update_patrol(delta: float) -> void:
	if patrol_radius <= 0.0:
		velocity = Vector3.ZERO
		return

	var offset := patrol_target - global_position
	offset.y = 0.0
	if offset.length() <= 0.25:
		velocity = Vector3.ZERO
		patrol_wait_timer -= delta
		if patrol_wait_timer <= 0.0:
			_pick_patrol_target()
		return

	velocity = offset.normalized() * (move_speed * 0.45)
	_face_movement_direction(velocity)
	move_and_slide()


func _pick_patrol_target() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs((str(get_path()) + str(Time.get_ticks_msec())).hash())
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(patrol_radius * 0.35, patrol_radius)
	patrol_target = home_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	patrol_wait_timer = patrol_wait_time


func _is_target_sprinting(candidate: Node3D) -> bool:
	if not candidate:
		return false
	return bool(candidate.get("is_sprinting"))


func _on_kill_zone_body_entered(body: Node3D) -> void:
	if not active or not chase_started:
		return
	if body.has_method("has_control") and body.has_control():
		_kill_player()


func _kill_player() -> void:
	active = false
	killed_player.emit(death_reason)


func _start_chase_after_delay() -> void:
	if start_timer:
		start_timer.queue_free()
	start_timer = Timer.new()
	start_timer.one_shot = true
	start_timer.wait_time = start_delay
	start_timer.timeout.connect(_on_start_timer_timeout)
	add_child(start_timer)
	start_timer.start()


func _on_start_timer_timeout() -> void:
	if active:
		chase_started = true


func _activate() -> void:
	var was_activated := is_activated
	is_activated = true
	active = true
	_clear_behavior_memory()
	visible = true
	home_position = global_position
	patrol_target = home_position
	collision_layer = 1 << 3
	collision_mask = 1
	kill_zone.monitoring = true
	_start_chase_after_delay()
	if not was_activated:
		activated.emit()


func _set_dormant() -> void:
	is_activated = false
	active = false
	chase_started = false
	velocity = Vector3.ZERO
	_clear_behavior_memory()
	visible = false
	collision_layer = 0
	collision_mask = 0
	kill_zone.monitoring = false
