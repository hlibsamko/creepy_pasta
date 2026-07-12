class_name CorridorMonster
extends CharacterBody3D

signal killed_player(reason: String)
signal activated

@export var move_speed := 4.8
@export var kill_distance := 0.9
@export var start_delay := 2.5
@export var death_reason := "You've been killed by corridor monster"
@export var target_local_player_only := true
@export var sprint_hearing_range := 18.0
@export var sprint_speed_bonus := 1.35
@export var notes_required_to_activate := 0
@export var patrol_radius := 0.0
@export var patrol_wait_time := 1.2

@onready var kill_zone: Area3D = $KillZone

var active := true
var chase_started := false
var is_activated := false
var target: Node3D
var start_timer: Timer
var home_position := Vector3.ZERO
var patrol_target := Vector3.ZERO
var patrol_wait_timer := 0.0


func _ready() -> void:
	add_to_group("monsters")
	home_position = global_position
	patrol_target = home_position
	kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	if notes_required_to_activate > 0:
		_set_dormant()
	else:
		_activate()


func _physics_process(_delta: float) -> void:
	if not active or not chase_started:
		velocity = Vector3.ZERO
		return

	target = _find_target()
	if not target:
		_update_patrol(_delta)
		return

	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length() <= kill_distance:
		_kill_player()
		return

	var speed := move_speed * sprint_speed_bonus if _is_target_sprinting(target) else move_speed
	velocity = offset.normalized() * speed
	move_and_slide()


func stop_chase() -> void:
	active = false
	velocity = Vector3.ZERO
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


func _find_target() -> Node3D:
	var best_target: Node3D
	var best_distance := INF
	for player in get_tree().get_nodes_in_group("players"):
		if target_local_player_only and player.has_method("has_control") and not player.has_control():
			continue
		if not player is Node3D:
			continue
		var distance := global_position.distance_squared_to((player as Node3D).global_position)
		if _is_target_sprinting(player as Node3D) and distance <= sprint_hearing_range * sprint_hearing_range:
			distance *= 0.25
		if distance < best_distance:
			best_target = player
			best_distance = distance
	return best_target


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
	visible = false
	collision_layer = 0
	collision_mask = 0
	kill_zone.monitoring = false
