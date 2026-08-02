extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")

var main: Node
var completed := false


func _ready() -> void:
	main = MAIN_SCENE.instantiate()
	main.name = "Main"
	get_tree().root.call_deferred("add_child", main)
	await get_tree().process_frame
	main.network.connected_to_server.connect(_on_connected)
	main.network.server_disconnected.connect(_on_server_disconnected)
	var error: Error = main.network.join("ws://127.0.0.1:24567")
	if error != OK:
		_fail("Could not connect smoke client: %s" % error)
		return
	get_tree().create_timer(150.0).timeout.connect(_on_timeout)


func _on_connected() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	main._server_create_online_session.rpc_id(1)
	await get_tree().create_timer(0.75).timeout
	if str(main.active_session_id) == "":
		_fail("Server did not create and join a clean online session")
		return
	if not main.players.has_node(str(multiplayer.get_unique_id())):
		_fail("Online session did not spawn the local player")
		return
	main._request_online_breaker_outage.rpc_id(
		1,
		"EndlessHouseBuilder/GeneratedBackrooms/Mechanics/GeneratedBreakerTrigger1"
	)
	await get_tree().create_timer(0.35).timeout
	if bool(main.call("_is_level_exit_open")) or main.monster_journal.has_fact("unlit", 3):
		_fail("Room 1 accepted a stale Unlit breaker authority request")
		return
	main._request_collect_note.rpc_id(1, "Note1")
	await get_tree().create_timer(0.4).timeout
	if int(main.collected_notes) != 0:
		_fail("Server accepted Room 1 record collection from spawn")
		return
	await _move_local_player_to(Vector3(-4.9, 0.2, -1.8))
	main._request_collect_note.rpc_id(1, "Note1")
	await get_tree().create_timer(1.0).timeout
	if not multiplayer.has_multiplayer_peer():
		_fail("Server connection disappeared after Note1 request")
		return
	if not str(main.last_recovered_record_text).contains("Torn maintenance log"):
		_fail("Authoritative Room 1 collection returned generic copy instead of the scene record")
		return
	if not main.monster_journal.has_fact("listener", 2):
		_fail("Server note progress did not grant the Listener activation fact")
		return
	main._request_journal_discovery.rpc_id(
		1,
		"DialogueNpcs/EntryRadio",
		true,
		"listener",
		1,
		"light_barrier"
	)
	await get_tree().create_timer(0.5).timeout
	if (
		main.monster_journal.unlocked
		or main.monster_journal.has_fact("listener", 1)
		or main.monster_journal.has_rumor("listener", "light_barrier")
	):
		_fail("Room 1 accepted a forged combined journal unlock/fact/rumor request")
		return
	main._request_journal_discovery.rpc_id(
		1,
		"Monsters/OpeningListener",
		false,
		"listener",
		0,
		"light_barrier"
	)
	await get_tree().create_timer(0.4).timeout
	if main.monster_journal.has_rumor("listener", "light_barrier"):
		_fail("Room 1 accepted the radio rumor from the wrong scene source")
		return
	await _move_local_player_to(Vector3(0.0, 0.2, 0.0))
	main._request_journal_discovery.rpc_id(
		1,
		"DialogueNpcs/EntryRadio",
		false,
		"listener",
		0,
		"light_barrier"
	)
	await get_tree().create_timer(0.4).timeout
	if main.monster_journal.has_rumor("listener", "light_barrier"):
		_fail("Room 1 accepted the radio rumor while the player was out of range")
		return
	await _move_local_player_to(Vector3(-2.65, 0.2, -4.7))
	main._request_journal_discovery.rpc_id(
		1,
		"DialogueNpcs/EntryRadio",
		false,
		"listener",
		0,
		"light_barrier"
	)
	await get_tree().create_timer(0.5).timeout
	if not main.monster_journal.has_rumor("listener", "light_barrier"):
		_fail("Server did not synchronize the allowed Room 1 radio rumor")
		return
	if main.monster_journal.unlocked or main.monster_journal.has_fact("listener", 1):
		_fail("The allowed Room 1 rumor also unlocked journal state")
		return
	main._on_player_killed("Smoke death")
	main._retry_after_end()
	await get_tree().create_timer(1.0).timeout
	if not multiplayer.has_multiplayer_peer() or not main.started:
		_fail("Online Restart disconnected or did not resume the session")
		return
	if main.ui.death_panel.visible:
		_fail("Online Restart left the death overlay visible")
		return
	var local_player: Node = main.players.get_node_or_null(str(multiplayer.get_unique_id()))
	if not local_player or not bool(local_player.get("controls_enabled")):
		_fail("Online Restart did not restore the local player controls")
		return
	main._request_session_reset.rpc_id(1)
	await get_tree().create_timer(1.0).timeout
	if int(main.collected_notes) != 0:
		_fail("Online session reset did not clear collected notes")
		return
	if main.current_level_scene.resource_path != "res://scenes/level.tscn":
		_fail("Online session reset did not restore Room 1")
		return
	if main.monster_journal.unlocked:
		_fail("Online session reset did not clear journal progress")
		return
	if not await _advance_to_backrooms():
		return
	main._on_player_killed("Backrooms smoke death")
	main._retry_after_end()
	await get_tree().create_timer(0.8).timeout
	if main.current_level_scene.resource_path != "res://scenes/backrooms/backrooms_builder_demo.tscn":
		_fail("Backrooms Restart moved the player to a different level")
		return
	if main.ui.death_panel.visible or not main.started:
		_fail("Backrooms Restart did not restore playable state")
		return
	if not main.monster_journal.has_fact("house", 1) or not main.monster_journal.has_fact("house", 2):
		_fail("Backrooms Restart lost synchronized optional House records")
		return
	if not await _advance_through_house_survey():
		return
	completed = true
	print("[smoke] Session create, House and Unlit sync, Restart, and isolated reset kept server alive")
	get_tree().quit()


func _advance_to_backrooms() -> bool:
	await _move_local_player_to(Vector3(-4.9, 0.2, -1.8))
	main._request_collect_note.rpc_id(1, "Note1")
	await get_tree().create_timer(0.35).timeout
	await _move_local_player_to(Vector3(4.8, 0.2, 1.1))
	main._request_collect_note.rpc_id(1, "Note2")
	await get_tree().create_timer(0.7).timeout
	if not bool(main.call("_is_level_exit_open")):
		_fail("Room 1 session exit did not open after two records")
		return false
	main._request_next_level_transition.rpc_id(1)
	await get_tree().create_timer(0.4).timeout
	if main.current_level_scene.resource_path != "res://scenes/level.tscn":
		_fail("Room 1 accepted a transition request away from its exit")
		return false
	await _move_local_player_to(Vector3(0.0, 0.2, 3.8))
	main._request_next_level_transition.rpc_id(1)
	await get_tree().create_timer(0.8).timeout
	if main.current_level_scene.resource_path != "res://scenes/next_place.tscn":
		_fail("Session did not transition from Room 1 to Room 2")
		return false
	await _move_local_player_to(Vector3(4.5, 0.2, -4.0))
	main._request_journal_discovery.rpc_id(
		1,
		"DialogueNpcs/Mara",
		true,
		"listener",
		1,
		""
	)
	await get_tree().create_timer(0.4).timeout
	if main.monster_journal.unlocked or main.monster_journal.has_fact("listener", 1):
		_fail("Room 2 accepted Mara's journal handoff while the player was out of range")
		return false
	await _move_local_player_to(Vector3(-4.35, 0.2, -2.9))
	main._request_journal_discovery.rpc_id(
		1,
		"DialogueNpcs/Mara",
		true,
		"listener",
		1,
		""
	)
	await get_tree().create_timer(0.5).timeout
	if not main.monster_journal.unlocked or not main.monster_journal.has_fact("listener", 1):
		_fail("Room 2 rejected Mara's allowed journal handoff")
		return false
	await _move_local_player_to(Vector3(-5.6, 0.2, 3.8))
	main._request_collect_note.rpc_id(1, "Fragment1")
	await get_tree().create_timer(0.35).timeout
	await _move_local_player_to(Vector3(0.0, 0.2, 3.4))
	main._request_collect_note.rpc_id(1, "Fragment3")
	main._request_online_pressure_state.rpc_id(1, "UnknownPressurePlate", true)
	await get_tree().create_timer(0.35).timeout
	if bool(main.call("_is_level_exit_open")):
		_fail("Room 2 accepted an unknown pressure-plate path")
		return false
	main._request_online_pressure_state.rpc_id(1, "PressurePlate", true)
	await get_tree().create_timer(0.35).timeout
	if bool(main.call("_is_level_exit_open")):
		_fail("Room 2 accepted pressure activation while the player was out of range")
		return false
	await _move_local_player_to(Vector3(0.0, 0.2, -2.55))
	main._request_online_pressure_state.rpc_id(1, "PressurePlate", true)
	await get_tree().create_timer(0.7).timeout
	if not main.monster_journal.has_rumor("mimic", "replicated_room"):
		_fail("Room 2 survey theory did not synchronize from the authoritative server")
		return false
	if not main.monster_journal.has_fact("mimic", 1):
		_fail("Room 2 voice-recording fact did not synchronize with the survey theory")
		return false
	if not bool(main.call("_is_level_exit_open")):
		_fail("Room 2 session exit did not open after records and pressure switch")
		return false
	await _move_local_player_to(Vector3(0.0, 0.2, -3.0))
	main._request_next_level_transition.rpc_id(1)
	await get_tree().create_timer(0.8).timeout
	if main.current_level_scene.resource_path != "res://scenes/backrooms/backrooms_builder_demo.tscn":
		_fail("Session did not transition from Room 2 to Backrooms")
		return false
	if int(main.total_notes) != 2:
		_fail("Backrooms session did not expose exactly two active records")
		return false
	var required_progress_before: float = main.monster_journal.get_completion_ratio()
	await _move_local_player_to(Vector3(16.0, 0.2, 4.0))
	main._request_collect_note.rpc_id(1, "GeneratedNote1")
	await get_tree().create_timer(0.35).timeout
	await _move_local_player_to(Vector3(24.0, 0.2, 20.0))
	main._request_collect_note.rpc_id(1, "GeneratedNote3")
	await get_tree().create_timer(0.7).timeout
	if not main.monster_journal.has_fact("house", 1) or not main.monster_journal.has_fact("house", 2):
		_fail("Backrooms House records did not synchronize from the authoritative server")
		return false
	if not is_equal_approx(main.monster_journal.get_completion_ratio(), required_progress_before):
		_fail("Optional House records changed required online bestiary progress")
		return false
	var watcher_path := "BackroomsBuilder/GeneratedBackrooms/Monsters/GeneratedWatcher1"
	main._request_journal_discovery.rpc_id(
		1,
		watcher_path,
		false,
		"watcher",
		2,
		""
	)
	await get_tree().create_timer(0.35).timeout
	if main.monster_journal.has_fact("watcher", 2):
		_fail("Backrooms accepted Watcher observation while the player was out of range")
		return false
	await _move_local_player_to(Vector3(8.0, 0.2, 28.0))
	main._request_journal_discovery.rpc_id(
		1,
		watcher_path,
		false,
		"watcher",
		2,
		""
	)
	await get_tree().create_timer(0.35).timeout
	if main.monster_journal.has_fact("watcher", 2):
		_fail("Backrooms accepted Watcher observation while the player faced away")
		return false
	await _set_local_player_view(-PI * 0.5, 0.0)
	main._request_journal_discovery.rpc_id(
		1,
		watcher_path,
		false,
		"watcher",
		2,
		""
	)
	await get_tree().create_timer(0.35).timeout
	await _set_local_player_view(0.0, 0.0)
	if not main.monster_journal.has_fact("watcher", 2):
		_fail("Backrooms rejected a nearby player facing the Watcher")
		return false
	return true


func _advance_through_house_survey() -> bool:
	if main.ui.death_panel.visible:
		main._retry_after_end()
		await get_tree().create_timer(1.0).timeout
	if main.ui.death_panel.visible or not main.started:
		_fail("Backrooms network traversal could not recover before exit checks")
		return false
	for monster in main.call("_get_level_monsters"):
		if monster.has_method("stop_chase"):
			monster.call("stop_chase")
	main._request_online_pressure_state.rpc_id(1, "PressurePlate", true)
	await get_tree().create_timer(0.35).timeout
	if bool(main.call("_is_level_exit_open")):
		_fail("Backrooms accepted the stale Room 2 pressure-plate path")
		return false
	var backrooms_plate_path := "BackroomsBuilder/GeneratedBackrooms/Mechanics/PressurePlate"
	main._request_online_pressure_state.rpc_id(
		1,
		backrooms_plate_path,
		true
	)
	await get_tree().create_timer(0.35).timeout
	if bool(main.call("_is_level_exit_open")):
		_fail("Backrooms accepted pressure activation while the player was out of range")
		return false
	await _move_local_player_to(Vector3(32.0, 0.2, 24.0))
	main._request_online_pressure_state.rpc_id(
		1,
		backrooms_plate_path,
		true
	)
	await get_tree().create_timer(0.6).timeout
	if not bool(main.call("_is_level_exit_open")):
		_fail("Backrooms exit did not reopen after Restart and pressure activation")
		return false
	await _move_local_player_to(Vector3(34.45, 0.2, 28.0))
	main._request_next_level_transition.rpc_id(1)
	await get_tree().create_timer(0.8).timeout
	if main.current_level_scene.resource_path != "res://scenes/endless_house/endless_house_builder_demo.tscn":
		_fail("Session did not transition from Backrooms to the House survey")
		return false
	if int(main.total_notes) != 1:
		_fail("House survey did not expose exactly one short record task")
		return false
	main._request_journal_discovery.rpc_id(
		1,
		"EndlessHouseBuilder/GeneratedBackrooms/Monsters/GeneratedMimicDoor1",
		false,
		"mimic",
		2,
		""
	)
	await get_tree().create_timer(0.35).timeout
	if main.monster_journal.has_fact("mimic", 2):
		_fail("House survey accepted False Door observation from spawn")
		return false
	var required_progress_before: float = main.monster_journal.get_completion_ratio()
	await _move_local_player_to(Vector3(4.0, 0.2, 12.0))
	main._request_collect_note.rpc_id(1, "GeneratedNote1")
	await get_tree().create_timer(0.7).timeout
	if not main.monster_journal.has_fact("house", 3):
		_fail("House survey record did not synchronize from the authoritative server")
		return false
	if not str(main.ui.hud_label.text).contains("no draft"):
		_fail("Authoritative House collection returned generic copy instead of the survey record")
		return false
	if not is_equal_approx(main.monster_journal.get_completion_ratio(), required_progress_before):
		_fail("House survey lore changed required online bestiary progress")
		return false
	if not bool(main.call("_is_level_exit_open")):
		_fail("House survey exit did not open after its single record")
		return false
	await _move_local_player_to(Vector3(40.0, 0.2, 5.55))
	main._request_next_level_transition.rpc_id(1)
	await get_tree().create_timer(0.8).timeout
	if main.current_level_scene.resource_path != "res://scenes/endless_house/unlit_evidence_demo.tscn":
		_fail("Session did not transition from the House survey to The Unlit")
		return false
	return await _advance_through_unlit()


func _advance_through_unlit() -> bool:
	await get_tree().create_timer(0.5).timeout
	var monster_path := "EndlessHouseBuilder/GeneratedBackrooms/Monsters/GeneratedLightShyMonster1"
	var monster := main.level.get_node_or_null(monster_path) as LightShyMonster
	if not monster or not monster.is_authoritative_state_enabled():
		_fail("The Unlit production room did not receive server-owned creature state")
		return false
	if main.ui.death_panel.visible:
		_fail(
			"The player entered The Unlit already dead: reason=%s authority=%s"
			% [main.get("last_death_reason"), main.get("last_death_was_server_authoritative")]
		)
		return false
	if not await _approach_unlit_until_death(monster_path):
		_fail("The Unlit server-owned contact did not kill the approaching player")
		return false
	if not bool(main.get("last_death_was_server_authoritative")):
		_fail("The Unlit contact death came from a local client Area3D instead of the server")
		return false
	main._retry_after_end()
	await get_tree().create_timer(1.0).timeout
	var local_player := main.players.get_node_or_null(str(multiplayer.get_unique_id())) as Node3D
	monster = main.level.get_node_or_null(monster_path) as LightShyMonster
	if (
		main.current_level_scene.resource_path != "res://scenes/endless_house/unlit_evidence_demo.tscn"
		or main.ui.death_panel.visible
		or not main.started
		or not local_player
		or not bool(local_player.get("controls_enabled"))
		or not monster
		or not monster.is_authoritative_state_enabled()
		or monster.global_position.distance_to(Vector3(24.0, 0.0, 20.0)) > 2.5
	):
		_fail(
			"The Unlit Restart did not restore a playable room: level=%s death=%s started=%s player=%s controls=%s monster=%s authority=%s distance=%.2f"
			% [
				main.current_level_scene.resource_path,
				main.ui.death_panel.visible,
				main.started,
				local_player != null,
				bool(local_player.get("controls_enabled")) if local_player else false,
				monster != null,
				monster.is_authoritative_state_enabled() if monster else false,
				monster.global_position.distance_to(Vector3(24.0, 0.0, 20.0)) if monster else -1.0,
			]
		)
		return false

	await _move_local_player_to(Vector3(12.0, 0.2, 4.0))
	main._request_collect_note.rpc_id(1, "GeneratedNote1")
	await get_tree().create_timer(0.7).timeout
	if not main.monster_journal.has_fact("unlit", 1):
		_fail("The Unlit maintenance record did not synchronize from the server")
		return false
	if bool(main.call("_is_level_exit_open")):
		_fail("The Unlit record opened the exit before the breaker")
		return false
	var breaker_path := "EndlessHouseBuilder/GeneratedBackrooms/Mechanics/GeneratedBreakerTrigger1"
	main._request_online_breaker_outage.rpc_id(1, breaker_path)
	await get_tree().create_timer(0.35).timeout
	if main.monster_journal.has_fact("unlit", 3) or bool(main.call("_is_level_exit_open")):
		_fail("The Unlit server accepted its breaker while the player was out of range")
		return false

	await _move_local_player_to(Vector3(36.0, 0.2, 20.0))
	main._request_online_breaker_outage.rpc_id(1, breaker_path)
	await get_tree().create_timer(0.8).timeout
	var breaker: Node = main.level.get_node_or_null(breaker_path)
	if (
		not main.monster_journal.has_fact("unlit", 3)
		or not bool(main.call("_is_level_exit_open"))
		or not breaker
		or not bool(breaker.call("is_triggered"))
	):
		_fail("The Unlit breaker did not synchronize evidence, spent state, and exit")
		return false

	await _move_local_player_to(Vector3(36.0, 0.2, 4.0))
	main._request_next_level_transition.rpc_id(1)
	await get_tree().create_timer(0.8).timeout
	if main.current_level_scene.resource_path != "res://scenes/corridor.tscn":
		_fail("Session did not transition from The Unlit to the corridor")
		return false
	return true


func _approach_unlit_until_death(monster_path: String) -> bool:
	var local_player := main.players.get_node_or_null(str(multiplayer.get_unique_id())) as Node3D
	if not local_player:
		return false
	local_player.call("set_controls_enabled", false)
	for _step in range(240):
		if main.ui.death_panel.visible:
			return true
		var monster := main.level.get_node_or_null(monster_path) as Node3D
		if not monster:
			return false
		var target := monster.global_position
		target.y = local_player.global_position.y
		var next_position := local_player.global_position.move_toward(target, 4.0 * 0.05)
		var offset := target - next_position
		var yaw := local_player.rotation.y
		if Vector2(offset.x, offset.z).length_squared() > 0.001:
			yaw = atan2(-offset.x, -offset.z)
		local_player.global_position = next_position
		local_player.rotation.y = yaw
		local_player.rpc("_sync_state", next_position, yaw, 0.0)
		await get_tree().create_timer(0.05).timeout
	return main.ui.death_panel.visible


func _move_local_player_to(target_position: Vector3) -> void:
	var local_player := main.players.get_node_or_null(str(multiplayer.get_unique_id())) as Node3D
	if not local_player:
		_fail("Network movement helper could not find the local player")
		return
	var start_position := local_player.global_position
	var distance := start_position.distance_to(target_position)
	var step_count := maxi(ceili(distance / (4.8 * 0.05)), 1)
	local_player.call("set_controls_enabled", false)
	for step in range(1, step_count + 1):
		var next_position := start_position.lerp(
			target_position,
			float(step) / float(step_count)
		)
		local_player.global_position = next_position
		local_player.rpc("_sync_state", next_position, local_player.rotation.y, 0.0)
		await get_tree().create_timer(0.05).timeout
	local_player.call("set_controls_enabled", true)
	await get_tree().create_timer(0.2).timeout


func _set_local_player_view(yaw: float, pitch: float) -> void:
	var local_player := main.players.get_node_or_null(str(multiplayer.get_unique_id())) as Node3D
	if not local_player:
		_fail("Network view helper could not find the local player")
		return
	var head := local_player.get_node_or_null("Head") as Node3D
	local_player.rotation.y = yaw
	if head:
		head.rotation.x = pitch
	local_player.rpc("_sync_state", local_player.global_position, yaw, pitch)
	await get_tree().create_timer(0.2).timeout


func _on_server_disconnected() -> void:
	if not completed:
		_fail("Dedicated server disconnected after Note1 request")


func _on_timeout() -> void:
	if not completed:
		_fail("Network note smoke timed out")


func _fail(message: String) -> void:
	print("[smoke] FAIL: %s" % message)
	push_error(message)
	get_tree().quit(1)
