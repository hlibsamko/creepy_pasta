extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")

var main: Node
var completed := false
var initial_connection_started := false


func _ready() -> void:
	main = MAIN_SCENE.instantiate()
	main.name = "Main"
	get_tree().root.call_deferred("add_child", main)
	await get_tree().process_frame
	main.network.connected_to_server.connect(_on_connected)
	var local_server_url := "ws://127.0.0.1:24567"
	main.last_join_address = local_server_url
	var error: Error = main.network.join(local_server_url)
	if error != OK:
		_fail("Guest could not connect: %s" % error)
		return
	get_tree().create_timer(16.0).timeout.connect(_on_timeout)


func _on_connected() -> void:
	if initial_connection_started:
		return
	initial_connection_started = true
	main._server_authenticate_game_ticket.rpc_id(1, "smoke-session-guest")
	for _attempt in range(40):
		if bool(main.game_account_authenticated):
			break
		await get_tree().create_timer(0.05).timeout
	if not bool(main.game_account_authenticated):
		_fail("Guest game ticket authentication did not complete")
		return
	await get_tree().create_timer(0.3).timeout
	if main.ui.session_list.get_child_count() < 1:
		_fail("Guest lobby did not list the active owner session")
		return
	var owner_row: Node = main.ui.session_list.get_child(0)
	var owner_session_id := str(owner_row.get_meta("session_id", ""))
	if owner_session_id == "":
		_fail("Guest lobby row did not retain its explicit session ID")
		return
	main._server_join_online_session.rpc_id(1, owner_session_id)
	await get_tree().create_timer(0.8).timeout
	if str(main.active_session_id) != owner_session_id or int(main.collected_notes) != 1:
		_fail(
			"Guest join mismatch: requested=%s active=%s records=%s status=%s"
			% [
				owner_session_id,
				main.active_session_id,
				main.collected_notes,
				main.ui.status_label.text,
			]
		)
		return
	if str(main.ui.session_label.text) != "%s | 2 players" % owner_session_id:
		_fail("Joined owner session did not show two synchronized players")
		return
	main._server_create_online_session.rpc_id(1)
	await get_tree().create_timer(0.8).timeout
	if str(main.active_session_id) == "" or str(main.active_session_id) == owner_session_id:
		_fail("Guest did not enter a separate clean session")
		return
	var first_guest_session_id := str(main.active_session_id)
	main._server_create_online_session.rpc_id(1)
	await get_tree().create_timer(0.8).timeout
	if str(main.active_session_id) == first_guest_session_id:
		_fail("Guest could not switch from one clean session to another")
		return
	var reassigned_player := main.players.get_node_or_null(str(multiplayer.get_unique_id())) as Node3D
	if not reassigned_player:
		_fail("Guest Player node disappeared during session reassignment")
		return
	if str(reassigned_player.get("session_id")) != str(main.active_session_id):
		_fail(
			"Guest Player kept stale session %s after joining %s"
			% [reassigned_player.get("session_id"), main.active_session_id]
		)
		return
	var expected_spawn := Vector2(-0.8, -4.15)
	var actual_spawn := Vector2(
		reassigned_player.global_position.x,
		reassigned_player.global_position.z
	)
	if actual_spawn.distance_to(expected_spawn) > 0.08:
		_fail(
			"Guest Player kept stale horizontal spawn %s after reassignment"
			% reassigned_player.global_position
		)
		return
	if str(main.ui.session_label.text) != "%s | 1 player" % main.active_session_id:
		_fail("Clean reassigned session did not return to one synchronized player")
		return
	if int(main.collected_notes) != 0:
		_fail("Guest clean session inherited owner progress")
		return
	await _move_local_player_to(Vector3(-4.9, 0.2, -1.8))
	main._request_collect_note.rpc_id(1, "Note1")
	await get_tree().create_timer(0.7).timeout
	if int(main.collected_notes) != 1:
		_fail(
			"Guest Note1 apply mismatch: records=%s ids=%s node_exists=%s session=%s"
			% [
				main.collected_notes,
				main.collected_note_ids,
				main._get_note_by_id("Note1") != null,
				main.active_session_id,
			]
		)
		return
	main._request_session_reset.rpc_id(1)
	await get_tree().create_timer(0.8).timeout
	if int(main.collected_notes) != 0:
		_fail("Guest session reset did not clear only guest progress")
		return
	var reconnect_session_id := str(main.active_session_id)
	# The account stays signed in but reconnecting requires a new single-use
	# game ticket, just like release clients receive from AccountService.
	main.pending_game_ticket = "smoke-session-guest-reconnect"
	main._reconnect_game()
	await get_tree().create_timer(1.8).timeout
	if str(main.active_session_id) != reconnect_session_id:
		_fail(
			"Reconnect returned to %s instead of retained %s: %s"
			% [main.active_session_id, reconnect_session_id, main.ui.status_label.text]
		)
		return
	if int(main.collected_notes) != 0 or not main._get_note_by_id("Note1"):
		_fail("Reconnect did not restore the reset session's clean Room 1 state")
		return
	await _move_local_player_to(Vector3(-4.9, 0.2, -1.8))
	main._request_collect_note.rpc_id(1, "Note1")
	await get_tree().create_timer(0.7).timeout
	if int(main.collected_notes) != 1:
		_fail("Reconnected session was visible but not playable")
		return
	completed = true
	print("[smoke] Guest created and reset an isolated session, then reconnected")
	get_tree().quit()


func _move_local_player_to(target_position: Vector3) -> void:
	var local_player := main.players.get_node_or_null(str(multiplayer.get_unique_id())) as Node3D
	if not local_player:
		_fail("Guest movement helper could not find the local player")
		return
	var start_position := local_player.global_position
	var step_count := maxi(ceili(start_position.distance_to(target_position) / (4.8 * 0.05)), 1)
	local_player.call("set_controls_enabled", false)
	for step in range(1, step_count + 1):
		var next_position := start_position.lerp(target_position, float(step) / float(step_count))
		local_player.global_position = next_position
		local_player.rpc("_sync_state", next_position, local_player.rotation.y, 0.0)
		await get_tree().create_timer(0.05).timeout
	local_player.call("set_controls_enabled", true)
	await get_tree().create_timer(0.2).timeout


func _on_timeout() -> void:
	if not completed:
		_fail("Guest session isolation smoke timed out")


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
