extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const LEVEL_SCENE := preload("res://scenes/level.tscn")
const NEXT_PLACE_SCENE := preload("res://scenes/next_place.tscn")
const BACKROOMS_SCENE := preload("res://scenes/backrooms/backrooms_builder_demo.tscn")
const CORRIDOR_SCENE := preload("res://scenes/corridor.tscn")
const FOURTH_ROOM_SCENE := preload("res://scenes/fourth_room.tscn")
const SPAWNS := [
	Vector3(-5.5, 0.2, -4.5),
	Vector3(5.5, 0.2, -4.5),
	Vector3(-5.5, 0.2, 4.5),
	Vector3(5.5, 0.2, 4.5),
	Vector3(0.0, 0.2, 0.0),
]
const PLAYER_COLORS := [
	Color(0.95, 0.88, 0.55),
	Color(0.45, 0.85, 1.00),
	Color(0.95, 0.45, 0.58),
	Color(0.55, 1.00, 0.62),
	Color(0.72, 0.58, 1.00),
]
const CONNECTION_TIMEOUT_SECONDS := 10.0

@onready var network: Node = $NetworkManager
@onready var day_night_cycle: Node = $DayNightCycle
@onready var audio_cues: Node = $AudioCues
@onready var level: Node3D = $Level
@onready var notes: Node3D = $Level/Notes
@onready var level_exit: Area3D = $Level/LevelExit
@onready var players: Node3D = $Players
@onready var ui: CanvasLayer = $Ui

var collected_notes := 0
var total_notes := 0
var collected_note_ids: Array[String] = []
var session_collected_notes := 0
var started := false
var current_level_scene: PackedScene = LEVEL_SCENE
var nearby_dialogue_npc: DialogueNpc
var active_dialogue_npc: DialogueNpc
var active_dialogue_pages: Array[String] = []
var active_dialogue_index := 0
var level_transitioning := false
var last_join_address := ""
var connection_timer: Timer
var suppress_disconnect_until_msec := 0


func _ready() -> void:
	_setup_connection_timer()
	day_night_cycle.set_target_level(level)
	_connect_network()
	_connect_ui()
	_connect_level_interactables()
	ui.set_join_address(network.get_join_hint())
	last_join_address = network.get_join_hint()
	if network.is_dedicated_server():
		_start_dedicated_server()
		return
	if audio_cues.has_method("play_ambience"):
		audio_cues.play_ambience(current_level_scene.resource_path)
	_update_objective()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _should_capture_game_input(event):
		_capture_game_input()
		return

	if _handle_debug_cycle_input(event):
		return

	if ui.is_dialogue_visible():
		if event.is_action_pressed("dialogue_next"):
			_advance_dialogue()
		elif event.is_action_pressed("ui_cancel"):
			_end_dialogue()
		return
	if event.is_action_pressed("interact") and nearby_dialogue_npc:
		_start_dialogue(nearby_dialogue_npc)
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause_menu()


func _connect_network() -> void:
	network.connected_to_server.connect(_on_connected_to_server)
	network.connection_failed.connect(_on_connection_failed)
	network.server_disconnected.connect(_on_server_disconnected)
	network.peer_connected.connect(_on_peer_connected)
	network.peer_disconnected.connect(_on_peer_disconnected)


func _connect_ui() -> void:
	ui.host_requested.connect(_host_game)
	ui.join_requested.connect(_join_game)
	ui.offline_requested.connect(_start_offline)
	ui.reconnect_requested.connect(_reconnect_game)
	ui.retry_requested.connect(_retry_after_end)
	ui.main_menu_requested.connect(_return_to_menu)
	ui.note_puzzle_completed.connect(_on_note_puzzle_completed)
	ui.note_puzzle_cancelled.connect(_on_note_puzzle_cancelled)


func _connect_level_interactables() -> void:
	_connect_notes()
	_connect_level_exit()
	_connect_monsters()
	_connect_pressure_plates()
	_connect_dialogue_npcs()


func _connect_notes() -> void:
	total_notes = 0
	for note in _get_level_notes():
		if not note.has_signal("collected"):
			continue
		total_notes += 1
		note.collected.connect(_on_note_collected)
		if note.has_signal("puzzle_requested"):
			note.puzzle_requested.connect(_on_note_puzzle_requested)


func _connect_level_exit() -> void:
	if not level_exit or not level_exit.has_signal("entered"):
		return
	level_exit.entered.connect(_on_level_exit_entered)


func _connect_monsters() -> void:
	for monster in _get_level_monsters():
		if monster.has_signal("killed_player"):
			monster.killed_player.connect(_on_player_killed)
		if monster.has_signal("activated"):
			monster.activated.connect(_on_monster_activated)


func _connect_pressure_plates() -> void:
	for plate in _get_level_pressure_plates():
		if plate.has_signal("active_changed"):
			plate.active_changed.connect(_on_pressure_plate_changed)


func _connect_dialogue_npcs() -> void:
	var dialogue_npcs := level.get_node_or_null("DialogueNpcs")
	if not dialogue_npcs:
		return
	for npc in dialogue_npcs.get_children():
		if npc.has_signal("player_entered"):
			npc.player_entered.connect(_on_dialogue_npc_entered)
		if npc.has_signal("player_exited"):
			npc.player_exited.connect(_on_dialogue_npc_exited)


func _setup_connection_timer() -> void:
	connection_timer = Timer.new()
	connection_timer.one_shot = true
	connection_timer.wait_time = CONNECTION_TIMEOUT_SECONDS
	connection_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timer)


func _start_connection_timer() -> void:
	connection_timer.start()


func _stop_connection_timer() -> void:
	if connection_timer and not connection_timer.is_stopped():
		connection_timer.stop()


func _on_connection_timeout() -> void:
	_close_network_locally()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_menu()
	ui.set_connecting(false)
	ui.set_status("Connection timed out. Check the server and try Reconnect.")


func _toggle_pause_menu() -> void:
	if not started:
		return

	if ui.is_menu_visible():
		_resume_game()
	else:
		_pause_game()


func _host_game() -> void:
	var error: Error = network.host()
	if error != OK:
		ui.set_status("Host failed: %s" % error)
		return

	_start_game()
	_spawn_player(multiplayer.get_unique_id())
	ui.set_status("Hosting %s on port %s. Share your address with friends." % [network.get_transport_name(), network.port])


func _join_game(ip_address: String) -> void:
	last_join_address = ip_address.strip_edges()
	if last_join_address == "":
		last_join_address = network.get_join_hint()

	var error: Error = network.join(last_join_address)
	if error != OK:
		_stop_connection_timer()
		ui.set_connecting(false)
		ui.set_status("Join failed: %s" % error)
		return

	_start_connection_timer()
	ui.set_connecting(true)
	ui.set_status("Connecting...")


func _reconnect_game() -> void:
	if multiplayer.has_multiplayer_peer():
		_close_network_locally()
	_clear_players()
	started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_join_game(last_join_address)


func _retry_after_end() -> void:
	if multiplayer.has_multiplayer_peer():
		_close_network_locally()
	ui.set_connecting(false)
	_reset_session()
	_start_game()


func _return_to_menu() -> void:
	if multiplayer.has_multiplayer_peer():
		_close_network_locally()
	_reset_session()
	started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.hide_death()
	ui.hide_victory()
	ui.show_menu()
	ui.set_connecting(false)
	ui.set_status("Ready.")


func _start_offline() -> void:
	ui.set_connecting(false)
	_reset_session()
	_start_game()
	_spawn_player(1)


func _start_dedicated_server() -> void:
	var error: Error = network.host_websocket()
	if error != OK:
		push_error("Dedicated server failed: %s" % error)
		get_tree().quit(1)
		return

	started = true
	ui.hide_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_log_server_event("started", {"transport": "WebSocket", "port": network.port})


func _start_game() -> void:
	if started:
		return

	started = true
	ui.hide_death()
	ui.hide_victory()
	ui.hide_menu()
	if OS.has_feature("web"):
		ui.show_pointer_hint()
	_capture_game_input(not OS.has_feature("web"))
	_show_level_banner()
	_update_hud()


func _pause_game() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.hide_pointer_hint()
	ui.show_menu()


func _resume_game() -> void:
	ui.hide_menu()
	if OS.has_feature("web"):
		ui.show_pointer_hint()
	_capture_game_input(not OS.has_feature("web"))


func _reset_session() -> void:
	if multiplayer.has_multiplayer_peer():
		network.close()

	started = false
	collected_notes = 0
	collected_note_ids.clear()
	session_collected_notes = 0
	_clear_players()
	_load_level_scene(LEVEL_SCENE)
	_update_hud()


func _clear_players() -> void:
	for child in players.get_children():
		players.remove_child(child)
		child.queue_free()


func _on_connected_to_server() -> void:
	_stop_connection_timer()
	ui.set_connecting(false)
	_start_game()
	_request_spawn.rpc_id(1, multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	_stop_connection_timer()
	ui.set_connecting(false)
	ui.set_status("Connection failed.")


func _on_server_disconnected() -> void:
	if Time.get_ticks_msec() < suppress_disconnect_until_msec:
		return

	_stop_connection_timer()
	started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_players()
	ui.show_menu()
	ui.set_connecting(false)
	ui.set_status("Server disconnected.")


func _close_network_locally() -> void:
	suppress_disconnect_until_msec = Time.get_ticks_msec() + 500
	network.close()


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	_log_server_event("peer_connected", {"peer_id": peer_id})
	_sync_session_state.rpc_id(
		peer_id,
		current_level_scene.resource_path,
		collected_note_ids,
		session_collected_notes,
		_is_level_exit_open(),
		_get_pressure_plate_states(),
		_get_monster_activation_states()
	)
	for player in players.get_children():
		var existing_id := int(player.name)
		_spawn_player_remote.rpc_id(peer_id, existing_id, player.global_position, player.player_color)
	_spawn_player(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_log_server_event("peer_disconnected", {"peer_id": peer_id})
	var node := players.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()
	_refresh_pressure_plates()


@rpc("any_peer", "call_remote", "reliable")
func _request_spawn(peer_id: int) -> void:
	if multiplayer.is_server():
		_log_server_event("spawn_requested", {"peer_id": peer_id, "sender": multiplayer.get_remote_sender_id()})
		_spawn_player(peer_id)


func _spawn_player(peer_id: int) -> void:
	if players.has_node(str(peer_id)):
		return

	var spawn_positions := _get_spawn_positions()
	var spawn_index := players.get_child_count() % spawn_positions.size()
	var color: Color = PLAYER_COLORS[spawn_index % PLAYER_COLORS.size()]
	if multiplayer.has_multiplayer_peer():
		_spawn_player_remote.rpc(peer_id, spawn_positions[spawn_index], color)
	_spawn_player_remote(peer_id, spawn_positions[spawn_index], color)


func _get_spawn_positions() -> Array:
	var marker_positions := _get_level_marker_positions("SpawnMarker")
	if not marker_positions.is_empty():
		return marker_positions
	if current_level_scene == CORRIDOR_SCENE:
		return [
			Vector3(0.0, 0.2, -26.0),
			Vector3(-0.8, 0.2, -26.0),
			Vector3(0.8, 0.2, -26.0),
		]
	if current_level_scene == FOURTH_ROOM_SCENE:
		return [
			Vector3(0.0, 0.2, 3.2),
			Vector3(-1.0, 0.2, 3.2),
			Vector3(1.0, 0.2, 3.2),
		]
	return SPAWNS


@rpc("authority", "call_remote", "reliable")
func _spawn_player_remote(peer_id: int, spawn_position: Vector3, color: Color) -> void:
	if players.has_node(str(peer_id)):
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.player_id = peer_id
	player.player_color = color
	player.position = spawn_position
	players.add_child(player)


func _on_note_collected(note_id: String, note_text: String) -> void:
	if not multiplayer.has_multiplayer_peer():
		_collect_note(note_id, note_text)
		return

	if multiplayer.is_server():
		_server_collect_note(note_id)
	else:
		_request_collect_note.rpc_id(1, note_id)


func _on_note_puzzle_requested(note_id: String, note_text: String, puzzle_type: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_note_puzzle(note_id, note_text, puzzle_type)


func _on_note_puzzle_completed(note_id: String, note_text: String) -> void:
	if started:
		_capture_game_input(not OS.has_feature("web"))
	_on_note_collected(note_id, note_text)


func _on_note_puzzle_cancelled(note_id: String) -> void:
	var note := _get_note_by_id(note_id)
	if note and note.has_method("reset_collection_attempt"):
		note.reset_collection_attempt()
	if started:
		_capture_game_input(not OS.has_feature("web"))


@rpc("any_peer", "call_remote", "reliable")
func _request_collect_note(note_id: String) -> void:
	if multiplayer.is_server():
		_server_collect_note(note_id)


func _server_collect_note(note_id: String) -> void:
	if collected_note_ids.has(note_id):
		_log_server_event("note_duplicate_ignored", {"note_id": note_id})
		return

	var note := _get_note_by_id(note_id)
	if not note:
		_log_server_event("note_missing_ignored", {"note_id": note_id})
		return

	var note_text := str(note.get("note_text"))
	_log_server_event("note_collected", {"note_id": note_id})
	_collect_note.rpc(note_id, note_text)
	_collect_note(note_id, note_text)


@rpc("authority", "call_remote", "reliable")
func _collect_note(note_id: String, note_text: String) -> void:
	if collected_note_ids.has(note_id):
		return

	var note := _get_note_by_id(note_id)
	if not note:
		return

	collected_note_ids.append(note_id)
	note.queue_free()
	collected_notes += 1
	session_collected_notes += 1
	if audio_cues.has_method("play_note_pickup"):
		audio_cues.play_note_pickup()
	_notify_monsters_note_progress()
	_update_hud(note_text)
	if collected_notes >= total_notes and total_notes > 0:
		_evaluate_level_exit_unlock()


func _open_level_exit() -> void:
	if _is_level_exit_open():
		return
	_set_level_exit_open(true)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_set_level_exit_open.rpc(true)


@rpc("authority", "call_remote", "reliable")
func _set_level_exit_open(is_open: bool) -> void:
	_apply_level_exit_state(is_open)
	if is_open:
		if audio_cues.has_method("play_exit_open"):
			audio_cues.play_exit_open()
		_update_objective()
		ui.set_status("The entrance is open.")
		return

	ui.set_status("All fragments are collected.")


func _on_level_exit_entered() -> void:
	if level_transitioning:
		return
	if current_level_scene == FOURTH_ROOM_SCENE:
		if not multiplayer.has_multiplayer_peer():
			_complete_game()
		elif multiplayer.is_server():
			_complete_game.rpc()
			_complete_game()
		else:
			_request_complete_game.rpc_id(1)
		return

	if not multiplayer.has_multiplayer_peer():
		_begin_next_level_transition()
		return

	if multiplayer.is_server():
		_begin_next_level_transition.rpc()
		_begin_next_level_transition()
	else:
		_request_next_level_transition.rpc_id(1)


func _on_pressure_plate_changed(_is_active: bool) -> void:
	if multiplayer.is_server():
		_log_server_event("pressure_plate_changed", {"active": _is_active})
	_evaluate_level_exit_unlock()


func _on_monster_activated() -> void:
	if multiplayer.is_server():
		_log_server_event("monster_activated")
	if network.is_dedicated_server():
		return
	if audio_cues.has_method("play_threat"):
		audio_cues.play_threat()
	ui.set_status("Something heard the fragment.")


func _evaluate_level_exit_unlock() -> void:
	if collected_notes < total_notes or total_notes <= 0:
		return
	if not _are_pressure_plates_satisfied():
		_update_objective()
		ui.set_status("The doorway needs the floor switch.")
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_open_level_exit()


@rpc("any_peer", "call_remote", "reliable")
func _request_next_level_transition() -> void:
	if not multiplayer.is_server():
		return
	if level_transitioning or not _is_level_exit_open():
		_log_server_event("level_transition_ignored", {"sender": multiplayer.get_remote_sender_id()})
		return

	_log_server_event("level_transition_requested", {"sender": multiplayer.get_remote_sender_id()})
	_begin_next_level_transition.rpc()
	_begin_next_level_transition()


@rpc("any_peer", "call_remote", "reliable")
func _request_complete_game() -> void:
	if not multiplayer.is_server():
		return
	if current_level_scene != FOURTH_ROOM_SCENE or not _is_level_exit_open():
		_log_server_event("victory_ignored", {"sender": multiplayer.get_remote_sender_id()})
		return

	_log_server_event("victory_requested", {"sender": multiplayer.get_remote_sender_id()})
	_complete_game.rpc()
	_complete_game()


@rpc("authority", "call_remote", "reliable")
func _begin_next_level_transition() -> void:
	if level_transitioning:
		return

	level_transitioning = true
	if multiplayer.is_server():
		_log_server_event("level_transition_started")
	_set_player_controls(false)
	call_deferred("_enter_next_level")


func _enter_next_level() -> void:
	collected_notes = 0
	collected_note_ids.clear()
	_load_level_scene(_get_next_level_scene())
	_move_current_players_to_spawns()
	level_transitioning = false
	if multiplayer.is_server():
		_log_server_event("level_loaded")
	ui.set_status("You entered the next place.")
	_update_objective()
	_update_hud("You entered the next place.")


func _get_next_level_scene() -> PackedScene:
	if current_level_scene == LEVEL_SCENE:
		return NEXT_PLACE_SCENE
	if current_level_scene == NEXT_PLACE_SCENE:
		return BACKROOMS_SCENE
	if current_level_scene == BACKROOMS_SCENE:
		return CORRIDOR_SCENE
	if current_level_scene == CORRIDOR_SCENE:
		return FOURTH_ROOM_SCENE
	return FOURTH_ROOM_SCENE


@rpc("authority", "call_remote", "reliable")
func _sync_session_state(
	level_path: String,
	synced_collected_note_ids: Array[String],
	synced_session_collected_notes := 0,
	synced_level_exit_open := false,
	synced_pressure_plate_states := {},
	synced_monster_activation_states := {}
) -> void:
	print("[client_event] session_sync level=%s collected_notes=%s exit_open=%s" % [level_path, synced_collected_note_ids.size(), synced_level_exit_open])
	var scene := _get_level_scene_by_path(level_path)
	if scene and scene != current_level_scene:
		collected_notes = 0
		collected_note_ids.clear()
		_load_level_scene(scene)

	collected_note_ids = synced_collected_note_ids.duplicate()
	session_collected_notes = int(synced_session_collected_notes)
	_apply_collected_note_state()
	_apply_pressure_plate_states(synced_pressure_plate_states)
	_apply_monster_activation_states(synced_monster_activation_states)
	_apply_level_exit_state(synced_level_exit_open)
	_update_hud()


func _on_player_killed(reason: String) -> void:
	started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for player in players.get_children():
		if player.has_method("set_controls_enabled"):
			player.set_controls_enabled(false)
	for monster in _get_level_monsters():
		if monster.has_method("stop_chase"):
			monster.stop_chase()
	ui.show_death(reason)


@rpc("authority", "call_remote", "reliable")
func _complete_game() -> void:
	started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_player_controls(false)
	ui.set_objective("")
	if audio_cues.has_method("play_victory"):
		audio_cues.play_victory()
	ui.show_victory(_get_victory_summary())


func _on_dialogue_npc_entered(npc: DialogueNpc) -> void:
	nearby_dialogue_npc = npc
	ui.set_extra_hint("Press Q to talk")
	_update_hud()


func _on_dialogue_npc_exited(npc: DialogueNpc) -> void:
	if nearby_dialogue_npc == npc:
		nearby_dialogue_npc = null
	if active_dialogue_npc == npc:
		_end_dialogue()
	_update_level_hint()
	_update_hud()


func _start_dialogue(npc: DialogueNpc) -> void:
	active_dialogue_pages = npc.get_dialogue_pages()
	if active_dialogue_pages.is_empty():
		return

	active_dialogue_npc = npc
	active_dialogue_index = 0
	_set_player_controls(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_current_dialogue_page()


func _advance_dialogue() -> void:
	active_dialogue_index += 1
	if active_dialogue_index >= active_dialogue_pages.size():
		_end_dialogue()
		return

	_show_current_dialogue_page()


func _show_current_dialogue_page() -> void:
	ui.show_dialogue(
		active_dialogue_npc.speaker_name,
		active_dialogue_pages[active_dialogue_index],
		active_dialogue_index,
		active_dialogue_pages.size()
	)


func _end_dialogue() -> void:
	ui.hide_dialogue()
	active_dialogue_npc = null
	active_dialogue_pages.clear()
	active_dialogue_index = 0
	_set_player_controls(true)
	if started:
		_capture_game_input(not OS.has_feature("web"))


func _set_player_controls(enabled: bool) -> void:
	for player in players.get_children():
		if player.has_method("set_controls_enabled"):
			player.set_controls_enabled(enabled)


func _capture_game_input(capture_mouse := true) -> void:
	get_viewport().gui_release_focus()
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		ui.hide_pointer_hint()


func _should_capture_game_input(event: InputEvent) -> bool:
	if not OS.has_feature("web"):
		return false
	if not started or ui.is_menu_visible():
		return false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return false
	return event is InputEventMouseButton and event.pressed


func _handle_debug_cycle_input(event: InputEvent) -> bool:
	if OS.has_feature("web") or network.is_dedicated_server():
		return false
	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	var key_event := event as InputEventKey
	if key_event.physical_keycode == KEY_F6:
		_adjust_day_night_cycle(0.5)
		return true
	if key_event.physical_keycode == KEY_F7:
		_adjust_day_night_cycle(2.0)
		return true
	return false


func _adjust_day_night_cycle(multiplier: float) -> void:
	if not day_night_cycle.has_method("get_cycle_length") or not day_night_cycle.has_method("set_cycle_length"):
		return

	var current_length := float(day_night_cycle.get_cycle_length())
	var next_length: float = clamp(current_length * multiplier, 10.0, 3600.0)
	day_night_cycle.set_cycle_length(next_length)
	ui.set_status("Day/night cycle length: %ss" % int(next_length))


func _spawn_current_players() -> void:
	if not multiplayer.has_multiplayer_peer():
		_spawn_player(1)
		return
	if not multiplayer.is_server():
		return

	if not network.is_dedicated_server():
		_spawn_player(multiplayer.get_unique_id())
	for peer_id in multiplayer.get_peers():
		_spawn_player(peer_id)


func _move_current_players_to_spawns() -> void:
	var spawn_positions := _get_spawn_positions()
	if not multiplayer.has_multiplayer_peer():
		_move_player_to_spawn(1, spawn_positions[0])
		return
	if not multiplayer.is_server():
		return

	var spawn_index := 0
	if not network.is_dedicated_server():
		_move_player_to_spawn(multiplayer.get_unique_id(), spawn_positions[spawn_index % spawn_positions.size()])
		spawn_index += 1
	for peer_id in multiplayer.get_peers():
		_move_player_to_spawn(peer_id, spawn_positions[spawn_index % spawn_positions.size()])
		spawn_index += 1


func _move_player_to_spawn(peer_id: int, spawn_position: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		_move_player_to_spawn_remote.rpc(peer_id, spawn_position)
	_move_player_to_spawn_remote(peer_id, spawn_position)


@rpc("authority", "call_remote", "reliable")
func _move_player_to_spawn_remote(peer_id: int, spawn_position: Vector3) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if not player:
		return

	player.global_position = spawn_position
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	if player.has_method("set_controls_enabled"):
		player.set_controls_enabled(true)


func _load_level_scene(scene: PackedScene) -> void:
	if level:
		remove_child(level)
		level.queue_free()

	level = scene.instantiate()
	current_level_scene = scene
	level.name = "Level"
	add_child(level)
	move_child(level, players.get_index())
	day_night_cycle.set_target_level(level)
	if audio_cues.has_method("play_ambience"):
		audio_cues.play_ambience(current_level_scene.resource_path)
	notes = level.get_node("Notes")
	level_exit = level.find_child("LevelExit", true, false) as Area3D
	_connect_level_interactables()
	_notify_monsters_note_progress()
	_update_level_hint()
	_update_objective()
	if started:
		_show_level_banner()


func _apply_collected_note_state() -> void:
	collected_notes = 0
	for note_id in collected_note_ids:
		var note := _get_note_by_id(note_id)
		if note:
			note.queue_free()
		collected_notes += 1
	if collected_notes >= total_notes and total_notes > 0:
		_evaluate_level_exit_unlock()
	_notify_monsters_note_progress()


func _apply_level_exit_state(is_open: bool) -> void:
	if not level_exit:
		return
	if is_open and level_exit.has_method("open"):
		level_exit.open()
	elif not is_open and level_exit.has_method("close"):
		level_exit.close()


func _get_level_scene_by_path(scene_path: String) -> PackedScene:
	match scene_path:
		LEVEL_SCENE.resource_path:
			return LEVEL_SCENE
		NEXT_PLACE_SCENE.resource_path:
			return NEXT_PLACE_SCENE
		BACKROOMS_SCENE.resource_path:
			return BACKROOMS_SCENE
		CORRIDOR_SCENE.resource_path:
			return CORRIDOR_SCENE
		FOURTH_ROOM_SCENE.resource_path:
			return FOURTH_ROOM_SCENE
		_:
			push_warning("Unknown level scene path in session sync: %s" % scene_path)
			return null


func _get_level_marker_positions(prefix: String) -> Array:
	var positions := []
	if not level:
		return positions

	for child in level.find_children("%s*" % prefix, "Marker3D", true, false):
		positions.append((child as Marker3D).global_position)
	return positions


func _get_level_notes() -> Array:
	var found_notes := []
	if not level:
		return found_notes
	for candidate in level.find_children("*", "Area3D", true, false):
		if candidate.has_signal("collected"):
			found_notes.append(candidate)
	return found_notes


func _get_level_monsters() -> Array:
	var found_monsters := []
	if not level:
		return found_monsters
	for candidate in level.find_children("*", "", true, false):
		if candidate.has_signal("killed_player") or candidate.has_method("stop_chase"):
			found_monsters.append(candidate)
	return found_monsters


func _get_level_pressure_plates() -> Array:
	var found_plates := []
	if not level:
		return found_plates
	for candidate in level.find_children("*", "Area3D", true, false):
		if candidate.has_signal("active_changed") and candidate.has_method("is_active"):
			found_plates.append(candidate)
	return found_plates


func _get_pressure_plate_states() -> Dictionary:
	var states := {}
	for plate in _get_level_pressure_plates():
		states[str(level.get_path_to(plate))] = bool(plate.call("is_active"))
	return states


func _apply_pressure_plate_states(states: Dictionary) -> void:
	for plate in _get_level_pressure_plates():
		var state_id := str(level.get_path_to(plate))
		if not states.has(state_id):
			continue
		if plate.has_method("set_latched_active"):
			plate.set_latched_active(bool(states[state_id]))


func _get_monster_activation_states() -> Dictionary:
	var states := {}
	for monster in _get_level_monsters():
		if monster.has_method("is_note_gated_activated"):
			states[str(level.get_path_to(monster))] = bool(monster.call("is_note_gated_activated"))
	return states


func _apply_monster_activation_states(states: Dictionary) -> void:
	for monster in _get_level_monsters():
		var state_id := str(level.get_path_to(monster))
		if not states.has(state_id):
			continue
		if monster.has_method("set_note_gated_activated"):
			monster.set_note_gated_activated(bool(states[state_id]))


func _notify_monsters_note_progress() -> void:
	for monster in _get_level_monsters():
		if monster.has_method("set_note_progress"):
			monster.set_note_progress(collected_notes, total_notes)


func _refresh_pressure_plates() -> void:
	for plate in _get_level_pressure_plates():
		if plate.has_method("refresh_state"):
			plate.refresh_state()


func _get_note_by_id(note_id: String) -> Node:
	if not level:
		return null
	for note in _get_level_notes():
		if note.name == note_id:
			return note
	return null


func _is_level_exit_open() -> bool:
	if not level_exit:
		return false
	return not bool(level_exit.get("closed"))


func _are_pressure_plates_satisfied() -> bool:
	var plates := _get_level_pressure_plates()
	if plates.is_empty():
		return true
	for plate in plates:
		if not bool(plate.call("is_active")):
			return false
	return true


func _update_level_hint() -> void:
	if current_level_scene == CORRIDOR_SCENE:
		ui.set_extra_hint("Press Shift to run")
	else:
		ui.set_extra_hint("")


func _update_hud(last_note := "") -> void:
	ui.update_hud(collected_notes, total_notes, last_note)


func _update_objective() -> void:
	if network.is_dedicated_server():
		return

	var objective := ""
	if current_level_scene == LEVEL_SCENE:
		objective = "Listen to the radio. Collect the three fragments and open the glowing doorway."
	elif current_level_scene == NEXT_PLACE_SCENE:
		if collected_notes >= total_notes and total_notes > 0 and not _are_pressure_plates_satisfied():
			objective = "Step on the floor switch to stabilize the copied doorway."
		else:
			objective = "Solve the fragment locks. Gather all seven warnings before the room copies you."
	elif current_level_scene == BACKROOMS_SCENE:
		objective = "Follow the yellow rooms. Find the marked exit before the lights settle."
	elif current_level_scene == CORRIDOR_SCENE:
		objective = "Run the corridor. Sprint only when you can afford to be heard."
	elif current_level_scene == FOURTH_ROOM_SCENE:
		objective = "Do not hold its gaze. Reach the final opening."

	if level_exit and _is_level_exit_open():
		if current_level_scene == FOURTH_ROOM_SCENE:
			objective = "Leave through the final opening."
		else:
			objective = "The doorway is open. Regroup and enter it."

	ui.set_objective(objective)


func _show_level_banner() -> void:
	if network.is_dedicated_server():
		return
	if ui.has_method("show_level_banner"):
		ui.show_level_banner(_get_level_title())


func _get_level_title() -> String:
	if current_level_scene == LEVEL_SCENE:
		return "Room 1: The Wrong Copy"
	if current_level_scene == NEXT_PLACE_SCENE:
		return "Room 2: The Copied Door"
	if current_level_scene == BACKROOMS_SCENE:
		return "Backrooms: Yellow Drift"
	if current_level_scene == CORRIDOR_SCENE:
		return "Corridor: Do Not Sprint"
	if current_level_scene == FOURTH_ROOM_SCENE:
		return "Final Room: Do Not Stare"
	return "Unknown Room"


func _get_victory_summary() -> String:
	return "You escaped after recovering %s fragments. The last room lets you leave, but it keeps the shape of your shadow." % session_collected_notes


func _log_server_event(event_name: String, data := {}) -> void:
	if not network.is_dedicated_server() and not multiplayer.is_server():
		return

	var parts := PackedStringArray()
	for key in data.keys():
		parts.append("%s=%s" % [str(key), str(data[key])])
	print("[server_event] %s version=%s level=%s notes=%s/%s %s" % [
		event_name,
		GameVersion.get_display_version(),
		current_level_scene.resource_path,
		collected_notes,
		total_notes,
		" ".join(parts),
	])
