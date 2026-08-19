extends Node

const ACCOUNT_GAME_BRIDGE := preload("res://scripts/account_game_bridge.gd")


func _ready() -> void:
	var bridge := ACCOUNT_GAME_BRIDGE.new()
	add_child(bridge)
	# Keep the worker retrying locally so we can inspect ordering without an API.
	bridge.internal_base_url = "http://127.0.0.1:1"
	bridge.internal_secret = "smoke-internal-secret-that-is-at-least-32-chars"
	bridge.disable_queue_drain_for_tests()
	var play_session_id := "00000000-0000-0000-0000-000000000001"
	bridge.enqueue_heartbeat(play_session_id, false)
	bridge.enqueue_heartbeat(play_session_id, true)
	bridge.enqueue_event(play_session_id, "event-1", "achievement", "first_record")
	bridge.enqueue_heartbeat(play_session_id, false)
	bridge.enqueue_heartbeat(play_session_id, true)
	bridge.enqueue_heartbeat(play_session_id, true)
	bridge.enqueue_end(play_session_id)
	bridge.enqueue_event(play_session_id, "late-event", "death")

	var snapshot := bridge.queued_operation_snapshot(play_session_id)
	var expected := [
		["heartbeat", false],
		["heartbeat", true],
		["event", false],
		["heartbeat", false],
		["heartbeat", true],
		["end", false],
	]
	if snapshot.size() != expected.size():
		_fail("Account bridge queue lost or accepted a terminal operation")
		return
	for index in snapshot.size():
		var operation: Dictionary = snapshot[index]
		if (
			str(operation.get("kind", "")) != str(expected[index][0])
			or bool(operation.get("active", false)) != bool(expected[index][1])
		):
			_fail("Account bridge queue reordered activity transitions")
			return
	bridge.clear_queued_operations_for_tests()
	bridge.queue_free()
	print("[smoke] Account game bridge queue ordering OK")
	get_tree().call_deferred("quit")


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
