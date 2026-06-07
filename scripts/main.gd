extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const LEVEL_SCENE := preload("res://scenes/level.tscn")
const NEXT_PLACE_SCENE := preload("res://scenes/next_place.tscn")
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

@onready var network: Node = $NetworkManager
@onready var level: Node3D = $Level
@onready var notes: Node3D = $Level/Notes
@onready var level_exit: Area3D = $Level/LevelExit
@onready var players: Node3D = $Players
@onready var ui: CanvasLayer = $Ui

var collected_notes := 0
var total_notes := 0
var started := false
var current_level_scene: PackedScene = LEVEL_SCENE
var nearby_dialogue_npc: DialogueNpc
var active_dialogue_npc: DialogueNpc
var active_dialogue_pages: Array[String] = []
var active_dialogue_index := 0


func _ready() -> void:
	_connect_network()
	_connect_ui()
	_connect_level_interactables()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
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
	ui.note_puzzle_completed.connect(_on_note_puzzle_completed)
	ui.note_puzzle_cancelled.connect(_on_note_puzzle_cancelled)


func _connect_level_interactables() -> void:
	_connect_notes()
	_connect_level_exit()
	_connect_monsters()
	_connect_dialogue_npcs()


func _connect_notes() -> void:
	total_notes = 0
	for note in notes.get_children():
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
	var monsters := level.get_node_or_null("Monsters")
	if not monsters:
		return
	for monster in monsters.get_children():
		if monster.has_signal("killed_player"):
			monster.killed_player.connect(_on_player_killed)


func _connect_dialogue_npcs() -> void:
	var dialogue_npcs := level.get_node_or_null("DialogueNpcs")
	if not dialogue_npcs:
		return
	for npc in dialogue_npcs.get_children():
		if npc.has_signal("player_entered"):
			npc.player_entered.connect(_on_dialogue_npc_entered)
		if npc.has_signal("player_exited"):
			npc.player_exited.connect(_on_dialogue_npc_exited)


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
	ui.set_status("Hosting on port %s. Share your IP with friends." % network.port)


func _join_game(ip_address: String) -> void:
	var error: Error = network.join(ip_address)
	if error != OK:
		ui.set_status("Join failed: %s" % error)
		return

	ui.set_status("Connecting...")


func _start_offline() -> void:
	_reset_session()
	_start_game()
	_spawn_player(1)


func _start_game() -> void:
	if started:
		return

	started = true
	ui.hide_death()
	ui.hide_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()


func _pause_game() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_menu()


func _resume_game() -> void:
	ui.hide_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _reset_session() -> void:
	if multiplayer.has_multiplayer_peer():
		network.close()

	started = false
	collected_notes = 0
	_clear_players()
	_load_level_scene(LEVEL_SCENE)
	_update_hud()


func _clear_players() -> void:
	for child in players.get_children():
		players.remove_child(child)
		child.queue_free()


func _on_connected_to_server() -> void:
	_start_game()
	_request_spawn.rpc_id(1, multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	ui.set_status("Connection failed.")


func _on_server_disconnected() -> void:
	started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_players()
	ui.show_menu()
	ui.set_status("Server disconnected.")


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	for player in players.get_children():
		var existing_id := int(player.name)
		_spawn_player_remote.rpc_id(peer_id, existing_id, player.global_position, player.player_color)
	_spawn_player(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var node := players.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()


@rpc("any_peer", "call_remote", "reliable")
func _request_spawn(peer_id: int) -> void:
	if multiplayer.is_server():
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
	if multiplayer.has_multiplayer_peer():
		_collect_note.rpc(note_id, note_text)
	_collect_note(note_id, note_text)


func _on_note_puzzle_requested(note_id: String, note_text: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_note_puzzle(note_id, note_text)


func _on_note_puzzle_completed(note_id: String, note_text: String) -> void:
	if started:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_on_note_collected(note_id, note_text)


func _on_note_puzzle_cancelled(note_id: String) -> void:
	var note := notes.get_node_or_null(note_id)
	if note and note.has_method("reset_collection_attempt"):
		note.reset_collection_attempt()
	if started:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


@rpc("any_peer", "call_remote", "reliable")
func _collect_note(note_id: String, note_text: String) -> void:
	var note := notes.get_node_or_null(note_id)
	if not note:
		return

	note.queue_free()
	collected_notes += 1
	_update_hud(note_text)
	if collected_notes >= total_notes and total_notes > 0:
		_open_level_exit()


func _open_level_exit() -> void:
	if level_exit and level_exit.has_method("open"):
		level_exit.open()
		ui.set_status("The entrance is open.")
		return

	ui.set_status("All fragments are collected.")


func _on_level_exit_entered() -> void:
	if multiplayer.has_multiplayer_peer():
		_enter_next_level.rpc()
	_enter_next_level()


@rpc("any_peer", "call_remote", "reliable")
func _enter_next_level() -> void:
	collected_notes = 0
	_clear_players()
	_load_level_scene(_get_next_level_scene())
	_spawn_current_players()
	ui.set_status("You entered the next place.")
	_update_hud("You entered the next place.")


func _get_next_level_scene() -> PackedScene:
	if current_level_scene == LEVEL_SCENE:
		return NEXT_PLACE_SCENE
	if current_level_scene == NEXT_PLACE_SCENE:
		return CORRIDOR_SCENE
	if current_level_scene == CORRIDOR_SCENE:
		return FOURTH_ROOM_SCENE
	return FOURTH_ROOM_SCENE


func _on_player_killed(reason: String) -> void:
	started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for player in players.get_children():
		if player.has_method("set_controls_enabled"):
			player.set_controls_enabled(false)
	var monsters := level.get_node_or_null("Monsters")
	if monsters:
		for monster in monsters.get_children():
			if monster.has_method("stop_chase"):
				monster.stop_chase()
	ui.show_death(reason)


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
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_player_controls(enabled: bool) -> void:
	for player in players.get_children():
		if player.has_method("set_controls_enabled"):
			player.set_controls_enabled(enabled)


func _spawn_current_players() -> void:
	if not multiplayer.has_multiplayer_peer():
		_spawn_player(1)
		return
	if not multiplayer.is_server():
		return

	_spawn_player(multiplayer.get_unique_id())
	for peer_id in multiplayer.get_peers():
		_spawn_player(peer_id)


func _load_level_scene(scene: PackedScene) -> void:
	if level:
		remove_child(level)
		level.queue_free()

	level = scene.instantiate()
	current_level_scene = scene
	level.name = "Level"
	add_child(level)
	move_child(level, players.get_index())
	notes = level.get_node("Notes")
	level_exit = level.get_node_or_null("LevelExit")
	_connect_level_interactables()
	_update_level_hint()


func _update_level_hint() -> void:
	if current_level_scene == CORRIDOR_SCENE:
		ui.set_extra_hint("Press Shift to run")
	else:
		ui.set_extra_hint("")


func _update_hud(last_note := "") -> void:
	ui.update_hud(collected_notes, total_notes, last_note)
