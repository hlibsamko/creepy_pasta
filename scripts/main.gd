extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const LEVEL_SCENE := preload("res://scenes/level.tscn")
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
@onready var players: Node3D = $Players
@onready var ui: CanvasLayer = $Ui

var collected_notes := 0
var total_notes := 0
var started := false


func _ready() -> void:
	_connect_network()
	_connect_ui()
	_connect_notes()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
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


func _connect_notes() -> void:
	total_notes = 0
	for note in notes.get_children():
		if not note.has_signal("collected"):
			continue
		total_notes += 1
		note.collected.connect(_on_note_collected)


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
	_reload_level()
	_update_hud()


func _clear_players() -> void:
	for child in players.get_children():
		players.remove_child(child)
		child.queue_free()


func _reload_level() -> void:
	if level:
		remove_child(level)
		level.queue_free()

	level = LEVEL_SCENE.instantiate()
	level.name = "Level"
	add_child(level)
	move_child(level, players.get_index())
	notes = level.get_node("Notes")
	_connect_notes()


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

	var spawn_index := players.get_child_count() % SPAWNS.size()
	var color: Color = PLAYER_COLORS[spawn_index % PLAYER_COLORS.size()]
	if multiplayer.has_multiplayer_peer():
		_spawn_player_remote.rpc(peer_id, SPAWNS[spawn_index], color)
	_spawn_player_remote(peer_id, SPAWNS[spawn_index], color)


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


@rpc("any_peer", "call_remote", "reliable")
func _collect_note(note_id: String, note_text: String) -> void:
	var note := notes.get_node_or_null(note_id)
	if not note:
		return

	note.queue_free()
	collected_notes += 1
	_update_hud(note_text)


func _update_hud(last_note := "") -> void:
	ui.update_hud(collected_notes, total_notes, last_note)
