class_name WatcherMonster
extends Node3D

signal killed_player(reason: String)

@export var active := true
@export var trigger_distance := 10.0
@export_range(0.75, 1.0, 0.01) var gaze_dot_threshold := 0.94
@export var stare_time_to_kill := 1.6
@export var calm_decay_speed := 1.8
@export var death_reason := "The watcher noticed you staring"

var stare_time := 0.0


func _ready() -> void:
	add_to_group("monsters")


func _process(delta: float) -> void:
	if not active:
		stare_time = 0.0
		return

	var watched := false
	for player in get_tree().get_nodes_in_group("players"):
		if _is_watched_by_player(player):
			watched = true
			break

	if watched:
		stare_time += delta
		if stare_time >= stare_time_to_kill:
			_kill_player()
	else:
		stare_time = max(stare_time - delta * calm_decay_speed, 0.0)


func stop_chase() -> void:
	active = false
	stare_time = 0.0


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
	query.exclude = [camera.get_rid()]
	if player_node is CollisionObject3D:
		query.exclude.append((player_node as CollisionObject3D).get_rid())
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	var collider := hit.get("collider") as Node
	return collider == self or is_ancestor_of(collider)


func _kill_player() -> void:
	active = false
	killed_player.emit(death_reason)
