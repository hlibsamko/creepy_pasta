extends Node3D

#region Scene resources and authoritative session contracts

const LEVEL_RUNTIME_QUERY := preload("res://scripts/level_runtime_query.gd")
const ACCOUNT_GAME_BRIDGE := preload("res://scripts/account_game_bridge.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const LEVEL_SCENE := preload("res://scenes/level.tscn")
const NEXT_PLACE_SCENE := preload("res://scenes/next_place.tscn")
const BACKROOMS_SCENE := preload("res://scenes/backrooms/backrooms_builder_demo.tscn")
const HOUSE_BUILDER_DEMO_SCENE := preload("res://scenes/endless_house/endless_house_builder_demo.tscn")
const UNLIT_EVIDENCE_DEMO_SCENE := preload("res://scenes/endless_house/unlit_evidence_demo.tscn")
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
const MAX_ONLINE_SESSIONS := 8
const SESSION_RECONNECT_GRACE_MSEC := 90000
const SERVER_MONSTER_SYNC_INTERVAL := 0.1
const ACCOUNT_AUTH_TIMEOUT_MSEC := 10000
const ACCOUNT_HEARTBEAT_INTERVAL := 60.0
const SESSION_LEVEL_PATHS := [
	"res://scenes/level.tscn",
	"res://scenes/next_place.tscn",
	"res://scenes/backrooms/backrooms_builder_demo.tscn",
	"res://scenes/endless_house/endless_house_builder_demo.tscn",
	"res://scenes/endless_house/unlit_evidence_demo.tscn",
	"res://scenes/corridor.tscn",
	"res://scenes/fourth_room.tscn",
]
const SESSION_EXIT_DEFINITIONS := {
	"res://scenes/level.tscn": {
		"position": Vector3(0.0, 1.15, 5.35),
		"activation_radius": 2.0,
	},
	"res://scenes/next_place.tscn": {
		"position": Vector3(0.0, 1.15, -4.55),
		"activation_radius": 2.0,
	},
	"res://scenes/backrooms/backrooms_builder_demo.tscn": {
		"position": Vector3(36.0, 1.15, 28.0),
		"activation_radius": 2.0,
	},
	"res://scenes/endless_house/endless_house_builder_demo.tscn": {
		"position": Vector3(40.0, 1.15, 4.0),
		"activation_radius": 2.0,
	},
	"res://scenes/endless_house/unlit_evidence_demo.tscn": {
		"position": Vector3(36.0, 1.15, 4.0),
		"activation_radius": 2.0,
	},
	"res://scenes/corridor.tscn": {
		"position": Vector3(0.0, 1.15, 34.5),
		"activation_radius": 2.0,
	},
	"res://scenes/fourth_room.tscn": {
		"position": Vector3(0.0, 1.15, -4.55),
		"activation_radius": 2.0,
	},
}
const SESSION_NOTE_DEFINITIONS := {
	"res://scenes/level.tscn": {
		"Note1": {
			"text": "Torn maintenance log: fast footsteps wake it; the runner becomes its clearest target.",
			"position": Vector3(-4.9, 0.55, -1.8),
			"collection_radius": 1.75,
		},
		"Note2": {
			"text": "Route sketch: overturned furniture and closed routes can make it search elsewhere.",
			"position": Vector3(4.8, 0.55, 1.1),
			"collection_radius": 1.75,
		},
	},
	"res://scenes/next_place.tscn": {
		"Fragment1": {
			"text": "Survey plate: fixed points show the room copied its own floor plan before the doorway appeared.",
			"entry_id": "mimic",
			"rumor_id": "replicated_room",
			"position": Vector3(-5.6, 0.55, 3.8),
			"collection_radius": 1.75,
		},
		"Fragment3": {
			"text": "Voice record: do not answer a doorway that speaks with a familiar voice.",
			"entry_id": "mimic",
			"fact_index": 1,
			"position": Vector3(0.0, 0.55, 3.4),
			"collection_radius": 1.75,
		},
	},
	"res://scenes/backrooms/backrooms_builder_demo.tscn": {
		"GeneratedNote1": {
			"text": "Survey plate: chalk reference points stayed fixed while the corridor around them changed.",
			"entry_id": "house",
			"fact_index": 1,
			"position": Vector3(16.0, 0.55, 4.0),
			"collection_radius": 1.75,
		},
		"GeneratedNote3": {
			"text": "Maintenance index: room labels count downward and restart at zero, as if every copy is catalogued.",
			"entry_id": "house",
			"fact_index": 2,
			"position": Vector3(24.0, 0.55, 20.0),
			"collection_radius": 1.75,
		},
	},
	"res://scenes/endless_house/endless_house_builder_demo.tscn": {
		"GeneratedNote1": {
			"text": "Survey record: real openings move floor dust. The copy matches every measurement, but has no draft or room tone.",
			"entry_id": "house",
			"fact_index": 3,
			"position": Vector3(4.0, 0.55, 12.0),
			"collection_radius": 1.75,
		},
	},
	"res://scenes/endless_house/unlit_evidence_demo.tscn": {
		"GeneratedNote1": {
			"text": "Maintenance test: the silhouette stayed inside the same chalk mark only while the work lamp faced it.",
			"entry_id": "unlit",
			"fact_index": 1,
			"position": Vector3(12.0, 0.55, 4.0),
			"collection_radius": 1.75,
		},
	},
	"res://scenes/corridor.tscn": {},
	"res://scenes/fourth_room.tscn": {
		"WatcherWarning": {
			"text": "It only moves inside your attention. Look away before it learns your face.",
			"entry_id": "watcher",
			"fact_index": 1,
			"position": Vector3(2.8, 0.55, 2.8),
			"collection_radius": 1.75,
		},
		"MimicWarning": {
			"text": "Door test: a true opening keeps a steady glow. The copy answers with two close pulses.",
			"entry_id": "mimic",
			"fact_index": 3,
			"position": Vector3(-2.8, 0.55, 2.65),
			"collection_radius": 1.75,
		},
	},
}
const SESSION_PRESSURE_REQUIREMENTS := {
	"res://scenes/next_place.tscn": 1,
	"res://scenes/backrooms/backrooms_builder_demo.tscn": 1,
}
const SESSION_BREAKER_REQUIREMENTS := {
	"res://scenes/endless_house/unlit_evidence_demo.tscn": 1,
}
const SESSION_PRESSURE_PLATE_DEFINITIONS := {
	"res://scenes/next_place.tscn": {
		"PressurePlate": {
			"position": Vector3(0.0, 0.03, -2.55),
			"activation_radius": 1.5,
		},
	},
	"res://scenes/backrooms/backrooms_builder_demo.tscn": {
		"BackroomsBuilder/GeneratedBackrooms/Mechanics/PressurePlate": {
			"position": Vector3(32.0, 0.03, 24.0),
			"activation_radius": 1.5,
		},
	},
	"res://scenes/endless_house/unlit_evidence_demo.tscn": {
		"EndlessHouseBuilder/GeneratedBackrooms/Mechanics/PressurePlate": {
			"position": Vector3(4.0, 0.03, 20.0),
			"activation_radius": 1.5,
		},
	},
}
const SESSION_BREAKER_DEFINITIONS := {
	"res://scenes/endless_house/unlit_evidence_demo.tscn": {
		"EndlessHouseBuilder/GeneratedBackrooms/Mechanics/GeneratedBreakerTrigger1": {
			"position": Vector3(36.0, 0.0, 20.0),
			"activation_radius": 2.0,
			"work_light_id": "EndlessHouseBuilder/GeneratedBackrooms/Mechanics/GeneratedWorkLight1",
			"outage_duration": 3.2,
			"entry_id": "unlit",
			"fact_index": 3,
			"message": "The work light died. Keep your own beam on the silhouette.",
		},
	},
}
const SESSION_MONSTER_DEFINITIONS := {
	"res://scenes/endless_house/unlit_evidence_demo.tscn": {
		"EndlessHouseBuilder/GeneratedBackrooms/Monsters/GeneratedLightShyMonster1": {
			"spawn_position": Vector3(24.0, 0.0, 20.0),
			"move_speed": 2.2,
			"kill_radius": 1.0,
			"death_reason": "Something from the unlit hall reached you",
			"cell_size": 4.0,
			"layout": "############\n#S.D.L..#E.#\n#.#.###.#..#\n#.#...#.#..#\n#.###.#.##.#\n#R.L.LU.LT.#\n############",
			"flashlight_range": 18.0,
			"flashlight_angle": 34.0,
			"beam_edge_margin_degrees": 2.0,
			"journal_entry_id": "unlit",
			"journal_fact_index_on_observation": 2,
			"work_lights": [
				{
					"source_id": "EndlessHouseBuilder/GeneratedBackrooms/Mechanics/GeneratedWorkLight1",
					"power_source_id": "EndlessHouseBuilder/GeneratedBackrooms/Mechanics/PressurePlate",
					"position": Vector3(4.0, 2.65, 20.0),
					"aim_position": Vector3(24.0, 0.55, 20.0),
					"range": 24.0,
					"angle": 32.0,
				},
			],
		},
	},
}
const SESSION_CLIENT_DISCOVERIES := {
	"res://scenes/level.tscn": [
		{
			"source_id": "DialogueNpcs/EntryRadio",
			"unlock": false,
			"entry_id": "listener",
			"fact_index": 0,
			"rumor_id": "light_barrier",
			"position": Vector3(-2.65, 0.55, -4.7),
			"interaction_radius": 2.4,
		},
	],
	"res://scenes/next_place.tscn": [
		{
			"source_id": "DialogueNpcs/Mara",
			"unlock": true,
			"entry_id": "listener",
			"fact_index": 1,
			"rumor_id": "",
			"position": Vector3(-4.35, 0.0, -2.9),
			"interaction_radius": 2.2,
		},
	],
	"res://scenes/backrooms/backrooms_builder_demo.tscn": [
		{
			"source_id": "BackroomsBuilder/GeneratedBackrooms/Monsters/GeneratedWatcher1",
			"unlock": false,
			"entry_id": "watcher",
			"fact_index": 2,
			"rumor_id": "",
			"position": Vector3(12.0, 1.1, 28.0),
			"observation_radius": 10.8,
			"facing_dot_min": 0.9,
		},
		{
			"source_id": "DialogueNpcs/Elias",
			"unlock": false,
			"entry_id": "mimic",
			"fact_index": 0,
			"rumor_id": "double_pulse_safe",
			"position": Vector3(4.0, 0.0, 24.0),
			"interaction_radius": 2.2,
		},
	],
	"res://scenes/endless_house/endless_house_builder_demo.tscn": [
		{
			"source_id": "EndlessHouseBuilder/GeneratedBackrooms/Monsters/GeneratedMimicDoor1",
			"unlock": false,
			"entry_id": "mimic",
			"fact_index": 2,
			"rumor_id": "",
			"position": Vector3(36.0, 1.15, 20.0),
			"observation_radius": 3.8,
		},
	],
	"res://scenes/endless_house/unlit_evidence_demo.tscn": [
		{
			"source_id": "EndlessHouseBuilder/GeneratedBackrooms/Monsters/GeneratedLightShyMonster1",
			"unlock": false,
			"entry_id": "unlit",
			"fact_index": 2,
			"rumor_id": "",
			"position": Vector3(24.0, 0.0, 20.0),
			"observation_radius": 21.0,
		},
	],
	"res://scenes/corridor.tscn": [],
	"res://scenes/fourth_room.tscn": [
		{
			"source_id": "Monsters/WatcherMonster",
			"unlock": false,
			"entry_id": "watcher",
			"fact_index": 2,
			"rumor_id": "",
			"position": Vector3(-3.0, 1.1, -2.7),
			"observation_radius": 10.8,
			"facing_dot_min": 0.9,
		},
		{
			"source_id": "DialogueNpcs/FinalIntercom",
			"unlock": false,
			"entry_id": "watcher",
			"fact_index": 3,
			"rumor_id": "",
			"position": Vector3(-1.9, 0.72, -3.95),
			"interaction_radius": 2.3,
		},
		{
			"source_id": "DialogueNpcs/ThresholdTest",
			"unlock": false,
			"entry_id": "mimic",
			"fact_index": 2,
			"rumor_id": "",
			"position": Vector3(3.35, 0.85, 0.35),
			"interaction_radius": 2.0,
		},
	],
}
const SESSION_NOTE_GATED_MONSTERS := {
	"res://scenes/level.tscn": [
		{
			"source_id": "Monsters/OpeningListener",
			"notes_required": 1,
			"entry_id": "listener",
			"fact_index": 2,
		},
	],
	"res://scenes/next_place.tscn": [],
	"res://scenes/backrooms/backrooms_builder_demo.tscn": [
		{
			"source_id": "BackroomsBuilder/GeneratedBackrooms/Monsters/GeneratedChaser1",
			"notes_required": 1,
			"entry_id": "listener",
			"fact_index": 2,
		},
		{
			"source_id": "BackroomsBuilder/GeneratedBackrooms/Monsters/GeneratedAmbushChaser2",
			"notes_required": 2,
			"entry_id": "listener",
			"fact_index": 2,
		},
	],
	"res://scenes/endless_house/endless_house_builder_demo.tscn": [],
	"res://scenes/endless_house/unlit_evidence_demo.tscn": [],
	"res://scenes/corridor.tscn": [],
	"res://scenes/fourth_room.tscn": [],
}

#endregion

#region Runtime node references and state

@onready var network: Node = $NetworkManager
@onready var day_night_cycle: Node = $DayNightCycle
@onready var audio_cues: Node = $AudioCues
@onready var monster_journal: Node = $MonsterJournal
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
var monster_activation_feedback_timer: Timer
var pending_activation_monster: Node
var suppress_disconnect_until_msec := 0
var reset_session_on_connect := false
var online_sessions := {}
var peer_session_ids := {}
var peer_account_ids := {}
var peer_account_profiles := {}
var peer_play_session_ids := {}
var peer_account_event_sequences := {}
var peer_auth_deadlines_msec := {}
var peer_auth_in_progress := {}
var active_session_id := ""
var loaded_session_id := ""
var last_online_session_id := ""
var pending_reconnect_session_id := ""
var next_session_number := 1
var debug_preview_session_collected_notes := 0
var server_monster_sync_accumulator := 0.0
var account_heartbeat_accumulator := 0.0
var pending_game_ticket := ""
var game_account_authenticated := false
var account_game_bridge
var last_death_was_server_authoritative := false
var last_death_reason := ""
var last_recovered_record_text := ""
var qa_invulnerable := true
var qa_noclip := false
var qa_speed_multiplier := 1.0
var qa_monsters_paused := false
var qa_diagnostics_timer: Timer
var qa_monster_process_modes := {}


#endregion

#region Lifecycle and scene wiring

func _ready() -> void:
	account_game_bridge = ACCOUNT_GAME_BRIDGE.new()
	account_game_bridge.name = "AccountGameBridge"
	add_child(account_game_bridge)
	_setup_connection_timer()
	_setup_monster_activation_feedback_timer()
	if network.is_dedicated_server():
		day_night_cycle.set_enabled(false)
	else:
		day_night_cycle.set_target_level(level)
	_connect_network()
	_connect_ui()
	_connect_level_interactables()
	_setup_qa_mode()
	ui.set_join_address(network.get_join_hint())
	ui.set_status("The house remembers every connection. Choose how you enter.")
	last_join_address = network.get_join_hint()
	if network.is_dedicated_server():
		_start_dedicated_server()
		return
	_update_objective()
	_update_hud()


func _physics_process(delta: float) -> void:
	if not _is_network_server():
		return
	_prune_unauthenticated_peers()
	_step_account_heartbeats(delta)
	_prune_expired_online_sessions()
	if online_sessions.is_empty():
		return
	server_monster_sync_accumulator += maxf(delta, 0.0)
	var should_broadcast := server_monster_sync_accumulator >= SERVER_MONSTER_SYNC_INTERVAL
	if should_broadcast:
		server_monster_sync_accumulator = fmod(
			server_monster_sync_accumulator,
			SERVER_MONSTER_SYNC_INTERVAL
		)
	var now_msec := Time.get_ticks_msec()
	for session_id in online_sessions:
		var state: Dictionary = online_sessions[session_id]
		if (state.get("members", []) as Array).is_empty():
			continue
		if not _server_step_online_monsters(state, delta, now_msec):
			continue
		if should_broadcast:
			_broadcast_online_monster_states(state)


func _unhandled_input(event: InputEvent) -> void:
	if _handle_qa_menu_input(event):
		return
	if _should_capture_game_input(event):
		_set_player_controls(true)
		_capture_game_input()
		return
	if _should_recover_game_input(event):
		_set_player_controls(true)

	if _handle_debug_unlit_preview_input(event):
		return
	if _handle_debug_house_preview_input(event):
		return
	if _handle_debug_branch_preview_input(event):
		return
	if _handle_debug_cycle_input(event):
		return

	if ui.is_journal_visible():
		if event.is_action_pressed("journal") or event.is_action_pressed("ui_cancel"):
			_close_journal()
		return
	if event.is_action_pressed("journal"):
		_toggle_journal()
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
	ui.reset_session_requested.connect(_reset_online_session)
	ui.create_session_requested.connect(_request_create_online_session)
	ui.join_session_requested.connect(_request_join_online_session)
	ui.refresh_sessions_requested.connect(_request_online_session_list)
	ui.branch_browser_requested.connect(_show_branch_browser)
	ui.branch_requested.connect(_start_offline_branch)
	ui.journal_requested.connect(_toggle_journal)
	ui.journal_closed.connect(_close_journal)
	ui.retry_requested.connect(_retry_after_end)
	ui.main_menu_requested.connect(_return_to_menu)
	ui.note_puzzle_completed.connect(_on_note_puzzle_completed)
	ui.note_puzzle_cancelled.connect(_on_note_puzzle_cancelled)
	ui.qa_panel_open_changed.connect(_on_qa_panel_open_changed)
	ui.qa_level_requested.connect(_qa_load_level)
	ui.qa_invulnerable_changed.connect(_qa_set_invulnerable)
	ui.qa_noclip_changed.connect(_qa_set_noclip)
	ui.qa_speed_changed.connect(_qa_set_speed)
	ui.qa_monsters_paused_changed.connect(_qa_set_monsters_paused)
	ui.qa_reload_requested.connect(_qa_reload_level)
	ui.qa_teleport_spawn_requested.connect(_qa_teleport_to_spawn)
	ui.qa_teleport_exit_requested.connect(_qa_teleport_to_exit)
	ui.qa_open_exit_requested.connect(_qa_open_exit)
	ui.qa_complete_objectives_requested.connect(_qa_complete_objectives)


func _connect_level_interactables() -> void:
	_connect_notes()
	_connect_level_exit()
	_connect_monsters()
	_connect_environmental_evidence()
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
			monster.killed_player.connect(_on_player_killed.bind(monster))
		if monster.has_signal("activated"):
			monster.activated.connect(_on_monster_activated.bind(monster))
		if monster.has_signal("observed"):
			monster.observed.connect(_on_monster_observed.bind(monster))
		if monster.has_signal("gaze_warning"):
			monster.gaze_warning.connect(_on_watcher_gaze_warning)
		if monster.has_signal("gaze_cleared"):
			monster.gaze_cleared.connect(_on_watcher_gaze_cleared)


func _connect_environmental_evidence() -> void:
	if not level:
		return
	for source in level.find_children("*", "", true, false):
		if source.has_signal("evidence_observed"):
			source.evidence_observed.connect(_on_environmental_evidence_observed.bind(source))
		if source.has_signal("outage_changed"):
			source.outage_changed.connect(_on_environmental_outage_changed)
		if source.has_signal("outage_requested"):
			source.outage_requested.connect(_on_breaker_outage_requested.bind(source))
			if source.has_method("set_authoritative_mode"):
				source.call(
					"set_authoritative_mode",
					multiplayer.has_multiplayer_peer() and not _is_network_server()
				)


func _connect_pressure_plates() -> void:
	for plate in _get_level_pressure_plates():
		if plate.has_signal("active_changed"):
			plate.active_changed.connect(_on_pressure_plate_changed.bind(plate))


func _connect_dialogue_npcs() -> void:
	var dialogue_npcs := level.get_node_or_null("DialogueNpcs")
	if not dialogue_npcs:
		return
	for npc in dialogue_npcs.get_children():
		if npc.has_signal("player_entered"):
			npc.player_entered.connect(_on_dialogue_npc_entered)
		if npc.has_signal("player_exited"):
			npc.player_exited.connect(_on_dialogue_npc_exited)


#endregion

#region Connection and game-session lifecycle

func _setup_connection_timer() -> void:
	connection_timer = Timer.new()
	connection_timer.one_shot = true
	connection_timer.wait_time = CONNECTION_TIMEOUT_SECONDS
	connection_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timer)


func _setup_monster_activation_feedback_timer() -> void:
	monster_activation_feedback_timer = Timer.new()
	monster_activation_feedback_timer.one_shot = true
	monster_activation_feedback_timer.wait_time = 1.2
	monster_activation_feedback_timer.timeout.connect(_show_monster_activation_feedback)
	add_child(monster_activation_feedback_timer)


func _start_connection_timer() -> void:
	connection_timer.start()


func _stop_connection_timer() -> void:
	if connection_timer and not connection_timer.is_stopped():
		connection_timer.stop()


func _on_connection_timeout() -> void:
	_close_network_locally()
	reset_session_on_connect = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.set_connection_visual_active(true)
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
	game_account_authenticated = false
	var uses_debug_smoke_ticket := OS.is_debug_build() and pending_game_ticket.begins_with("smoke-")
	if not uses_debug_smoke_ticket:
		var account_service := get_node_or_null("/root/AccountService")
		if not account_service or not account_service.has_method("is_authenticated"):
			ui.set_connecting(false)
			ui.set_status("Account service is unavailable. Sign in before playing online.")
			return
		if not bool(account_service.call("is_authenticated")):
			ui.set_connecting(false)
			ui.set_status("Sign in with Google before playing online.")
			return
		ui.set_connecting(true)
		ui.set_status("Preparing a secure game session...")
		var ticket_result: Dictionary = await account_service.call("create_game_ticket")
		if not bool(ticket_result.get("ok", false)):
			ui.set_connecting(false)
			ui.set_status(str(ticket_result.get("error", "Could not create a game ticket.")))
			return
		pending_game_ticket = str(ticket_result.get("ticket", ""))
		if pending_game_ticket == "":
			ui.set_connecting(false)
			ui.set_status("The account service returned an empty game ticket.")
			return

	last_join_address = ip_address.strip_edges()
	if last_join_address == "":
		last_join_address = network.get_join_hint()

	var error: Error = network.join(last_join_address)
	if error != OK:
		_stop_connection_timer()
		reset_session_on_connect = false
		ui.set_connecting(false)
		ui.set_status("Join failed: %s" % error)
		return

	_start_connection_timer()
	ui.set_connecting(true)
	ui.set_status("Connecting...")


func _reconnect_game() -> void:
	if active_session_id != "":
		last_online_session_id = active_session_id
	pending_reconnect_session_id = last_online_session_id
	if multiplayer.has_multiplayer_peer():
		_close_network_locally()
		await get_tree().create_timer(0.1).timeout
	_clear_players()
	started = false
	active_session_id = ""
	loaded_session_id = ""
	_update_session_status()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_join_game(last_join_address)
	if pending_reconnect_session_id != "" and multiplayer.has_multiplayer_peer():
		ui.set_status("Reconnecting to %s..." % pending_reconnect_session_id)


func _request_online_session_list() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	ui.set_connecting(true)
	ui.set_status("Refreshing sessions...")
	_server_request_online_session_list.rpc_id(1)


func _request_create_online_session() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	ui.set_connecting(true)
	ui.set_status("Creating a clean session...")
	_server_create_online_session.rpc_id(1)


func _request_join_online_session(session_id: String) -> void:
	if not multiplayer.has_multiplayer_peer() or session_id == "":
		return
	ui.set_connecting(true)
	ui.set_status("Joining %s..." % session_id)
	_server_join_online_session.rpc_id(1, session_id)


func _reset_online_session(ip_address: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		ui.hide_menu()
		ui.set_status("Resetting online session...")
		_request_session_reset.rpc_id(1)
		return

	reset_session_on_connect = true
	_join_game(ip_address)


func _retry_after_end() -> void:
	ui.set_connecting(false)
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var restarting_completed_run: bool = bool(ui.is_victory_visible())
		ui.hide_death()
		ui.hide_victory()
		if restarting_completed_run:
			ui.set_status("Resetting the completed online session...")
			_request_session_reset.rpc_id(1)
		else:
			ui.set_status("Returning to the current online session...")
			_request_respawn.rpc_id(1)
		return
	_reset_session()
	_start_game()
	_spawn_player(1)


func _return_to_menu() -> void:
	if multiplayer.has_multiplayer_peer():
		_close_network_locally()
	_reset_session()
	started = false
	active_session_id = ""
	loaded_session_id = ""
	last_online_session_id = ""
	pending_reconnect_session_id = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.hide_death()
	ui.hide_victory()
	ui.set_connection_visual_active(true)
	ui.show_menu()
	if audio_cues.has_method("stop_ambience"):
		audio_cues.stop_ambience()
	ui.prepare_connection_menu()
	ui.set_connecting(false)
	ui.set_status("Ready.")


func _start_offline() -> void:
	ui.set_connecting(false)
	last_online_session_id = ""
	pending_reconnect_session_id = ""
	_reset_session()
	_start_game()
	_spawn_player(1)


func _show_branch_browser() -> void:
	if multiplayer.has_multiplayer_peer():
		ui.set_status("Leave the online session before opening a local study.")
		return
	ui.show_branch_browser(BranchCatalog.ALL)


func _start_offline_branch(branch_id: String) -> void:
	var branch := BranchCatalog.find_by_id(branch_id)
	if branch == null or not branch.is_valid():
		ui.set_status("That environment study is unavailable.")
		return
	ui.set_connecting(false)
	last_online_session_id = ""
	pending_reconnect_session_id = ""
	_reset_session()
	_load_level_scene(branch.scene)
	_start_game()
	_spawn_player(1)
	ui.set_status(branch.arrival_status)


func _start_dedicated_server() -> void:
	if not _is_account_auth_test_mode() and not account_game_bridge.is_configured():
		push_error(
			"Dedicated server refused to start without CREEPY_ACCOUNT_INTERNAL_SECRET."
		)
		get_tree().quit(1)
		return
	# Production traffic reaches this listener through Caddy (HTTPS/WSS). Keeping
	# it on loopback prevents clients from bypassing the TLS/authenticated edge.
	var error: Error = network.host_websocket("127.0.0.1")
	if error != OK:
		push_error("Dedicated server failed: %s" % error)
		get_tree().quit(1)
		return

	started = true
	ui.set_connection_visual_active(false)
	ui.hide_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_log_server_event("started", {"transport": "WebSocket", "port": network.port})


func _start_game() -> void:
	if started:
		return

	started = true
	ui.set_connection_visual_active(false)
	ui.hide_death()
	ui.hide_victory()
	ui.hide_menu()
	if audio_cues.has_method("play_ambience"):
		audio_cues.play_ambience(current_level_scene.resource_path)
	if OS.has_feature("web"):
		ui.show_pointer_hint()
	_capture_game_input(not OS.has_feature("web"))
	_show_level_banner()
	_update_hud()
	if ui.is_qa_menu_open():
		call_deferred("_on_qa_panel_open_changed", true)


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
	debug_preview_session_collected_notes = 0
	monster_journal.reset()
	ui.set_journal_available(false)
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
	if pending_game_ticket != "":
		ui.set_connecting(true)
		ui.set_status("Authenticating game account...")
		_server_authenticate_game_ticket.rpc_id(1, pending_game_ticket)
		pending_game_ticket = ""
		return
	ui.set_status("Waiting for game account authentication...")


func _continue_after_game_authentication() -> void:
	if reset_session_on_connect:
		reset_session_on_connect = false
	started = false
	active_session_id = ""
	loaded_session_id = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.set_connection_visual_active(true)
	ui.show_menu()
	ui.prepare_connection_menu()
	if pending_reconnect_session_id != "":
		ui.set_connecting(true)
		ui.set_status("Rejoining %s..." % pending_reconnect_session_id)
		_server_join_online_session.rpc_id(1, pending_reconnect_session_id)
		return
	ui.set_status("Loading active sessions...")
	_server_request_online_session_list.rpc_id(1)


func _on_connection_failed() -> void:
	_stop_connection_timer()
	pending_game_ticket = ""
	game_account_authenticated = false
	reset_session_on_connect = false
	ui.set_connecting(false)
	ui.set_status("Connection failed.")


func _on_server_disconnected() -> void:
	if Time.get_ticks_msec() < suppress_disconnect_until_msec:
		return

	_stop_connection_timer()
	pending_game_ticket = ""
	game_account_authenticated = false
	reset_session_on_connect = false
	if active_session_id != "":
		last_online_session_id = active_session_id
	pending_reconnect_session_id = last_online_session_id
	active_session_id = ""
	loaded_session_id = ""
	_update_session_status()
	started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_players()
	ui.set_connection_visual_active(true)
	ui.show_menu()
	ui.prepare_connection_menu()
	ui.set_connecting(false)
	ui.set_status("Server disconnected.")


func _close_network_locally() -> void:
	suppress_disconnect_until_msec = Time.get_ticks_msec() + 500
	game_account_authenticated = false
	network.close()


func _on_peer_connected(peer_id: int) -> void:
	if not _is_network_server():
		return

	_log_server_event("peer_connected", {"peer_id": peer_id})
	if network.is_dedicated_server():
		peer_auth_deadlines_msec[peer_id] = Time.get_ticks_msec() + ACCOUNT_AUTH_TIMEOUT_MSEC
		return
	_complete_peer_account_authentication(
		peer_id,
		{"id": "local:%s" % peer_id, "display_name": "Local player", "friend_code": ""},
		"",
		false
	)


@rpc("any_peer", "call_remote", "reliable")
func _server_authenticate_game_ticket(ticket: String) -> void:
	if not _is_network_server() or not network.is_dedicated_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 0 or peer_account_ids.has(peer_id) or peer_auth_in_progress.has(peer_id):
		return
	if peer_account_ids.size() >= network.max_clients:
		_reject_peer_account_authentication(peer_id, "The game server is full.")
		return
	if ticket.length() > 512 or (ticket.length() < 24 and not _is_account_auth_test_mode()):
		_reject_peer_account_authentication(peer_id, "Invalid or expired game ticket.")
		return
	peer_auth_in_progress[peer_id] = true
	var result: Dictionary
	if _is_account_auth_test_mode() and ticket.begins_with("smoke-"):
		var test_account_ticket := ticket.trim_suffix("-reconnect")
		result = {
			"ok": true,
			"user": {
				"id": "test:%s" % test_account_ticket,
				"display_name": "Smoke player",
				"friend_code": "TEST",
			},
			"play_session_id": "test-session:%s" % ticket,
		}
	else:
		result = await account_game_bridge.redeem_game_ticket(ticket)
	peer_auth_in_progress.erase(peer_id)
	if not multiplayer.get_peers().has(peer_id):
		return
	if not bool(result.get("ok", false)):
		_log_server_event("account_auth_rejected", {
			"peer_id": peer_id,
			"status": int(result.get("status", 0)),
		})
		_reject_peer_account_authentication(peer_id, "Invalid or expired game ticket.")
		return
	var user: Dictionary = result.get("user", {})
	var account_id := str(user.get("id", ""))
	var play_session_id := str(result.get("play_session_id", ""))
	if account_id == "" or play_session_id == "":
		_reject_peer_account_authentication(peer_id, "Account service returned an invalid identity.")
		return
	_complete_peer_account_authentication(peer_id, user, play_session_id, true)


func _complete_peer_account_authentication(
	peer_id: int,
	user: Dictionary,
	play_session_id: String,
	notify_client: bool
) -> void:
	peer_auth_deadlines_msec.erase(peer_id)
	peer_account_ids[peer_id] = str(user.get("id", ""))
	peer_account_profiles[peer_id] = user.duplicate(true)
	peer_account_event_sequences[peer_id] = 0
	if play_session_id != "":
		peer_play_session_ids[peer_id] = play_session_id
		if not _is_account_auth_test_mode():
			account_game_bridge.enqueue_heartbeat(play_session_id, false)
	_log_server_event("account_authenticated", {
		"peer_id": peer_id,
		"account_id": peer_account_ids[peer_id],
	})
	if notify_client:
		_game_ticket_authenticated.rpc_id(peer_id, user)
	_send_authenticated_peer_state(peer_id)


func _send_authenticated_peer_state(peer_id: int) -> void:
	for player in players.get_children():
		var existing_id := int(player.name)
		_spawn_player_remote.rpc_id(peer_id, existing_id, player.global_position, player.player_color, player.rotation.y, str(player.get("session_id")))
	_send_online_session_list(peer_id)


func _reject_peer_account_authentication(peer_id: int, message: String) -> void:
	peer_auth_deadlines_msec.erase(peer_id)
	peer_auth_in_progress.erase(peer_id)
	_game_ticket_rejected.rpc_id(peer_id, message)
	_disconnect_peer_after_auth_rejection(peer_id)


func _disconnect_peer_after_auth_rejection(peer_id: int) -> void:
	await get_tree().create_timer(0.25).timeout
	if multiplayer.multiplayer_peer and multiplayer.get_peers().has(peer_id):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


@rpc("authority", "call_remote", "reliable")
func _game_ticket_authenticated(_user: Dictionary) -> void:
	game_account_authenticated = true
	ui.set_connecting(false)
	_continue_after_game_authentication()


@rpc("authority", "call_remote", "reliable")
func _game_ticket_rejected(message: String) -> void:
	_stop_connection_timer()
	game_account_authenticated = false
	ui.set_connecting(false)
	ui.set_status(message)
	_close_network_locally()


func _on_peer_disconnected(peer_id: int) -> void:
	if _is_network_server():
		_log_server_event("peer_disconnected", {"peer_id": peer_id})
		_remove_peer_from_online_session(peer_id, false)
		_remove_player_remote.rpc(peer_id)
		_end_account_play_session(peer_id)
		peer_account_ids.erase(peer_id)
		peer_account_profiles.erase(peer_id)
		peer_account_event_sequences.erase(peer_id)
		peer_auth_deadlines_msec.erase(peer_id)
		peer_auth_in_progress.erase(peer_id)
	_remove_player_remote(peer_id)
	_refresh_pressure_plates()
	_broadcast_online_session_list()


func _is_account_auth_test_mode() -> bool:
	return OS.is_debug_build() and OS.get_cmdline_args().has("--account-auth-test-mode")


func _authenticated_remote_sender_id() -> int:
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 0:
		return 0
	if not network.is_dedicated_server() or peer_account_ids.has(peer_id):
		return peer_id
	_log_server_event("unauthenticated_rpc_rejected", {"peer_id": peer_id})
	return 0


func _reject_dedicated_lobby_rpc(
	peer_id: int,
	rpc_name: String,
	online_state: Dictionary
) -> bool:
	if not network.is_dedicated_server() or peer_id <= 0 or not online_state.is_empty():
		return false
	_log_server_event("lobby_rpc_rejected", {"peer_id": peer_id, "rpc": rpc_name})
	return true


func _prune_unauthenticated_peers() -> void:
	if not network.is_dedicated_server() or peer_auth_deadlines_msec.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	for peer_id_value in peer_auth_deadlines_msec.keys():
		var peer_id := int(peer_id_value)
		if now_msec < int(peer_auth_deadlines_msec[peer_id]):
			continue
		_log_server_event("account_auth_timeout", {"peer_id": peer_id})
		_reject_peer_account_authentication(peer_id, "Game account authentication timed out.")


func _step_account_heartbeats(delta: float) -> void:
	if peer_play_session_ids.is_empty() or _is_account_auth_test_mode():
		return
	account_heartbeat_accumulator += maxf(delta, 0.0)
	if account_heartbeat_accumulator < ACCOUNT_HEARTBEAT_INTERVAL:
		return
	account_heartbeat_accumulator = fmod(account_heartbeat_accumulator, ACCOUNT_HEARTBEAT_INTERVAL)
	for peer_id_value in peer_play_session_ids.keys():
		var peer_id := int(peer_id_value)
		var online_state := _get_online_session_for_peer(peer_id)
		var play_session_id := str(peer_play_session_ids.get(peer_id, ""))
		if play_session_id != "":
			var active := (
				not online_state.is_empty()
				and not bool(online_state.get("finished", false))
			)
			account_game_bridge.enqueue_heartbeat(play_session_id, active)


func _end_account_play_session(peer_id: int) -> void:
	var play_session_id := str(peer_play_session_ids.get(peer_id, ""))
	peer_play_session_ids.erase(peer_id)
	if play_session_id == "" or _is_account_auth_test_mode():
		return
	account_game_bridge.enqueue_end(play_session_id)


func _record_account_event(
	peer_id: int,
	event_type: String,
	achievement_code := "",
	context := ""
) -> void:
	var play_session_id := str(peer_play_session_ids.get(peer_id, ""))
	if play_session_id == "" or _is_account_auth_test_mode():
		return
	var sequence := int(peer_account_event_sequences.get(peer_id, 0)) + 1
	peer_account_event_sequences[peer_id] = sequence
	var event_id := ("%s:%s:%s:%s" % [
		play_session_id,
		event_type,
		sequence,
		context.validate_node_name(),
	]).left(256)
	account_game_bridge.enqueue_event(
		play_session_id,
		event_id,
		event_type,
		achievement_code
	)


func _record_account_achievement(peer_id: int, achievement_code: String, context := "") -> void:
	_record_account_event(peer_id, "achievement", achievement_code, context)


func _record_account_death(peer_id: int, context := "") -> void:
	_record_account_event(peer_id, "death", "", context)


@rpc("authority", "call_remote", "reliable")
func _remove_player_remote(peer_id: int) -> void:
	var node := players.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()
		call_deferred("_update_session_status")


@rpc("any_peer", "call_remote", "reliable")
func _server_request_online_session_list() -> void:
	if not _is_network_server():
		return
	var peer_id := _authenticated_remote_sender_id()
	if peer_id == 0:
		return
	_send_online_session_list(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _server_create_online_session() -> void:
	if not _is_network_server():
		return
	var peer_id := _authenticated_remote_sender_id()
	if peer_id == 0:
		return
	_prune_expired_online_sessions()
	if online_sessions.size() >= MAX_ONLINE_SESSIONS:
		_online_session_error.rpc_id(peer_id, "All session slots are currently in use.")
		return
	var session_id := "S%03d" % next_session_number
	next_session_number += 1
	online_sessions[session_id] = _create_online_session_state(session_id)
	_assign_peer_to_online_session(peer_id, session_id)


@rpc("any_peer", "call_remote", "reliable")
func _server_join_online_session(session_id: String) -> void:
	if not _is_network_server():
		return
	var peer_id := _authenticated_remote_sender_id()
	if peer_id == 0:
		return
	_prune_expired_online_sessions()
	if (
		not _is_online_session_joinable(session_id)
		and not _is_online_session_reconnectable_for_peer(session_id, peer_id)
	):
		_log_server_event("session_join_ignored", {
			"peer_id": peer_id,
			"session_id": session_id,
			"exists": online_sessions.has(session_id),
		})
		_online_session_error.rpc_id(peer_id, "That session has ended or is no longer active.")
		_send_online_session_list(peer_id)
		return
	_assign_peer_to_online_session(peer_id, session_id)


@rpc("authority", "call_remote", "reliable")
func _receive_online_session_list(sessions: Array) -> void:
	ui.set_connecting(false)
	if active_session_id == "" and not started:
		ui.show_session_browser(sessions)


@rpc("authority", "call_remote", "reliable")
func _online_session_error(message: String) -> void:
	if pending_reconnect_session_id != "":
		pending_reconnect_session_id = ""
		last_online_session_id = ""
	ui.set_connecting(false)
	ui.set_status(message)


@rpc("authority", "call_remote", "reliable")
func _online_session_joined(session_id: String) -> void:
	active_session_id = session_id
	last_online_session_id = session_id
	pending_reconnect_session_id = ""
	ui.set_connecting(false)
	ui.hide_session_browser()
	_start_game()
	_refresh_player_session_visibility()
	_update_session_status()
	ui.set_status("Joined %s." % session_id)


func _create_online_session_state(session_id: String) -> Dictionary:
	return {
		"id": session_id,
		"name": "Session %s" % session_id.trim_prefix("S"),
		"level_path": LEVEL_SCENE.resource_path,
		"collected_note_ids": [],
		"session_collected_notes": 0,
		"exit_open": false,
		"pressure_plate_states": {},
		"monster_activation_states": {},
		"level_mechanic_states": {},
		"monster_states": {},
		"monster_kill_latches": {},
		"journal_state": _create_empty_journal_snapshot(),
		"members": [],
		"account_ids": [],
		"empty_since_msec": 0,
		"finished": false,
	}


func _is_online_session_joinable(session_id: String) -> bool:
	if not online_sessions.has(session_id):
		return false
	var state: Dictionary = online_sessions[session_id]
	var members: Array = state["members"]
	return not members.is_empty() and not bool(state["finished"])


func _is_online_session_reconnectable(session_id: String, now_msec := -1) -> bool:
	if not online_sessions.has(session_id):
		return false
	var state: Dictionary = online_sessions[session_id]
	if bool(state["finished"]) or not (state["members"] as Array).is_empty():
		return false
	var empty_since_msec := int(state.get("empty_since_msec", 0))
	if empty_since_msec <= 0:
		return false
	var checked_msec: int = Time.get_ticks_msec() if now_msec < 0 else int(now_msec)
	return checked_msec - empty_since_msec < SESSION_RECONNECT_GRACE_MSEC


func _is_online_session_reconnectable_for_peer(session_id: String, peer_id: int) -> bool:
	if not _is_online_session_reconnectable(session_id):
		return false
	var state: Dictionary = online_sessions[session_id]
	var account_id := str(peer_account_ids.get(peer_id, ""))
	return account_id != "" and (state.get("account_ids", []) as Array).has(account_id)


func _prune_expired_online_sessions(now_msec := -1) -> void:
	var checked_msec: int = Time.get_ticks_msec() if now_msec < 0 else int(now_msec)
	for session_id in online_sessions.keys():
		var state: Dictionary = online_sessions[session_id]
		var members: Array = state["members"]
		if not members.is_empty():
			continue
		if bool(state["finished"]) or not _is_online_session_reconnectable(str(session_id), checked_msec):
			online_sessions.erase(session_id)


func _create_empty_journal_snapshot() -> Dictionary:
	var journal := MonsterJournal.new()
	journal.reset()
	var snapshot := journal.get_snapshot()
	journal.free()
	return snapshot


func _assign_peer_to_online_session(peer_id: int, session_id: String) -> void:
	_remove_peer_before_online_session_assignment(peer_id, session_id)
	var state: Dictionary = online_sessions[session_id]
	var members: Array = state["members"]
	if not members.has(peer_id):
		members.append(peer_id)
	state["members"] = members
	var account_ids: Array = state.get("account_ids", [])
	var account_id := str(peer_account_ids.get(peer_id, ""))
	if account_id != "" and not account_ids.has(account_id):
		account_ids.append(account_id)
	state["account_ids"] = account_ids
	state["empty_since_msec"] = 0
	peer_session_ids[peer_id] = session_id
	var play_session_id := str(peer_play_session_ids.get(peer_id, ""))
	if play_session_id != "" and not _is_account_auth_test_mode():
		account_game_bridge.enqueue_heartbeat(play_session_id, true)
	_online_session_joined.rpc_id(peer_id, session_id)
	_send_online_session_state(peer_id, state)
	_spawn_player_for_online_session(peer_id, state)
	_log_server_event("session_joined", {"peer_id": peer_id, "session_id": session_id})
	_broadcast_online_session_list()


func _remove_peer_before_online_session_assignment(peer_id: int, next_session_id: String) -> void:
	var previous_session_id := str(peer_session_ids.get(peer_id, ""))
	if previous_session_id == "" or previous_session_id == next_session_id:
		return
	_remove_peer_from_online_session(peer_id)


func _remove_peer_from_online_session(peer_id: int, delete_empty := true) -> void:
	if not peer_session_ids.has(peer_id):
		return
	var session_id := str(peer_session_ids[peer_id])
	peer_session_ids.erase(peer_id)
	if not online_sessions.has(session_id):
		return
	var state: Dictionary = online_sessions[session_id]
	var members: Array = state["members"]
	members.erase(peer_id)
	state["members"] = members
	if delete_empty and members.is_empty():
		online_sessions.erase(session_id)
	elif members.is_empty():
		if bool(state["finished"]):
			online_sessions.erase(session_id)
		else:
			state["empty_since_msec"] = maxi(Time.get_ticks_msec(), 1)


func _serialize_online_sessions() -> Array:
	_prune_expired_online_sessions()
	var result := []
	var ids := online_sessions.keys()
	ids.sort()
	for session_id in ids:
		var state: Dictionary = online_sessions[session_id]
		var members: Array = state["members"]
		if not _is_online_session_joinable(str(session_id)):
			continue
		result.append({
			"id": session_id,
			"name": state["name"],
			"level": _get_level_title_from_path(str(state["level_path"])),
			"players": members.size(),
			"finished": bool(state["finished"]),
		})
	return result


func _send_online_session_list(peer_id: int) -> void:
	_receive_online_session_list.rpc_id(peer_id, _serialize_online_sessions())


func _broadcast_online_session_list() -> void:
	if not _is_network_server():
		return
	var sessions := _serialize_online_sessions()
	for peer_id in multiplayer.get_peers():
		if network.is_dedicated_server() and not peer_account_ids.has(peer_id):
			continue
		if not peer_session_ids.has(peer_id):
			_receive_online_session_list.rpc_id(peer_id, sessions)


func _send_online_session_state(peer_id: int, state: Dictionary) -> void:
	_sync_session_state.rpc_id(
		peer_id,
		str(state["level_path"]),
		_typed_string_array(state["collected_note_ids"]),
		int(state["session_collected_notes"]),
		bool(state["exit_open"]),
		(state["pressure_plate_states"] as Dictionary).duplicate(true),
		(state["monster_activation_states"] as Dictionary).duplicate(true),
		_get_online_mechanic_snapshot(state),
		_get_online_monster_snapshot(state),
		(state["journal_state"] as Dictionary).duplicate(true),
		str(state["id"])
	)


func _typed_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _get_online_session_for_peer(peer_id: int) -> Dictionary:
	var session_id := str(peer_session_ids.get(peer_id, ""))
	if session_id == "" or not online_sessions.has(session_id):
		return {}
	return online_sessions[session_id]


func _get_level_title_from_path(level_path: String) -> String:
	match level_path:
		"res://scenes/level.tscn":
			return "Room 1"
		"res://scenes/next_place.tscn":
			return "Room 2"
		"res://scenes/backrooms/backrooms_builder_demo.tscn":
			return "Backrooms"
		"res://scenes/endless_house/endless_house_builder_demo.tscn":
			return "House Survey"
		"res://scenes/endless_house/unlit_evidence_demo.tscn":
			return "Maintenance Test"
		"res://scenes/corridor.tscn":
			return "Corridor"
		"res://scenes/fourth_room.tscn":
			return "Final Room"
	return "Unknown Room"


#endregion

#region Player spawning and session runtime

@rpc("any_peer", "call_remote", "reliable")
func _request_spawn(_peer_id: int) -> void:
	if _is_network_server():
		var sender_id := _authenticated_remote_sender_id()
		if sender_id == 0:
			return
		var online_state := _get_online_session_for_peer(sender_id)
		if _reject_dedicated_lobby_rpc(sender_id, "spawn", online_state):
			return
		if network.is_dedicated_server():
			_spawn_player_for_online_session(sender_id, online_state)
			return
		_log_server_event("spawn_requested", {"peer_id": sender_id, "sender": sender_id})
		_spawn_player(sender_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_respawn() -> void:
	if not _is_network_server():
		return
	var peer_id := _authenticated_remote_sender_id()
	if peer_id == 0:
		return
	var online_state := _get_online_session_for_peer(peer_id)
	if _reject_dedicated_lobby_rpc(peer_id, "respawn", online_state):
		return
	if not online_state.is_empty():
		_log_server_event("session_respawn_requested", {"session_id": online_state["id"], "peer_id": peer_id})
		_reset_online_monster_runtime_state(online_state)
		_respawn_in_current_session.rpc_id(
			peer_id,
			str(online_state["level_path"]),
			_typed_string_array(online_state["collected_note_ids"]),
			int(online_state["session_collected_notes"]),
			bool(online_state["exit_open"]),
			(online_state["pressure_plate_states"] as Dictionary).duplicate(true),
			(online_state["monster_activation_states"] as Dictionary).duplicate(true),
			_get_online_mechanic_snapshot(online_state),
			_get_online_monster_snapshot(online_state),
			(online_state["journal_state"] as Dictionary).duplicate(true)
		)
		var session_spawns := _get_session_spawn_positions(str(online_state["level_path"]))
		var member_index: int = maxi((online_state["members"] as Array).find(peer_id), 0)
		_move_player_to_spawn_remote.rpc(peer_id, session_spawns[member_index % session_spawns.size()], _get_session_spawn_yaw(str(online_state["level_path"])))
		_move_player_to_spawn_remote(peer_id, session_spawns[member_index % session_spawns.size()], _get_session_spawn_yaw(str(online_state["level_path"])))
		return
	_log_server_event("respawn_requested", {"peer_id": peer_id})
	_respawn_in_current_session.rpc_id(
		peer_id,
		current_level_scene.resource_path,
		collected_note_ids,
		session_collected_notes,
		_is_level_exit_open(),
		_get_pressure_plate_states(),
		_get_monster_activation_states(),
		_get_level_mechanic_states(),
		_get_online_monster_snapshot({
			"level_path": current_level_scene.resource_path,
			"monster_states": {},
		}),
		monster_journal.get_snapshot()
	)
	var spawn_positions := _get_spawn_positions()
	_move_player_to_spawn(peer_id, spawn_positions[0])


@rpc("authority", "call_remote", "reliable")
func _respawn_in_current_session(
	level_path: String,
	synced_collected_note_ids: Array[String],
	synced_session_collected_notes: int,
	synced_level_exit_open: bool,
	synced_pressure_plate_states: Dictionary,
	synced_monster_activation_states: Dictionary,
	synced_level_mechanic_states: Dictionary,
	synced_monster_states: Dictionary,
	synced_journal_state: Dictionary
) -> void:
	var scene := _get_level_scene_by_path(level_path)
	if not scene:
		_return_to_menu()
		return
	collected_notes = 0
	collected_note_ids = synced_collected_note_ids.duplicate()
	session_collected_notes = synced_session_collected_notes
	_load_level_scene(scene)
	_apply_collected_note_state()
	_apply_pressure_plate_states(synced_pressure_plate_states)
	_apply_monster_activation_states(synced_monster_activation_states)
	_apply_level_mechanic_states(synced_level_mechanic_states)
	_apply_online_monster_states(synced_monster_states)
	monster_journal.apply_snapshot(synced_journal_state)
	ui.set_journal_available(monster_journal.unlocked)
	_apply_level_exit_state(synced_level_exit_open)
	started = true
	ui.hide_death()
	ui.hide_victory()
	ui.hide_menu()
	_set_player_controls(true)
	_capture_game_input(not OS.has_feature("web"))
	_update_objective()
	_update_hud()


@rpc("any_peer", "call_remote", "reliable")
func _request_session_reset() -> void:
	if not _is_network_server():
		return

	var requesting_peer_id := _authenticated_remote_sender_id()
	if requesting_peer_id == 0:
		return
	var online_state := _get_online_session_for_peer(requesting_peer_id)
	if _reject_dedicated_lobby_rpc(requesting_peer_id, "session_reset", online_state):
		return
	if not online_state.is_empty():
		_reset_online_session_state(online_state)
		return
	_log_server_event("session_reset_requested", {"sender": requesting_peer_id})
	_apply_session_reset.rpc()
	_apply_session_reset()


func _reset_online_session_state(state: Dictionary) -> void:
	state["level_path"] = LEVEL_SCENE.resource_path
	state["collected_note_ids"] = []
	state["session_collected_notes"] = 0
	state["exit_open"] = false
	state["pressure_plate_states"] = {}
	state["monster_activation_states"] = {}
	state["level_mechanic_states"] = {}
	state["monster_states"] = {}
	state["monster_kill_latches"] = {}
	state["journal_state"] = _create_empty_journal_snapshot()
	state["finished"] = false
	for member_id in state["members"]:
		_respawn_in_current_session.rpc_id(
			int(member_id),
			str(state["level_path"]),
			_typed_string_array(state["collected_note_ids"]),
			int(state["session_collected_notes"]),
			bool(state["exit_open"]),
			(state["pressure_plate_states"] as Dictionary).duplicate(true),
			(state["monster_activation_states"] as Dictionary).duplicate(true),
			_get_online_mechanic_snapshot(state),
			_get_online_monster_snapshot(state),
			(state["journal_state"] as Dictionary).duplicate(true)
		)
	_move_online_session_players_to_spawns(state)
	_log_server_event("online_session_reset", {"session_id": state["id"]})
	_broadcast_online_session_list()


func _reset_online_monster_runtime_state(state: Dictionary) -> void:
	state["monster_states"] = {}
	state["monster_kill_latches"] = {}


@rpc("authority", "call_remote", "reliable")
func _apply_session_reset() -> void:
	collected_notes = 0
	collected_note_ids.clear()
	session_collected_notes = 0
	monster_journal.reset()
	level_transitioning = false
	nearby_dialogue_npc = null
	active_dialogue_npc = null
	active_dialogue_pages.clear()
	active_dialogue_index = 0
	_clear_players()
	_load_level_scene(LEVEL_SCENE)
	started = true
	if _is_network_server():
		_spawn_current_players()
		_log_server_event("session_reset_applied")
	if network.is_dedicated_server():
		return

	ui.hide_death()
	ui.hide_victory()
	ui.hide_dialogue()
	ui.set_journal_available(false)
	ui.hide_menu()
	ui.set_connecting(false)
	ui.set_status("Online session reset to Room 1.")
	_capture_game_input(not OS.has_feature("web"))
	_update_objective()
	_update_hud()
	_show_level_banner()


func _spawn_player(peer_id: int) -> void:
	if players.has_node(str(peer_id)):
		return

	var spawn_positions := _get_spawn_positions()
	var spawn_index := players.get_child_count() % spawn_positions.size()
	var color: Color = PLAYER_COLORS[spawn_index % PLAYER_COLORS.size()]
	var spawn_yaw := _get_spawn_yaw()
	var player_session_id := str(peer_session_ids.get(peer_id, active_session_id))
	if multiplayer.has_multiplayer_peer():
		_spawn_player_remote.rpc(peer_id, spawn_positions[spawn_index], color, spawn_yaw, player_session_id)
	_spawn_player_remote(peer_id, spawn_positions[spawn_index], color, spawn_yaw, player_session_id)


func _spawn_player_for_online_session(peer_id: int, state: Dictionary) -> void:
	var members: Array = state["members"]
	var spawn_positions := _get_session_spawn_positions(str(state["level_path"]))
	var spawn_index: int = maxi(members.find(peer_id), 0) % spawn_positions.size()
	var spawn_position: Vector3 = spawn_positions[spawn_index]
	var spawn_yaw := _get_session_spawn_yaw(str(state["level_path"]))
	var player_session_id := str(state["id"])
	if players.has_node(str(peer_id)):
		_move_player_to_online_session_remote.rpc(
			peer_id,
			spawn_position,
			spawn_yaw,
			player_session_id
		)
		_move_player_to_online_session_remote(
			peer_id,
			spawn_position,
			spawn_yaw,
			player_session_id
		)
		return
	var color: Color = PLAYER_COLORS[spawn_index % PLAYER_COLORS.size()]
	_spawn_player_remote.rpc(peer_id, spawn_position, color, spawn_yaw, player_session_id)
	_spawn_player_remote(peer_id, spawn_position, color, spawn_yaw, player_session_id)


@rpc("authority", "call_remote", "reliable")
func _move_player_to_online_session_remote(
	peer_id: int,
	spawn_position: Vector3,
	spawn_yaw: float,
	player_session_id: String
) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if not player:
		return
	player.session_id = player_session_id
	player.global_position = spawn_position
	player.rotation.y = spawn_yaw
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	if player.has_method("reset_remote_sync_tracking"):
		player.reset_remote_sync_tracking()
	if player.has_method("set_active_session"):
		player.set_active_session(active_session_id)
	_update_session_status()


func _get_session_spawn_positions(level_path: String) -> Array:
	match level_path:
		"res://scenes/level.tscn":
			return [Vector3(-0.8, 0.2, -4.15), Vector3(0.8, 0.2, -4.15)]
		"res://scenes/backrooms/backrooms_builder_demo.tscn":
			return [Vector3(4.0, 0.2, 4.0), Vector3(4.8, 0.2, 4.0), Vector3(3.2, 0.2, 4.0)]
		"res://scenes/endless_house/endless_house_builder_demo.tscn":
			return [Vector3(4.0, 0.2, 4.0), Vector3(4.0, 0.2, 4.8), Vector3(4.0, 0.2, 3.2)]
		"res://scenes/endless_house/unlit_evidence_demo.tscn":
			return [Vector3(4.0, 0.2, 4.0), Vector3(4.0, 0.2, 4.8), Vector3(4.0, 0.2, 3.2)]
		"res://scenes/corridor.tscn":
			return [Vector3(0.0, 0.2, -26.0), Vector3(-0.8, 0.2, -26.0), Vector3(0.8, 0.2, -26.0)]
		"res://scenes/fourth_room.tscn":
			return [Vector3(0.0, 0.2, 3.2), Vector3(-1.0, 0.2, 3.2), Vector3(1.0, 0.2, 3.2)]
	return SPAWNS


func _get_session_spawn_yaw(level_path: String) -> float:
	if level_path == HOUSE_BUILDER_DEMO_SCENE.resource_path or level_path == UNLIT_EVIDENCE_DEMO_SCENE.resource_path:
		return -PI * 0.5
	if level_path == LEVEL_SCENE.resource_path or level_path == CORRIDOR_SCENE.resource_path:
		return PI
	return 0.0


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


func _get_spawn_yaw() -> float:
	if current_level_scene == LEVEL_SCENE or current_level_scene == CORRIDOR_SCENE:
		return PI
	if current_level_scene == HOUSE_BUILDER_DEMO_SCENE or current_level_scene == UNLIT_EVIDENCE_DEMO_SCENE:
		return -PI * 0.5
	return 0.0


@rpc("authority", "call_remote", "reliable")
func _spawn_player_remote(peer_id: int, spawn_position: Vector3, color: Color, spawn_yaw: float, player_session_id := "") -> void:
	if players.has_node(str(peer_id)):
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.player_id = peer_id
	player.player_color = color
	player.session_id = player_session_id
	player.position = spawn_position
	player.rotation.y = spawn_yaw
	players.add_child(player)
	if player.has_method("set_active_session"):
		player.set_active_session(active_session_id)
	_update_session_status()


func _refresh_player_session_visibility() -> void:
	for player in players.get_children():
		if player.has_method("set_active_session"):
			player.set_active_session(active_session_id)
	_update_session_status()


func _update_session_status() -> void:
	if network.is_dedicated_server() or active_session_id == "":
		ui.set_session_status("")
		return
	var player_count := 0
	for player in players.get_children():
		if str(player.get("session_id")) == active_session_id:
			player_count += 1
	ui.set_session_status(
		"%s | %s player%s"
		% [active_session_id, player_count, "" if player_count == 1 else "s"]
	)


#endregion

#region Evidence, exits, mechanics, and observation

func _on_note_collected(note_id: String, note_text: String) -> void:
	if not multiplayer.has_multiplayer_peer():
		_collect_note(note_id, note_text)
		return

	if _is_network_server():
		_server_collect_note(note_id)
	else:
		_request_collect_note.rpc_id(1, note_id)


func _on_note_puzzle_requested(note_id: String, note_text: String, puzzle_type: int) -> void:
	_set_player_controls(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_note_puzzle(note_id, note_text, puzzle_type)


func _on_note_puzzle_completed(note_id: String, note_text: String) -> void:
	if started:
		_restore_game_input_after_interaction()
	_on_note_collected(note_id, note_text)


func _on_note_puzzle_cancelled(note_id: String) -> void:
	var note := _get_note_by_id(note_id)
	if note and note.has_method("reset_collection_attempt"):
		note.reset_collection_attempt()
	if started:
		_restore_game_input_after_interaction()


@rpc("any_peer", "call_remote", "reliable")
func _request_collect_note(note_id: String) -> void:
	if _is_network_server():
		var peer_id := _authenticated_remote_sender_id()
		if peer_id != 0:
			_server_collect_note(note_id, peer_id)


func _server_collect_note(note_id: String, requesting_peer_id := 0) -> void:
	var online_state := _get_online_session_for_peer(requesting_peer_id)
	if _reject_dedicated_lobby_rpc(requesting_peer_id, "collect_note", online_state):
		return
	if not online_state.is_empty():
		_server_collect_online_session_note(online_state, note_id, requesting_peer_id)
		return
	if collected_note_ids.has(note_id):
		_log_server_event("note_duplicate_ignored", {"note_id": note_id})
		return

	var note := _get_note_by_id(note_id)
	if not note:
		_log_server_event("note_missing_ignored", {"note_id": note_id})
		return

	var note_text := str(note.get("note_text"))
	var journal_entry_id := str(note.get("journal_entry_id"))
	var journal_fact_index := int(note.get("journal_fact_index"))
	var journal_rumor_id := str(note.get("journal_rumor_id"))
	_log_server_event("note_collected", {"note_id": note_id})
	_collect_note.rpc(note_id, note_text)
	_collect_note(note_id, note_text)
	if journal_entry_id != "" and (journal_fact_index > 0 or journal_rumor_id != ""):
		_server_apply_journal_discovery(false, journal_entry_id, journal_fact_index, journal_rumor_id)


func _server_collect_online_session_note(
	state: Dictionary,
	note_id: String,
	requesting_peer_id: int
) -> void:
	var level_path := str(state["level_path"])
	var definitions: Dictionary = SESSION_NOTE_DEFINITIONS.get(level_path, {})
	var collected: Array = state["collected_note_ids"]
	if collected.has(note_id):
		_log_server_event("session_note_duplicate_ignored", {"session_id": state["id"], "note_id": note_id})
		return
	if not definitions.has(note_id):
		_log_server_event("session_note_missing_ignored", {"session_id": state["id"], "note_id": note_id})
		return
	var definition: Dictionary = definitions[note_id]
	if not _is_online_peer_near_position(
		requesting_peer_id,
		state,
		definition["position"],
		float(definition["collection_radius"])
	):
		_log_server_event("session_note_out_of_range", {
			"session_id": state["id"],
			"level": level_path,
			"note_id": note_id,
		})
		return
	var recovered_text := str(definition.get("text", "Evidence recovered."))
	collected.append(note_id)
	state["collected_note_ids"] = collected
	state["session_collected_notes"] = int(state["session_collected_notes"]) + 1
	for member_id in state["members"]:
		_collect_note.rpc_id(int(member_id), note_id, recovered_text)
	var entry_id := str(definition.get("entry_id", ""))
	var fact_index := int(definition.get("fact_index", 0))
	var rumor_id := str(definition.get("rumor_id", ""))
	if entry_id != "" and (fact_index > 0 or rumor_id != ""):
		_apply_discovery_to_online_session(state, false, entry_id, fact_index, rumor_id)
	_update_online_note_gated_monsters(state)
	_evaluate_online_session_exit(state)
	_record_account_achievement(
		requesting_peer_id,
		"first_record",
		"%s:%s" % [level_path, note_id]
	)
	_log_server_event("session_note_collected", {"session_id": state["id"], "note_id": note_id})


func _update_online_note_gated_monsters(state: Dictionary) -> void:
	var definitions: Array = SESSION_NOTE_GATED_MONSTERS.get(str(state["level_path"]), [])
	var activation_states: Dictionary = state["monster_activation_states"]
	var collected_count := int(state["session_collected_notes"])
	for definition: Dictionary in definitions:
		var source_id := str(definition["source_id"])
		if bool(activation_states.get(source_id, false)):
			continue
		if collected_count < int(definition["notes_required"]):
			continue
		activation_states[source_id] = true
		for member_id in state["members"]:
			_apply_online_monster_activation_state.rpc_id(int(member_id), source_id, true)
		var entry_id := str(definition.get("entry_id", ""))
		var fact_index := int(definition.get("fact_index", 0))
		if entry_id != "" and fact_index > 0:
			_apply_discovery_to_online_session(state, false, entry_id, fact_index)
	state["monster_activation_states"] = activation_states


@rpc("authority", "call_remote", "reliable")
func _apply_online_monster_activation_state(source_id: String, is_activated: bool) -> void:
	for monster in _get_level_monsters():
		if (
			str(level.get_path_to(monster)) == source_id
			and monster.has_method("set_note_gated_activated")
		):
			monster.call("set_note_gated_activated", is_activated)
			return


@rpc("authority", "call_remote", "reliable")
func _collect_note(note_id: String, note_text: String) -> void:
	if collected_note_ids.has(note_id):
		if multiplayer.has_multiplayer_peer() and not _is_network_server():
			print("[client_event] note_apply_duplicate note_id=%s session=%s" % [note_id, active_session_id])
		return

	var note := _get_note_by_id(note_id)
	if not note:
		if multiplayer.has_multiplayer_peer() and not _is_network_server():
			print("[client_event] note_apply_missing note_id=%s session=%s" % [note_id, active_session_id])
		return

	var journal_entry_id := str(note.get("journal_entry_id"))
	var journal_fact_index := int(note.get("journal_fact_index"))
	var journal_rumor_id := str(note.get("journal_rumor_id"))
	collected_note_ids.append(note_id)
	last_recovered_record_text = note_text
	note.queue_free()
	collected_notes += 1
	session_collected_notes += 1
	if multiplayer.has_multiplayer_peer() and not _is_network_server():
		print("[client_event] note_applied note_id=%s session=%s" % [note_id, active_session_id])
	if audio_cues.has_method("play_note_pickup"):
		audio_cues.play_note_pickup()
	if not network.is_dedicated_server():
		call_deferred("_ensure_game_input_available")
	if not multiplayer.has_multiplayer_peer() and journal_entry_id != "" and (journal_fact_index > 0 or journal_rumor_id != ""):
		_apply_journal_discovery(false, journal_entry_id, journal_fact_index, journal_rumor_id)
	if _is_local_unlit_debug_preview():
		_activate_debug_unlit_assist()
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


func _close_level_exit() -> void:
	if not _is_level_exit_open():
		return
	_set_level_exit_open(false)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_set_level_exit_open.rpc(false)


@rpc("authority", "call_remote", "reliable")
func _set_level_exit_open(is_open: bool) -> void:
	_apply_level_exit_state(is_open)
	if is_open:
		if audio_cues.has_method("play_exit_open"):
			audio_cues.play_exit_open()
		_update_objective()
		ui.set_status("The entrance is open.")
		return

	if audio_cues.has_method("play_exit_close"):
		audio_cues.play_exit_close()
	_update_objective()
	ui.set_status("The doorway destabilized.")


func _on_level_exit_entered() -> void:
	if level_transitioning:
		return
	if _is_local_unlit_debug_preview():
		_leave_local_unlit_debug_preview()
		return
	if _is_offline_branch_study():
		_leave_offline_branch_study()
		return
	if current_level_scene == FOURTH_ROOM_SCENE:
		if not _is_journal_complete():
			ui.set_status("The final opening rejects an incomplete field journal.")
			_update_objective()
			return
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

	if _is_network_server():
		_begin_next_level_transition.rpc()
		_begin_next_level_transition()
	else:
		_request_next_level_transition.rpc_id(1)


func _on_pressure_plate_changed(_is_active: bool, plate: Node = null) -> void:
	if multiplayer.has_multiplayer_peer() and not _is_network_server():
		var plate_id := str(level.get_path_to(plate)) if plate else "PressurePlate"
		_request_online_pressure_state.rpc_id(1, plate_id, _is_active)
		return
	if _is_network_server():
		_log_server_event("pressure_plate_changed", {"active": _is_active})
	_evaluate_level_exit_unlock()


@rpc("any_peer", "call_remote", "reliable")
func _request_online_pressure_state(plate_id: String, is_active: bool) -> void:
	if not _is_network_server():
		return
	var requesting_peer_id := _authenticated_remote_sender_id()
	if requesting_peer_id == 0:
		return
	var state := _get_online_session_for_peer(requesting_peer_id)
	if state.is_empty():
		return
	var level_path := str(state["level_path"])
	var plate_definitions: Dictionary = SESSION_PRESSURE_PLATE_DEFINITIONS.get(level_path, {})
	if not plate_definitions.has(plate_id):
		_log_server_event(
			"session_pressure_state_ignored",
			{"session_id": state["id"], "level": level_path, "plate_id": plate_id}
		)
		return
	if is_active:
		var definition: Dictionary = plate_definitions[plate_id]
		if not _is_online_peer_near_position(
			requesting_peer_id,
			state,
			definition["position"],
			float(definition["activation_radius"])
		):
			_log_server_event(
				"session_pressure_state_out_of_range",
				{"session_id": state["id"], "level": level_path, "plate_id": plate_id}
			)
			return
	var pressure_states: Dictionary = state["pressure_plate_states"]
	pressure_states[plate_id] = is_active
	state["pressure_plate_states"] = pressure_states
	for member_id in state["members"]:
		_apply_online_pressure_state.rpc_id(int(member_id), plate_id, is_active)
	_evaluate_online_session_exit(state)


@rpc("authority", "call_remote", "reliable")
func _apply_online_pressure_state(plate_id: String, is_active: bool) -> void:
	for plate in _get_level_pressure_plates():
		if str(level.get_path_to(plate)) == plate_id and plate.has_method("set_synced_active"):
			plate.set_synced_active(is_active)
			return


func _on_monster_activated(monster: Node) -> void:
	if _is_network_server():
		_log_server_event("monster_activated")
		_record_monster_discovery(monster)
	else:
		_record_monster_discovery(monster)
	if network.is_dedicated_server():
		return
	if audio_cues.has_method("play_threat"):
		audio_cues.play_threat()
	pending_activation_monster = monster
	monster_activation_feedback_timer.start()


func _show_monster_activation_feedback() -> void:
	if network.is_dedicated_server():
		return
	if (
		not is_instance_valid(pending_activation_monster)
		or not level
		or not level.is_ancestor_of(pending_activation_monster)
	):
		return
	var message := "The record stopped rustling. Footsteps answered behind you."
	ui.set_status(message)
	_update_hud(message)


func _on_monster_observed(monster: Node) -> void:
	var entry_id := str(monster.get("journal_entry_id"))
	var fact_index := int(monster.get("journal_fact_index_on_observation"))
	if entry_id != "" and fact_index > 0:
		_submit_journal_discovery(false, entry_id, fact_index, "", monster)
	_show_observation_message(monster)


func _on_environmental_evidence_observed(source: Node) -> void:
	var entry_id := str(source.get("journal_entry_id"))
	var fact_index := int(source.get("journal_fact_index_on_observation"))
	if entry_id != "" and fact_index > 0:
		_submit_journal_discovery(false, entry_id, fact_index, "", source)
	_show_observation_message(source)
	if source.has_method("is_triggered") and bool(source.call("is_triggered")):
		_evaluate_level_exit_unlock()


func _on_environmental_outage_changed(is_in_outage: bool) -> void:
	if is_in_outage:
		if audio_cues.has_method("play_power_outage"):
			audio_cues.play_power_outage()
	elif audio_cues.has_method("play_power_restore"):
		audio_cues.play_power_restore()


func _on_breaker_outage_requested(source: Node) -> void:
	if not multiplayer.has_multiplayer_peer() or _is_network_server():
		return
	var source_id := _get_level_source_id(source)
	if source_id != "":
		_request_online_breaker_outage.rpc_id(1, source_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_online_breaker_outage(source_id: String) -> void:
	if not _is_network_server():
		return
	var peer_id := _authenticated_remote_sender_id()
	if peer_id == 0:
		return
	var state := _get_online_session_for_peer(peer_id)
	if state.is_empty():
		return
	_server_apply_online_breaker_outage(state, peer_id, source_id)


func _server_apply_online_breaker_outage(
	state: Dictionary,
	peer_id: int,
	source_id: String,
	now_msec := -1
) -> bool:
	var level_path := str(state.get("level_path", ""))
	var definitions: Dictionary = SESSION_BREAKER_DEFINITIONS.get(level_path, {})
	if not definitions.has(source_id):
		_log_server_event("session_breaker_ignored", {
			"session_id": state.get("id", ""),
			"level": level_path,
			"source_id": source_id,
		})
		return false
	var definition: Dictionary = definitions[source_id]
	if not _is_online_peer_near_position(
		peer_id,
		state,
		definition["position"],
		float(definition["activation_radius"])
	):
		_log_server_event("session_breaker_out_of_range", {
			"session_id": state.get("id", ""),
			"level": level_path,
			"source_id": source_id,
		})
		return false
	var mechanic_states: Dictionary = state.get("level_mechanic_states", {})
	var breaker_state: Dictionary = mechanic_states.get(source_id, {})
	if bool(breaker_state.get("triggered", false)):
		_log_server_event("session_breaker_duplicate_ignored", {
			"session_id": state.get("id", ""),
			"source_id": source_id,
		})
		return false
	var timestamp := int(Time.get_ticks_msec()) if now_msec < 0 else int(now_msec)
	var outage_duration := maxf(float(definition["outage_duration"]), 0.0)
	var work_light_id := str(definition["work_light_id"])
	mechanic_states[source_id] = {"triggered": true}
	mechanic_states[work_light_id] = {
		"outage_deadline_msec": timestamp + roundi(outage_duration * 1000.0),
	}
	state["level_mechanic_states"] = mechanic_states
	_apply_discovery_to_online_session(
		state,
		false,
		str(definition.get("entry_id", "")),
		int(definition.get("fact_index", 0))
	)
	_evaluate_online_session_exit(state)
	_broadcast_online_mechanic_snapshot(state)
	var message := str(definition.get("message", "")).strip_edges()
	if not message.is_empty():
		for member_id in state.get("members", []):
			_show_authoritative_status.rpc_id(int(member_id), message)
	_log_server_event("session_breaker_triggered", {
		"session_id": state.get("id", ""),
		"source_id": source_id,
		"outage_duration": outage_duration,
	})
	return true


func _broadcast_online_mechanic_snapshot(state: Dictionary) -> void:
	var snapshot := _get_online_mechanic_snapshot(state)
	for member_id in state.get("members", []):
		_apply_level_mechanic_states.rpc_id(int(member_id), snapshot)


@rpc("authority", "call_remote", "reliable")
func _show_authoritative_status(message: String) -> void:
	if not network.is_dedicated_server() and not message.strip_edges().is_empty():
		ui.set_status(message)


func _show_observation_message(source: Node) -> void:
	if network.is_dedicated_server():
		return
	var message := str(source.get("observation_message")).strip_edges()
	if not message.is_empty():
		ui.set_status(message)


func _on_watcher_gaze_warning(progress: float, seconds_remaining: float) -> void:
	if network.is_dedicated_server() or not started:
		return
	ui.show_threat_warning(progress, seconds_remaining)


func _on_watcher_gaze_cleared() -> void:
	if network.is_dedicated_server():
		return
	ui.hide_threat_warning()


func _evaluate_level_exit_unlock() -> void:
	if collected_notes < total_notes or total_notes <= 0:
		return
	if not _are_breaker_requirements_satisfied():
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			_close_level_exit()
			_update_objective()
			ui.set_status("The maintenance exit needs the spent breaker.")
		return
	if current_level_scene != UNLIT_EVIDENCE_DEMO_SCENE and not _are_pressure_plates_satisfied():
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			_close_level_exit()
		_update_objective()
		ui.set_status("The doorway needs the floor switch.")
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_open_level_exit()


func _evaluate_online_session_exit(state: Dictionary) -> void:
	var level_path := str(state["level_path"])
	var definitions: Dictionary = SESSION_NOTE_DEFINITIONS.get(level_path, {})
	var collected: Array = state["collected_note_ids"]
	var required_plate_count := int(SESSION_PRESSURE_REQUIREMENTS.get(level_path, 0))
	var required_breaker_count := int(SESSION_BREAKER_REQUIREMENTS.get(level_path, 0))
	var active_plate_count := 0
	var triggered_breaker_count := 0
	var pressure_states: Dictionary = state["pressure_plate_states"]
	var mechanic_states: Dictionary = state["level_mechanic_states"]
	var plate_definitions: Dictionary = SESSION_PRESSURE_PLATE_DEFINITIONS.get(level_path, {})
	var breaker_definitions: Dictionary = SESSION_BREAKER_DEFINITIONS.get(level_path, {})
	for plate_id in plate_definitions:
		if bool(pressure_states.get(str(plate_id), false)):
			active_plate_count += 1
	for breaker_id in breaker_definitions:
		var breaker_state: Dictionary = mechanic_states.get(str(breaker_id), {})
		if bool(breaker_state.get("triggered", false)):
			triggered_breaker_count += 1
	var should_open := _is_session_level_open_by_default(level_path)
	if not should_open and not definitions.is_empty():
		should_open = (
			collected.size() >= definitions.size()
			and active_plate_count >= required_plate_count
			and triggered_breaker_count >= required_breaker_count
		)
	if bool(state["exit_open"]) == should_open:
		return
	state["exit_open"] = should_open
	for member_id in state["members"]:
		_set_level_exit_open.rpc_id(int(member_id), should_open)


func _is_online_peer_near_position(
	peer_id: int,
	state: Dictionary,
	target_position: Vector3,
	max_distance: float
) -> bool:
	var player := players.get_node_or_null(str(peer_id)) as Node3D
	if not player or str(player.get("session_id")) != str(state["id"]):
		return false
	return player.global_position.distance_to(target_position) <= maxf(max_distance, 0.1)


func _is_online_peer_near_session_exit(peer_id: int, state: Dictionary) -> bool:
	var definition: Dictionary = SESSION_EXIT_DEFINITIONS.get(str(state["level_path"]), {})
	if definition.is_empty():
		return false
	return _is_online_peer_near_position(
		peer_id,
		state,
		definition["position"],
		float(definition["activation_radius"])
	)


func _is_online_peer_facing_position(
	peer_id: int,
	state: Dictionary,
	target_position: Vector3,
	minimum_dot: float
) -> bool:
	var player := players.get_node_or_null(str(peer_id)) as Node3D
	if not player or str(player.get("session_id")) != str(state["id"]):
		return false
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		return false
	var offset := target_position - camera.global_position
	if offset.length_squared() <= 0.001:
		return true
	var camera_forward := -camera.global_basis.z.normalized()
	return camera_forward.dot(offset.normalized()) >= clampf(minimum_dot, -1.0, 1.0)


func _is_session_level_open_by_default(level_path: String) -> bool:
	return level_path == CORRIDOR_SCENE.resource_path or level_path == FOURTH_ROOM_SCENE.resource_path


#endregion

#region Level transitions, dialogue, and journal

@rpc("any_peer", "call_remote", "reliable")
func _request_next_level_transition() -> void:
	if not _is_network_server():
		return
	var requesting_peer_id := _authenticated_remote_sender_id()
	if requesting_peer_id == 0:
		return
	var online_state := _get_online_session_for_peer(requesting_peer_id)
	if _reject_dedicated_lobby_rpc(requesting_peer_id, "next_level", online_state):
		return
	if not online_state.is_empty():
		if not bool(online_state["exit_open"]):
			_log_server_event("session_transition_ignored", {"session_id": online_state["id"], "peer_id": requesting_peer_id})
			return
		if not _is_online_peer_near_session_exit(requesting_peer_id, online_state):
			_log_server_event("session_transition_out_of_range", {
				"session_id": online_state["id"],
				"peer_id": requesting_peer_id,
				"level": online_state["level_path"],
			})
			return
		_advance_online_session(online_state)
		return
	if level_transitioning or not _is_level_exit_open():
		_log_server_event("level_transition_ignored", {"sender": multiplayer.get_remote_sender_id()})
		return

	_log_server_event("level_transition_requested", {"sender": multiplayer.get_remote_sender_id()})
	_begin_next_level_transition.rpc()
	_begin_next_level_transition()


@rpc("any_peer", "call_remote", "reliable")
func _request_complete_game() -> void:
	if not _is_network_server():
		return
	var requesting_peer_id := _authenticated_remote_sender_id()
	if requesting_peer_id == 0:
		return
	var online_state := _get_online_session_for_peer(requesting_peer_id)
	if _reject_dedicated_lobby_rpc(requesting_peer_id, "complete_game", online_state):
		return
	if not online_state.is_empty():
		if bool(online_state.get("finished", false)):
			_log_server_event("session_victory_ignored", {
				"session_id": online_state["id"],
				"peer_id": requesting_peer_id,
				"reason": "already_finished",
			})
			return
		if (
			str(online_state["level_path"]) != FOURTH_ROOM_SCENE.resource_path
			or not bool(online_state["exit_open"])
			or not _is_online_session_journal_complete(online_state)
			or not _is_online_peer_near_session_exit(requesting_peer_id, online_state)
		):
			_log_server_event("session_victory_ignored", {"session_id": online_state["id"], "peer_id": requesting_peer_id})
			return
		online_state["finished"] = true
		for member_id in online_state["members"]:
			_record_account_achievement(int(member_id), "field_researcher", "complete-journal")
			_record_account_achievement(int(member_id), "escaped", "completed-game")
			var play_session_id := str(peer_play_session_ids.get(int(member_id), ""))
			if play_session_id != "" and not _is_account_auth_test_mode():
				account_game_bridge.enqueue_heartbeat(play_session_id, false)
			_complete_game.rpc_id(int(member_id))
		_broadcast_online_session_list()
		return
	if current_level_scene != FOURTH_ROOM_SCENE or not _is_level_exit_open() or not _is_journal_complete():
		_log_server_event("victory_ignored", {"sender": multiplayer.get_remote_sender_id()})
		return

	_log_server_event("victory_requested", {"sender": multiplayer.get_remote_sender_id()})
	_complete_game.rpc()
	_complete_game()


func _advance_online_session(state: Dictionary) -> void:
	var current_path := str(state["level_path"])
	if current_path == LEVEL_SCENE.resource_path:
		_apply_discovery_to_online_session(state, false, "listener", 2)
	elif current_path == CORRIDOR_SCENE.resource_path:
		_apply_discovery_to_online_session(state, false, "listener", 3)
	var next_path := _get_next_session_level_path(current_path)
	state["level_path"] = next_path
	state["collected_note_ids"] = []
	state["pressure_plate_states"] = {}
	state["monster_activation_states"] = {}
	state["level_mechanic_states"] = {}
	state["monster_states"] = {}
	state["monster_kill_latches"] = {}
	state["exit_open"] = _is_session_level_open_by_default(next_path)
	for member_id in state["members"]:
		_send_online_session_state(int(member_id), state)
	_move_online_session_players_to_spawns(state)
	_log_server_event("session_level_loaded", {"session_id": state["id"], "level": next_path})
	_broadcast_online_session_list()


func _get_next_session_level_path(current_path: String) -> String:
	var index := SESSION_LEVEL_PATHS.find(current_path)
	if index < 0 or index >= SESSION_LEVEL_PATHS.size() - 1:
		return FOURTH_ROOM_SCENE.resource_path
	return str(SESSION_LEVEL_PATHS[index + 1])


func _move_online_session_players_to_spawns(state: Dictionary) -> void:
	var spawn_positions := _get_session_spawn_positions(str(state["level_path"]))
	var spawn_yaw := _get_session_spawn_yaw(str(state["level_path"]))
	var members: Array = state["members"]
	for index in range(members.size()):
		var peer_id := int(members[index])
		_move_player_to_spawn_remote.rpc(peer_id, spawn_positions[index % spawn_positions.size()], spawn_yaw)
		_move_player_to_spawn_remote(peer_id, spawn_positions[index % spawn_positions.size()], spawn_yaw)


func _is_online_session_journal_complete(state: Dictionary) -> bool:
	var journal := MonsterJournal.new()
	journal.reset()
	journal.apply_snapshot(state["journal_state"])
	var complete := journal.unlocked and is_equal_approx(journal.get_completion_ratio(), 1.0)
	journal.free()
	return complete


@rpc("authority", "call_remote", "reliable")
func _begin_next_level_transition() -> void:
	if level_transitioning:
		return

	level_transitioning = true
	if _is_network_server():
		_log_server_event("level_transition_started")
	_set_player_controls(false)
	call_deferred("_enter_next_level")


func _enter_next_level() -> void:
	_record_level_completion_discovery()
	collected_notes = 0
	collected_note_ids.clear()
	_load_level_scene(_get_next_level_scene())
	_move_current_players_to_spawns()
	level_transitioning = false
	if _is_network_server():
		_log_server_event("level_loaded")
	ui.set_status("You entered the next place.")
	_update_objective()
	_update_hud("You entered the next place.")


func _record_level_completion_discovery() -> void:
	var entry_id := ""
	var fact_index := 0
	if current_level_scene == LEVEL_SCENE:
		entry_id = "listener"
		fact_index = 2
	elif current_level_scene == CORRIDOR_SCENE:
		entry_id = "listener"
		fact_index = 3
	else:
		return
	if not multiplayer.has_multiplayer_peer():
		_apply_journal_discovery(false, entry_id, fact_index)
	elif _is_network_server():
		_server_apply_journal_discovery(false, entry_id, fact_index)


func _get_next_level_scene() -> PackedScene:
	if current_level_scene == LEVEL_SCENE:
		return NEXT_PLACE_SCENE
	if current_level_scene == NEXT_PLACE_SCENE:
		return BACKROOMS_SCENE
	if current_level_scene == BACKROOMS_SCENE:
		return HOUSE_BUILDER_DEMO_SCENE
	if current_level_scene == HOUSE_BUILDER_DEMO_SCENE:
		return UNLIT_EVIDENCE_DEMO_SCENE
	if current_level_scene == UNLIT_EVIDENCE_DEMO_SCENE:
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
	synced_monster_activation_states := {},
	synced_level_mechanic_states := {},
	synced_monster_states := {},
	synced_journal_state := {},
	synced_session_id := ""
) -> void:
	print("[client_event] session_sync level=%s collected_notes=%s exit_open=%s" % [level_path, synced_collected_note_ids.size(), synced_level_exit_open])
	var scene := _get_level_scene_by_path(level_path)
	var session_changed := synced_session_id != "" and synced_session_id != loaded_session_id
	if synced_session_id != "":
		active_session_id = synced_session_id
		_refresh_player_session_visibility()
	if scene and (scene != current_level_scene or session_changed):
		collected_notes = 0
		collected_note_ids.clear()
		_load_level_scene(scene)

	collected_note_ids = synced_collected_note_ids.duplicate()
	session_collected_notes = int(synced_session_collected_notes)
	_apply_collected_note_state()
	_apply_pressure_plate_states(synced_pressure_plate_states)
	_apply_monster_activation_states(synced_monster_activation_states)
	_apply_level_mechanic_states(synced_level_mechanic_states)
	_apply_online_monster_states(synced_monster_states)
	monster_journal.apply_snapshot(synced_journal_state)
	ui.set_journal_available(monster_journal.unlocked)
	_apply_journal_difficulty()
	_apply_level_exit_state(synced_level_exit_open)
	_update_hud()
	if synced_session_id != "":
		loaded_session_id = synced_session_id


func _on_player_killed(reason: String, source: Node = null) -> void:
	if source and (not is_instance_valid(source) or not level or not level.is_ancestor_of(source)):
		return
	_apply_player_death(reason, false)


func _apply_player_death(reason: String, server_authoritative: bool) -> void:
	if qa_invulnerable and not multiplayer.has_multiplayer_peer():
		last_death_reason = reason
		ui.set_status("QA invulnerability blocked death: %s" % reason)
		return
	last_death_was_server_authoritative = server_authoritative
	last_death_reason = reason
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
	ui.set_extra_hint("Use interact to talk")
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
		_end_dialogue(true)
		return

	_show_current_dialogue_page()


func _show_current_dialogue_page() -> void:
	ui.show_dialogue(
		active_dialogue_npc.speaker_name,
		active_dialogue_pages[active_dialogue_index],
		active_dialogue_index,
		active_dialogue_pages.size()
	)


func _end_dialogue(completed := false) -> void:
	var completed_npc := active_dialogue_npc
	ui.hide_dialogue()
	active_dialogue_npc = null
	active_dialogue_pages.clear()
	active_dialogue_index = 0
	_set_player_controls(true)
	if completed and completed_npc:
		var should_unlock := bool(completed_npc.grants_journal)
		var entry_id := str(completed_npc.journal_entry_id)
		var fact_index := int(completed_npc.journal_fact_index)
		var rumor_id := str(completed_npc.journal_rumor_id)
		if should_unlock or entry_id != "":
			_submit_journal_discovery(should_unlock, entry_id, fact_index, rumor_id, completed_npc)
	if started:
		_restore_game_input_after_interaction()


func _set_player_controls(enabled: bool) -> void:
	for player in players.get_children():
		if player.has_method("set_controls_enabled"):
			player.set_controls_enabled(enabled)


func _toggle_journal() -> void:
	if not started:
		return
	if not monster_journal.unlocked:
		ui.set_status("You have not received the field journal yet.")
		return
	_set_player_controls(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_journal(monster_journal.get_progress_text(), monster_journal.get_rendered_text())


func _close_journal() -> void:
	if not ui.is_journal_visible():
		return
	ui.hide_journal()
	if started:
		_restore_game_input_after_interaction()


func _submit_journal_discovery(
	should_unlock: bool,
	entry_id: String,
	fact_index: int,
	rumor_id := "",
	source: Node = null
) -> void:
	if not multiplayer.has_multiplayer_peer():
		_apply_journal_discovery(should_unlock, entry_id, fact_index, rumor_id)
		return
	var source_id := _get_level_source_id(source)
	if _is_network_server():
		_server_apply_journal_discovery(should_unlock, entry_id, fact_index, rumor_id)
	else:
		_request_journal_discovery.rpc_id(
			1,
			source_id,
			should_unlock,
			entry_id,
			fact_index,
			rumor_id
		)


@rpc("any_peer", "call_remote", "reliable")
func _request_journal_discovery(
	source_id: String,
	should_unlock: bool,
	entry_id: String,
	fact_index: int,
	rumor_id: String
) -> void:
	if _is_network_server():
		var peer_id := _authenticated_remote_sender_id()
		if peer_id == 0:
			return
		_server_apply_journal_discovery(
			should_unlock,
			entry_id,
			fact_index,
			rumor_id,
			peer_id,
			source_id
		)


func _server_apply_journal_discovery(
	should_unlock: bool,
	entry_id: String,
	fact_index: int,
	rumor_id := "",
	requesting_peer_id := 0,
	source_id := ""
) -> void:
	var online_state := _get_online_session_for_peer(requesting_peer_id)
	if _reject_dedicated_lobby_rpc(requesting_peer_id, "journal_discovery", online_state):
		return
	if not online_state.is_empty():
		var discovery_definition := _get_online_client_discovery_definition(
			online_state,
			source_id,
			should_unlock,
			entry_id,
			fact_index,
			rumor_id
		)
		if discovery_definition.is_empty():
			_log_server_event("session_journal_discovery_ignored", {
				"session_id": online_state["id"],
				"level": online_state["level_path"],
				"source_id": source_id,
				"entry_id": entry_id,
				"fact_index": fact_index,
				"rumor_id": rumor_id,
				"unlock": should_unlock,
			})
			return
		if (
			discovery_definition.has("interaction_radius")
			and not _is_online_peer_near_position(
				requesting_peer_id,
				online_state,
				discovery_definition["position"],
				float(discovery_definition["interaction_radius"])
			)
		):
			_log_server_event("session_journal_discovery_out_of_range", {
				"session_id": online_state["id"],
				"level": online_state["level_path"],
				"source_id": source_id,
			})
			return
		if (
			discovery_definition.has("observation_radius")
			and not _is_online_peer_near_position(
				requesting_peer_id,
				online_state,
				discovery_definition["position"],
				float(discovery_definition["observation_radius"])
			)
		):
			_log_server_event("session_journal_observation_out_of_range", {
				"session_id": online_state["id"],
				"level": online_state["level_path"],
				"source_id": source_id,
			})
			return
		if (
			discovery_definition.has("facing_dot_min")
			and not _is_online_peer_facing_position(
				requesting_peer_id,
				online_state,
				discovery_definition["position"],
				float(discovery_definition["facing_dot_min"])
			)
		):
			_log_server_event("session_journal_observation_not_facing", {
				"session_id": online_state["id"],
				"level": online_state["level_path"],
				"source_id": source_id,
			})
			return
		_apply_discovery_to_online_session(online_state, should_unlock, entry_id, fact_index, rumor_id)
		return
	if entry_id != "" and not monster_journal.is_valid_entry(entry_id):
		_log_server_event("journal_discovery_ignored", {"entry_id": entry_id})
		return
	var safe_fact_index := fact_index if monster_journal.is_valid_fact(entry_id, fact_index) else 0
	var safe_rumor_id := rumor_id if monster_journal.is_valid_rumor(entry_id, rumor_id) else ""
	_apply_journal_discovery.rpc(should_unlock, entry_id, safe_fact_index, safe_rumor_id)
	_apply_journal_discovery(should_unlock, entry_id, safe_fact_index, safe_rumor_id)


func _get_online_client_discovery_definition(
	state: Dictionary,
	source_id: String,
	should_unlock: bool,
	entry_id: String,
	fact_index: int,
	rumor_id: String
) -> Dictionary:
	var allowed_discoveries: Array = SESSION_CLIENT_DISCOVERIES.get(str(state["level_path"]), [])
	for allowed: Dictionary in allowed_discoveries:
		if (
			str(allowed["source_id"]) == source_id
			and bool(allowed["unlock"]) == should_unlock
			and str(allowed["entry_id"]) == entry_id
			and int(allowed["fact_index"]) == fact_index
			and str(allowed["rumor_id"]) == rumor_id
		):
			return allowed
	return {}


func _get_level_source_id(source: Node) -> String:
	if not source or not level or not level.is_ancestor_of(source):
		return ""
	return str(level.get_path_to(source))


func _apply_discovery_to_online_session(
	state: Dictionary,
	should_unlock: bool,
	entry_id: String,
	fact_index: int,
	rumor_id := ""
) -> void:
	var journal := MonsterJournal.new()
	journal.reset()
	journal.apply_snapshot(state["journal_state"])
	if entry_id != "" and not journal.is_valid_entry(entry_id):
		journal.free()
		return
	var safe_fact_index := fact_index if journal.is_valid_fact(entry_id, fact_index) else 0
	var safe_rumor_id := rumor_id if journal.is_valid_rumor(entry_id, rumor_id) else ""
	var changed := false
	if should_unlock:
		changed = journal.unlock() or changed
	if safe_fact_index > 0:
		changed = journal.discover(entry_id, safe_fact_index) or changed
	if safe_rumor_id != "":
		changed = journal.discover_rumor(entry_id, safe_rumor_id) or changed
	state["journal_state"] = journal.get_snapshot()
	journal.free()
	if not changed:
		return
	for member_id in state["members"]:
		_apply_journal_discovery.rpc_id(int(member_id), should_unlock, entry_id, safe_fact_index, safe_rumor_id)
	_log_server_event("session_journal_updated", {
		"session_id": state["id"],
		"entry_id": entry_id,
		"fact_index": safe_fact_index,
		"rumor_id": safe_rumor_id,
	})


@rpc("authority", "call_remote", "reliable")
func _apply_journal_discovery(should_unlock: bool, entry_id: String, fact_index: int, rumor_id := "") -> void:
	var unlocked_now: bool = bool(monster_journal.unlock()) if should_unlock else false
	var fact_discovered: bool = bool(monster_journal.discover(entry_id, fact_index)) if fact_index > 0 else false
	var rumor_discovered: bool = bool(monster_journal.discover_rumor(entry_id, rumor_id)) if rumor_id != "" else false
	if not unlocked_now and not fact_discovered and not rumor_discovered:
		return
	if _is_network_server():
		_log_server_event("journal_updated", {
			"entry_id": entry_id,
			"fact_index": fact_index,
			"rumor_id": rumor_id,
			"unlocked": monster_journal.unlocked,
		})
	var behavior_shift := _apply_journal_difficulty()
	if network.is_dedicated_server():
		return
	ui.set_journal_available(monster_journal.unlocked)
	if ui.is_journal_visible():
		ui.show_journal(monster_journal.get_progress_text(), monster_journal.get_rendered_text())
	if unlocked_now:
		ui.set_status("Mara gave you the field journal.")
	elif fact_discovered:
		ui.set_status("A verified observation was added to the journal.")
	elif rumor_discovered and monster_journal.unlocked:
		ui.set_status("An unverified rumor was added to the journal.")
	if behavior_shift != "":
		if audio_cues.has_method("play_threat"):
			audio_cues.play_threat()
		ui.set_status(behavior_shift)


func _record_monster_discovery(monster: Node) -> void:
	if multiplayer.has_multiplayer_peer() and monster is CorridorMonster:
		return
	var entry_id := str(monster.get("journal_entry_id"))
	var fact_index := int(monster.get("journal_fact_index_on_activation"))
	if entry_id != "" and fact_index > 0:
		_submit_journal_discovery(false, entry_id, fact_index, "", monster)


func _apply_journal_difficulty() -> String:
	var completion_ratio := float(monster_journal.get_completion_ratio())
	var behavior_shift := ""
	for monster in _get_level_monsters():
		var previous_tier := int(monster.call("get_knowledge_behavior_tier")) if monster.has_method("get_knowledge_behavior_tier") else 0
		if monster.has_method("set_knowledge_profile"):
			var entry_id := str(monster.get("journal_entry_id"))
			var entry_ratio := float(monster_journal.get_entry_completion_ratio(entry_id))
			monster.call("set_knowledge_profile", completion_ratio, entry_ratio)
		elif monster.has_method("set_knowledge_difficulty"):
			monster.set_knowledge_difficulty(completion_ratio)
		var next_tier := int(monster.call("get_knowledge_behavior_tier")) if monster.has_method("get_knowledge_behavior_tier") else 0
		if next_tier > previous_tier and monster.has_method("get_knowledge_behavior_message"):
			behavior_shift = str(monster.call("get_knowledge_behavior_message"))
	return behavior_shift


#endregion

#region Input handling and debug previews

func _capture_game_input(capture_mouse := true) -> void:
	get_viewport().gui_release_focus()
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		ui.hide_pointer_hint()
	elif OS.has_feature("web"):
		ui.show_pointer_hint()


func _restore_game_input_after_interaction() -> void:
	if network.is_dedicated_server():
		return
	_set_player_controls(true)
	_capture_game_input(true)
	call_deferred("_release_gui_focus_after_interaction")


func _release_gui_focus_after_interaction() -> void:
	get_viewport().gui_release_focus()
	if OS.has_feature("web") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		ui.show_pointer_hint()


func _ensure_game_input_available() -> void:
	if not started or ui.is_blocking_overlay_visible():
		return
	_set_player_controls(true)
	get_viewport().gui_release_focus()
	if OS.has_feature("web") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		ui.show_pointer_hint()


func _should_capture_game_input(event: InputEvent) -> bool:
	if not OS.has_feature("web"):
		return false
	if not started or ui.is_blocking_overlay_visible():
		return false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return false
	return event is InputEventMouseButton and event.pressed


func _should_recover_game_input(event: InputEvent) -> bool:
	if not started or ui.is_blocking_overlay_visible():
		return false
	return event is InputEventKey and event.pressed and not event.echo


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


func _handle_debug_house_preview_input(event: InputEvent) -> bool:
	if not OS.is_debug_build() or network.is_dedicated_server() or multiplayer.has_multiplayer_peer():
		return false
	if not started or ui.is_blocking_overlay_visible():
		return false
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	if (event as InputEventKey).physical_keycode != KEY_F9:
		return false

	collected_notes = 0
	collected_note_ids.clear()
	_load_level_scene(HOUSE_BUILDER_DEMO_SCENE)
	_move_current_players_to_spawns()
	ui.set_status("The house assembled another hall.")
	_update_hud()
	return true


func _handle_debug_unlit_preview_input(event: InputEvent) -> bool:
	if not OS.is_debug_build() or network.is_dedicated_server() or multiplayer.has_multiplayer_peer():
		return false
	if not started or ui.is_blocking_overlay_visible():
		return false
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	if (event as InputEventKey).physical_keycode != KEY_F8:
		return false

	debug_preview_session_collected_notes = session_collected_notes
	collected_notes = 0
	collected_note_ids.clear()
	_load_level_scene(UNLIT_EVIDENCE_DEMO_SCENE)
	_move_current_players_to_spawns()
	ui.set_status("A maintenance test is still waiting in the dark.")
	_update_hud()
	return true


func _handle_debug_branch_preview_input(event: InputEvent) -> bool:
	if not OS.is_debug_build() or network.is_dedicated_server() or multiplayer.has_multiplayer_peer():
		return false
	if not started or ui.is_blocking_overlay_visible():
		return false
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var physical_keycode := (event as InputEventKey).physical_keycode
	var branch := BranchCatalog.find_by_debug_key(physical_keycode)
	if branch == null or not branch.is_valid():
		return false

	if not _is_offline_branch_study():
		debug_preview_session_collected_notes = session_collected_notes
	collected_notes = 0
	collected_note_ids.clear()
	_load_level_scene(branch.scene)
	_move_current_players_to_spawns()
	ui.set_status(branch.arrival_status)
	_update_hud()
	return true


func _is_offline_branch_study() -> bool:
	return (
		not network.is_dedicated_server()
		and not multiplayer.has_multiplayer_peer()
		and BranchCatalog.find_by_scene(current_level_scene) != null
	)


func _leave_offline_branch_study() -> void:
	collected_notes = 0
	collected_note_ids.clear()
	session_collected_notes = debug_preview_session_collected_notes
	debug_preview_session_collected_notes = 0
	started = false
	_clear_players()
	_load_level_scene(LEVEL_SCENE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_branch_browser(BranchCatalog.ALL)
	ui.set_status("Choose another environment study or return to the main route.")
	_update_hud()


func _is_local_unlit_debug_preview() -> bool:
	return (
		OS.is_debug_build()
		and not OS.has_feature("web")
		and not network.is_dedicated_server()
		and not multiplayer.has_multiplayer_peer()
		and current_level_scene == UNLIT_EVIDENCE_DEMO_SCENE
	)


func _activate_debug_unlit_assist() -> void:
	for plate in _get_level_pressure_plates():
		if plate.has_method("set_synced_active"):
			plate.call("set_synced_active", true)


func _leave_local_unlit_debug_preview() -> void:
	collected_notes = 0
	collected_note_ids.clear()
	session_collected_notes = debug_preview_session_collected_notes
	debug_preview_session_collected_notes = 0
	_load_level_scene(LEVEL_SCENE)
	_move_current_players_to_spawns()
	ui.set_status("The maintenance test folded back into the first room.")
	_update_hud()


func _adjust_day_night_cycle(multiplier: float) -> void:
	if not day_night_cycle.has_method("get_cycle_length") or not day_night_cycle.has_method("set_cycle_length"):
		return

	var current_length := float(day_night_cycle.get_cycle_length())
	var next_length: float = clamp(current_length * multiplier, 10.0, 3600.0)
	day_night_cycle.set_cycle_length(next_length)
	ui.set_status("Day/night cycle length: %ss" % int(next_length))


func _handle_qa_menu_input(event: InputEvent) -> bool:
	if network.is_dedicated_server():
		return false
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	if (event as InputEventKey).physical_keycode != KEY_F1:
		return false
	ui.toggle_qa_menu()
	return true


func _setup_qa_mode() -> void:
	if network.is_dedicated_server():
		return
	ui.configure_qa_mode(
		_get_qa_level_entries(),
		current_level_scene.resource_path,
		qa_invulnerable,
		qa_noclip,
		qa_speed_multiplier,
		qa_monsters_paused
	)
	players.child_entered_tree.connect(_on_qa_player_added)
	qa_diagnostics_timer = Timer.new()
	qa_diagnostics_timer.wait_time = 0.2
	qa_diagnostics_timer.timeout.connect(_qa_update_diagnostics)
	add_child(qa_diagnostics_timer)
	qa_diagnostics_timer.start()
	_qa_update_diagnostics()


func _get_qa_level_entries() -> Array:
	var entries := [
		{"title": "01 • Room 1 — The Wrong Copy", "scene_path": LEVEL_SCENE.resource_path},
		{"title": "02 • Room 2 — The Copied Door", "scene_path": NEXT_PLACE_SCENE.resource_path},
		{"title": "03 • Backrooms — Yellow Drift", "scene_path": BACKROOMS_SCENE.resource_path},
		{"title": "04 • House Survey — Repeated Hall", "scene_path": HOUSE_BUILDER_DEMO_SCENE.resource_path},
		{"title": "05 • The Unlit — Maintenance Wing", "scene_path": UNLIT_EVIDENCE_DEMO_SCENE.resource_path},
		{"title": "06 • Corridor — Do Not Sprint", "scene_path": CORRIDOR_SCENE.resource_path},
		{"title": "07 • Final Room — Do Not Stare", "scene_path": FOURTH_ROOM_SCENE.resource_path},
	]
	for branch in BranchCatalog.ALL:
		entries.append({
			"title": "STUDY • %s" % branch.title,
			"scene_path": branch.scene.resource_path,
		})
	return entries


func _on_qa_panel_open_changed(is_open: bool) -> void:
	if not started:
		return
	if is_open:
		_set_player_controls(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.set_qa_notice("QA menu active. Close with F1 to return camera control.")
		return
	if not ui.is_blocking_overlay_visible():
		_set_player_controls(true)
		_capture_game_input(true)


func _on_qa_player_added(_player: Node) -> void:
	call_deferred("_qa_apply_player_settings")


func _qa_require_offline(action_name: String) -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	ui.set_qa_notice("%s is blocked during online play." % action_name, true)
	ui.set_status("QA gameplay commands are offline-only.")
	return false


func _qa_load_level(scene_path: String) -> void:
	if not _qa_require_offline("Level loading"):
		return
	var scene := _get_level_scene_by_path(scene_path)
	if scene == null:
		ui.set_qa_notice("Unknown level: %s" % scene_path, true)
		return
	ui.hide_death()
	ui.hide_victory()
	collected_notes = 0
	collected_note_ids.clear()
	if not started:
		_reset_session()
		_load_level_scene(scene)
		_start_game()
		_spawn_player(1)
	else:
		_load_level_scene(scene)
		_move_current_players_to_spawns()
	_qa_apply_player_settings()
	_qa_apply_monster_pause()
	ui.set_qa_current_scene(scene.resource_path)
	ui.set_status("QA loaded: %s" % _get_level_title())
	ui.set_qa_notice("Loaded %s. Close with F1 to play." % _get_level_title())
	_on_qa_panel_open_changed(ui.is_qa_menu_open())
	_qa_update_diagnostics()


func _qa_reload_level() -> void:
	if not _qa_require_offline("Reload level"):
		return
	_qa_load_level(current_level_scene.resource_path)


func _qa_set_invulnerable(enabled: bool) -> void:
	qa_invulnerable = enabled
	ui.set_qa_notice("Invulnerability %s." % ("enabled" if enabled else "disabled"))
	_qa_update_diagnostics()


func _qa_set_noclip(enabled: bool) -> void:
	if enabled and not _qa_require_offline("Fly / No-clip"):
		qa_noclip = false
		ui.configure_qa_mode(_get_qa_level_entries(), current_level_scene.resource_path, qa_invulnerable, false, qa_speed_multiplier, qa_monsters_paused)
		return
	qa_noclip = enabled
	_qa_apply_player_settings()
	ui.set_qa_notice("Fly mode %s. WASD move, Space up, Ctrl down." % ("enabled" if enabled else "disabled"))
	_qa_update_diagnostics()


func _qa_set_speed(multiplier: float) -> void:
	if not _qa_require_offline("Speed change"):
		qa_speed_multiplier = 1.0
		ui.configure_qa_mode(_get_qa_level_entries(), current_level_scene.resource_path, qa_invulnerable, qa_noclip, 1.0, qa_monsters_paused)
		return
	qa_speed_multiplier = clampf(multiplier, 0.25, 10.0)
	_qa_apply_player_settings()
	ui.set_qa_notice("Player speed set to ×%s." % int(qa_speed_multiplier))
	_qa_update_diagnostics()


func _qa_apply_player_settings() -> void:
	var allow_offline_tools := not multiplayer.has_multiplayer_peer()
	for player in players.get_children():
		if player.has_method("set_qa_noclip"):
			player.call("set_qa_noclip", qa_noclip and allow_offline_tools)
		if player.has_method("set_qa_speed_multiplier"):
			player.call("set_qa_speed_multiplier", qa_speed_multiplier if allow_offline_tools else 1.0)


func _qa_set_monsters_paused(paused: bool) -> void:
	if paused and not _qa_require_offline("Pause monsters"):
		qa_monsters_paused = false
		ui.configure_qa_mode(_get_qa_level_entries(), current_level_scene.resource_path, qa_invulnerable, qa_noclip, qa_speed_multiplier, false)
		return
	qa_monsters_paused = paused
	_qa_apply_monster_pause()
	ui.set_qa_notice("Monster AI %s." % ("paused" if paused else "running"))
	_qa_update_diagnostics()


func _qa_apply_monster_pause() -> void:
	if not level:
		return
	for monster in _get_level_monsters():
		var instance_id := monster.get_instance_id()
		if qa_monsters_paused:
			if not qa_monster_process_modes.has(instance_id):
				qa_monster_process_modes[instance_id] = monster.process_mode
			monster.process_mode = Node.PROCESS_MODE_DISABLED
		elif qa_monster_process_modes.has(instance_id):
			monster.process_mode = int(qa_monster_process_modes[instance_id])
			qa_monster_process_modes.erase(instance_id)


func _qa_get_controlled_player() -> Node3D:
	for player in players.get_children():
		if player is Node3D and player.has_method("has_control") and bool(player.call("has_control")):
			return player as Node3D
	return null


func _qa_move_player(target_position: Vector3, target_yaw := NAN) -> void:
	var player := _qa_get_controlled_player()
	if not player:
		ui.set_qa_notice("No controlled player is currently spawned.", true)
		return
	player.global_position = target_position
	if is_finite(target_yaw):
		player.rotation.y = target_yaw
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	if player.has_method("reset_remote_sync_tracking"):
		player.call("reset_remote_sync_tracking")
	_qa_update_diagnostics()


func _qa_teleport_to_spawn() -> void:
	if not _qa_require_offline("Teleport"):
		return
	var spawn_positions := _get_spawn_positions()
	if spawn_positions.is_empty():
		ui.set_qa_notice("This level has no spawn marker.", true)
		return
	_qa_move_player(spawn_positions[0], _get_spawn_yaw())
	ui.set_qa_notice("Teleported to the primary spawn.")


func _qa_teleport_to_exit() -> void:
	if not _qa_require_offline("Teleport"):
		return
	if not level_exit:
		ui.set_qa_notice("This level has no discoverable exit.", true)
		return
	var safe_position := level_exit.global_position + level_exit.global_basis.z * 2.5 + Vector3.UP * 0.2
	_qa_move_player(safe_position)
	ui.set_qa_notice("Teleported near the exit.")


func _qa_open_exit() -> void:
	if not _qa_require_offline("Open exit"):
		return
	if not level_exit:
		ui.set_qa_notice("This level has no discoverable exit.", true)
		return
	_open_level_exit()
	ui.set_qa_notice("Exit forced open.")
	_qa_update_diagnostics()


func _qa_complete_objectives() -> void:
	if not _qa_require_offline("Complete objectives"):
		return
	var pending_notes := _get_level_notes().duplicate()
	for note in pending_notes:
		if not is_instance_valid(note):
			continue
		_collect_note(str(note.name), str(note.get("note_text")))
	for plate in _get_level_pressure_plates():
		if plate.has_method("set_synced_active"):
			plate.call("set_synced_active", true)
	for breaker in level.find_children("GeneratedBreakerTrigger*", "Area3D", true, false):
		if breaker.has_method("trigger_outage"):
			breaker.call("trigger_outage")
	if current_level_scene == FOURTH_ROOM_SCENE:
		monster_journal.unlock()
		for entry_id in ["listener", "watcher", "mimic"]:
			for fact_index in range(1, int(monster_journal.get_fact_total(entry_id)) + 1):
				monster_journal.discover(entry_id, fact_index)
		ui.set_journal_available(true)
	_evaluate_level_exit_unlock()
	_open_level_exit()
	_update_objective()
	_update_hud("QA completed the current objectives.")
	ui.set_qa_notice("Records, mechanics, journal gates, and exit completed.")
	_qa_update_diagnostics()


func _qa_update_diagnostics() -> void:
	if network.is_dedicated_server() or not ui or not current_level_scene:
		return
	var player := _qa_get_controlled_player()
	var position_text := "not spawned"
	if player:
		position_text = "%.1f, %.1f, %.1f" % [player.global_position.x, player.global_position.y, player.global_position.z]
	var exit_text := "missing"
	if level_exit:
		exit_text = "OPEN" if _is_level_exit_open() else "closed"
	var network_text := "online (commands locked)" if multiplayer.has_multiplayer_peer() else "offline"
	ui.set_qa_diagnostics(
		"Scene: %s\nPath: %s\nPlayer: %s\nRecords: %s/%s • Exit: %s\nMode: %s • God: %s • Fly: %s • Speed: ×%s • AI: %s" % [
			_get_level_title(),
			current_level_scene.resource_path,
			position_text,
			collected_notes,
			total_notes,
			exit_text,
			network_text,
			"ON" if qa_invulnerable else "off",
			"ON" if qa_noclip else "off",
			int(qa_speed_multiplier),
			"PAUSED" if qa_monsters_paused else "running",
		]
	)


#endregion

#region Level loading and local-state synchronization

func _spawn_current_players() -> void:
	if not multiplayer.has_multiplayer_peer():
		_spawn_player(1)
		return
	if not _is_network_server():
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
	if not _is_network_server():
		return

	var spawn_index := 0
	if not network.is_dedicated_server():
		_move_player_to_spawn(multiplayer.get_unique_id(), spawn_positions[spawn_index % spawn_positions.size()])
		spawn_index += 1
	for peer_id in multiplayer.get_peers():
		_move_player_to_spawn(peer_id, spawn_positions[spawn_index % spawn_positions.size()])
		spawn_index += 1


func _move_player_to_spawn(peer_id: int, spawn_position: Vector3) -> void:
	var spawn_yaw := _get_spawn_yaw()
	if multiplayer.has_multiplayer_peer():
		_move_player_to_spawn_remote.rpc(peer_id, spawn_position, spawn_yaw)
	_move_player_to_spawn_remote(peer_id, spawn_position, spawn_yaw)


@rpc("authority", "call_remote", "reliable")
func _move_player_to_spawn_remote(peer_id: int, spawn_position: Vector3, spawn_yaw: float) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if not player:
		return

	player.global_position = spawn_position
	player.rotation.y = spawn_yaw
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	if player.has_method("reset_remote_sync_tracking"):
		player.reset_remote_sync_tracking()
	if player.has_method("set_controls_enabled"):
		player.set_controls_enabled(true)


func _load_level_scene(scene: PackedScene) -> void:
	if monster_activation_feedback_timer:
		monster_activation_feedback_timer.stop()
	pending_activation_monster = null
	last_recovered_record_text = ""
	if level:
		remove_child(level)
		level.queue_free()
	qa_monster_process_modes.clear()

	level = scene.instantiate()
	current_level_scene = scene
	level.name = "Level"
	add_child(level)
	move_child(level, players.get_index())
	if not network.is_dedicated_server():
		day_night_cycle.set_target_level(level)
	if audio_cues.has_method("play_ambience"):
		audio_cues.play_ambience(current_level_scene.resource_path)
	notes = level.get_node("Notes")
	level_exit = level.find_child("LevelExit", true, false) as Area3D
	_connect_level_interactables()
	_qa_apply_monster_pause()
	if not network.is_dedicated_server():
		ui.set_qa_current_scene(current_level_scene.resource_path)
	var behavior_shift := _apply_journal_difficulty()
	_notify_monsters_note_progress()
	_update_level_hint()
	_update_objective()
	if started:
		_show_level_banner()
		if behavior_shift != "" and not network.is_dedicated_server():
			ui.set_status(behavior_shift)


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
		HOUSE_BUILDER_DEMO_SCENE.resource_path:
			return HOUSE_BUILDER_DEMO_SCENE
		UNLIT_EVIDENCE_DEMO_SCENE.resource_path:
			return UNLIT_EVIDENCE_DEMO_SCENE
		CORRIDOR_SCENE.resource_path:
			return CORRIDOR_SCENE
		FOURTH_ROOM_SCENE.resource_path:
			return FOURTH_ROOM_SCENE
		_:
			var branch_scene := BranchCatalog.find_scene_by_path(scene_path)
			if branch_scene != null:
				return branch_scene
			push_warning("Unknown level scene path in session sync: %s" % scene_path)
			return null


func _get_level_marker_positions(prefix: String) -> Array:
	return LEVEL_RUNTIME_QUERY.marker_positions(level, prefix)


func _get_level_notes() -> Array:
	return LEVEL_RUNTIME_QUERY.notes(level)


func _get_level_monsters() -> Array:
	return LEVEL_RUNTIME_QUERY.monsters(level)


func _get_level_pressure_plates() -> Array:
	return LEVEL_RUNTIME_QUERY.pressure_plates(level)


func _get_pressure_plate_states() -> Dictionary:
	return LEVEL_RUNTIME_QUERY.pressure_plate_states(level)


func _apply_pressure_plate_states(states: Dictionary) -> void:
	LEVEL_RUNTIME_QUERY.apply_pressure_plate_states(level, states)


func _get_monster_activation_states() -> Dictionary:
	return LEVEL_RUNTIME_QUERY.monster_activation_states(level)


func _apply_monster_activation_states(states: Dictionary) -> void:
	LEVEL_RUNTIME_QUERY.apply_monster_activation_states(level, states)


#endregion

#region Server-authoritative monster simulation

@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_online_monster_states(states: Dictionary) -> void:
	if not level:
		return
	for source_id in states:
		var monster := level.get_node_or_null(str(source_id))
		if (
			monster
			and monster.has_method("apply_authoritative_state")
			and states[source_id] is Dictionary
		):
			monster.call("apply_authoritative_state", states[source_id])


func _get_online_monster_snapshot(state: Dictionary) -> Dictionary:
	var level_path := str(state.get("level_path", ""))
	var definitions: Dictionary = SESSION_MONSTER_DEFINITIONS.get(level_path, {})
	if definitions.is_empty():
		state["monster_states"] = {}
		return {}
	var stored_states: Dictionary = state.get("monster_states", {})
	var snapshot := {}
	for source_id in definitions:
		var definition: Dictionary = definitions[source_id]
		var stored: Dictionary = stored_states.get(str(source_id), {})
		var position: Vector3 = definition["spawn_position"]
		var stored_position: Variant = stored.get("position", position)
		if stored_position is Vector3 and (stored_position as Vector3).is_finite():
			position = stored_position
		snapshot[str(source_id)] = {
			"position": position,
			"illuminated": bool(stored.get("illuminated", false)),
		}
	state["monster_states"] = snapshot.duplicate(true)
	return snapshot.duplicate(true)


func _server_step_online_monsters(
	state: Dictionary,
	delta: float,
	now_msec := -1
) -> bool:
	var level_path := str(state.get("level_path", ""))
	var definitions: Dictionary = SESSION_MONSTER_DEFINITIONS.get(level_path, {})
	if definitions.is_empty():
		return false
	var timestamp := int(Time.get_ticks_msec()) if now_msec < 0 else int(now_msec)
	var monster_states := _get_online_monster_snapshot(state)
	for source_id in definitions:
		var definition: Dictionary = definitions[source_id]
		var previous_state: Dictionary = monster_states[str(source_id)]
		var position: Vector3 = previous_state["position"]
		var illuminated := _is_online_monster_illuminated(
			state,
			definition,
			position,
			timestamp
		)
		if illuminated and not bool(previous_state.get("illuminated", false)):
			_apply_discovery_to_online_session(
				state,
				false,
				str(definition.get("journal_entry_id", "")),
				int(definition.get("journal_fact_index_on_observation", 0))
			)
		if not illuminated:
			var target := _find_online_monster_target(state, position)
			if target:
				position = _advance_online_monster_toward(
					position,
					target.global_position,
					definition,
					maxf(delta, 0.0)
				)
		monster_states[str(source_id)] = {
			"position": position,
			"illuminated": illuminated,
		}
		_server_update_online_monster_contacts(
			state,
			str(source_id),
			definition,
			position
		)
	state["monster_states"] = monster_states
	return true


func _server_update_online_monster_contacts(
	state: Dictionary,
	source_id: String,
	definition: Dictionary,
	monster_position: Vector3
) -> void:
	var all_latches: Dictionary = state.get("monster_kill_latches", {})
	var previous_latches: Array = all_latches.get(source_id, [])
	var current_latches := []
	var session_id := str(state.get("id", ""))
	var kill_radius := maxf(float(definition.get("kill_radius", 0.0)), 0.0)
	for candidate in players.get_children():
		if not candidate is Node3D or str(candidate.get("session_id")) != session_id:
			continue
		var candidate_position := (candidate as Node3D).global_position
		var horizontal_distance := Vector2(
			candidate_position.x - monster_position.x,
			candidate_position.z - monster_position.z
		).length()
		if horizontal_distance > kill_radius or absf(candidate_position.y - monster_position.y) > 2.0:
			continue
		var peer_id := int(candidate.get("player_id"))
		current_latches.append(peer_id)
		if previous_latches.has(peer_id):
			continue
		var reason := str(definition.get("death_reason", "Something in the house reached you"))
		_log_server_event("session_monster_contact", {
			"session_id": session_id,
			"source_id": source_id,
			"peer_id": peer_id,
		})
		if _is_network_server():
			_record_account_death(peer_id, source_id)
			_apply_online_player_death.rpc_id(peer_id, reason)
	all_latches[source_id] = current_latches
	state["monster_kill_latches"] = all_latches


@rpc("authority", "call_remote", "reliable")
func _apply_online_player_death(reason: String) -> void:
	if started:
		_apply_player_death(reason, true)


func _find_online_monster_target(state: Dictionary, origin: Vector3) -> Node3D:
	var nearest: Node3D
	var nearest_distance := INF
	var session_id := str(state.get("id", ""))
	for candidate in players.get_children():
		if not candidate is Node3D or str(candidate.get("session_id")) != session_id:
			continue
		var distance := origin.distance_squared_to((candidate as Node3D).global_position)
		if distance < nearest_distance:
			nearest = candidate as Node3D
			nearest_distance = distance
	return nearest


func _is_online_monster_illuminated(
	state: Dictionary,
	definition: Dictionary,
	monster_position: Vector3,
	now_msec: int
) -> bool:
	var target_point := monster_position + Vector3.UP * 0.55
	var session_id := str(state.get("id", ""))
	for candidate in players.get_children():
		if not candidate is Node3D or str(candidate.get("session_id")) != session_id:
			continue
		var flashlight := candidate.get_node_or_null("Head/Flashlight") as Node3D
		if not flashlight:
			continue
		if _is_server_spotlight_holding(
			definition,
			flashlight.global_position,
			-flashlight.global_basis.z,
			float(definition.get("flashlight_range", 0.0)),
			float(definition.get("flashlight_angle", 0.0)),
			target_point
		):
			return true

	var pressure_states: Dictionary = state.get("pressure_plate_states", {})
	var mechanic_states: Dictionary = state.get("level_mechanic_states", {})
	var work_lights: Array = definition.get("work_lights", [])
	for work_light: Dictionary in work_lights:
		var source_id := str(work_light.get("source_id", ""))
		var power_source_id := str(work_light.get("power_source_id", ""))
		if not bool(pressure_states.get(power_source_id, false)):
			continue
		var light_state: Dictionary = mechanic_states.get(source_id, {})
		if int(light_state.get("outage_deadline_msec", 0)) > now_msec:
			continue
		var origin: Vector3 = work_light["position"]
		var aim_position: Vector3 = work_light["aim_position"]
		if _is_server_spotlight_holding(
			definition,
			origin,
			aim_position - origin,
			float(work_light.get("range", 0.0)),
			float(work_light.get("angle", 0.0)),
			target_point
		):
			return true
	return false


func _is_server_spotlight_holding(
	definition: Dictionary,
	origin: Vector3,
	forward: Vector3,
	spot_range: float,
	spot_angle: float,
	target: Vector3
) -> bool:
	if (
		not origin.is_finite()
		or not forward.is_finite()
		or not target.is_finite()
		or forward.length_squared() <= 0.001
	):
		return false
	var offset := target - origin
	var distance := offset.length()
	if distance <= 0.01 or distance > maxf(spot_range, 0.0):
		return false
	var margin := float(definition.get("beam_edge_margin_degrees", 0.0))
	var safe_angle := maxf(spot_angle - margin, 1.0)
	if forward.normalized().dot(offset / distance) < cos(deg_to_rad(safe_angle)):
		return false
	return _is_session_grid_line_clear(definition, origin, target)


func _is_session_grid_line_clear(
	definition: Dictionary,
	origin: Vector3,
	target: Vector3
) -> bool:
	var rows := _get_session_layout_rows(str(definition.get("layout", "")))
	var cell_size := maxf(float(definition.get("cell_size", 1.0)), 1.0)
	var horizontal_distance := Vector2(target.x - origin.x, target.z - origin.z).length()
	var sample_count := maxi(ceili(horizontal_distance / (cell_size * 0.2)), 1)
	for index in range(1, sample_count):
		var sample := origin.lerp(target, float(index) / float(sample_count))
		if not _is_session_layout_cell_walkable(
			rows,
			Vector2i(roundi(sample.x / cell_size), roundi(sample.z / cell_size))
		):
			return false
	return true


func _advance_online_monster_toward(
	position: Vector3,
	target_position: Vector3,
	definition: Dictionary,
	delta: float
) -> Vector3:
	var rows := _get_session_layout_rows(str(definition.get("layout", "")))
	var cell_size := maxf(float(definition.get("cell_size", 1.0)), 1.0)
	var start_cell := Vector2i(roundi(position.x / cell_size), roundi(position.z / cell_size))
	var target_cell := Vector2i(
		roundi(target_position.x / cell_size),
		roundi(target_position.z / cell_size)
	)
	if (
		not _is_session_layout_cell_walkable(rows, start_cell)
		or not _is_session_layout_cell_walkable(rows, target_cell)
	):
		return position
	var next_target := target_position
	next_target.y = position.y
	if start_cell != target_cell:
		var next_cell := _get_next_session_layout_cell(rows, start_cell, target_cell)
		if next_cell == start_cell:
			return position
		next_target = Vector3(next_cell.x * cell_size, position.y, next_cell.y * cell_size)
	var offset := next_target - position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= 0.001:
		return position
	var step_distance := minf(
		maxf(float(definition.get("move_speed", 0.0)), 0.0) * delta,
		distance
	)
	return position + offset / distance * step_distance


func _get_next_session_layout_cell(
	rows: PackedStringArray,
	start_cell: Vector2i,
	target_cell: Vector2i
) -> Vector2i:
	var frontier: Array[Vector2i] = [start_cell]
	var came_from := {start_cell: start_cell}
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == target_cell:
			break
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = current + offset
			if came_from.has(neighbor) or not _is_session_layout_cell_walkable(rows, neighbor):
				continue
			came_from[neighbor] = current
			frontier.append(neighbor)
	if not came_from.has(target_cell):
		return start_cell
	var step := target_cell
	while came_from[step] != start_cell:
		step = came_from[step]
	return step


func _get_session_layout_rows(layout: String) -> PackedStringArray:
	var rows := PackedStringArray()
	for raw_row in layout.split("\n"):
		var row := raw_row.strip_edges()
		if not row.is_empty():
			rows.append(row)
	return rows


func _is_session_layout_cell_walkable(
	rows: PackedStringArray,
	cell: Vector2i
) -> bool:
	if cell.y < 0 or cell.y >= rows.size():
		return false
	var row := rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return false
	return row.substr(cell.x, 1) != "#"


func _broadcast_online_monster_states(state: Dictionary) -> void:
	var snapshot := _get_online_monster_snapshot(state)
	if snapshot.is_empty():
		return
	for member_id in state.get("members", []):
		_apply_online_monster_states.rpc_id(int(member_id), snapshot)


#endregion

#region Mechanic synchronization and UI presentation

func _get_level_mechanic_states() -> Dictionary:
	return LEVEL_RUNTIME_QUERY.mechanic_states(level)


func _get_online_mechanic_snapshot(state: Dictionary, now_msec := -1) -> Dictionary:
	var snapshot: Dictionary = (state.get("level_mechanic_states", {}) as Dictionary).duplicate(true)
	var level_path := str(state.get("level_path", ""))
	var definitions: Dictionary = SESSION_BREAKER_DEFINITIONS.get(level_path, {})
	var timestamp := int(Time.get_ticks_msec()) if now_msec < 0 else int(now_msec)
	for breaker_id in definitions:
		var definition: Dictionary = definitions[breaker_id]
		var breaker_state: Dictionary = snapshot.get(str(breaker_id), {})
		if not breaker_state.is_empty():
			snapshot[str(breaker_id)] = {
				"triggered": bool(breaker_state.get("triggered", false)),
			}
		var work_light_id := str(definition["work_light_id"])
		var work_light_state: Dictionary = snapshot.get(work_light_id, {})
		if work_light_state.has("outage_deadline_msec"):
			var remaining_msec := maxi(
				int(work_light_state["outage_deadline_msec"]) - timestamp,
				0
			)
			snapshot[work_light_id] = {
				"outage_remaining": float(remaining_msec) / 1000.0,
			}
	return snapshot


@rpc("authority", "call_remote", "reliable")
func _apply_level_mechanic_states(states: Dictionary) -> void:
	LEVEL_RUNTIME_QUERY.apply_mechanic_states(level, states)


func _notify_monsters_note_progress() -> void:
	for monster in _get_level_monsters():
		if monster.has_method("set_note_progress"):
			monster.set_note_progress(collected_notes, total_notes)


func _refresh_pressure_plates() -> void:
	for plate in _get_level_pressure_plates():
		if plate.has_method("refresh_state"):
			plate.refresh_state()


func _get_note_by_id(note_id: String) -> Node:
	return LEVEL_RUNTIME_QUERY.note_by_id(level, note_id)


func _is_level_exit_open() -> bool:
	if not level_exit:
		return false
	return not bool(level_exit.get("closed"))


func _are_pressure_plates_satisfied() -> bool:
	return LEVEL_RUNTIME_QUERY.pressure_plates_satisfied(level)


func _are_breaker_requirements_satisfied() -> bool:
	if current_level_scene != UNLIT_EVIDENCE_DEMO_SCENE:
		return true
	var breakers := level.find_children("GeneratedBreakerTrigger*", "Area3D", true, false)
	if breakers.is_empty():
		return false
	for breaker in breakers:
		if not breaker.has_method("is_triggered") or not bool(breaker.call("is_triggered")):
			return false
	return true


func _update_level_hint() -> void:
	if current_level_scene == CORRIDOR_SCENE:
		ui.set_extra_hint("Use sprint key to run")
	else:
		ui.set_extra_hint("")


func _update_hud(last_note := "") -> void:
	ui.update_hud(collected_notes, total_notes, last_note)


func _update_objective() -> void:
	if network.is_dedicated_server():
		return

	var objective := ""
	if current_level_scene == LEVEL_SCENE:
		objective = "The Listener is behind you. Recover two records along the route and cross the narrow doorway."
	elif current_level_scene == NEXT_PLACE_SCENE:
		if collected_notes >= total_notes and total_notes > 0 and not _are_pressure_plates_satisfied():
			objective = "Step on the floor switch to stabilize the copied doorway."
		else:
			objective = "Examine two records about the copied room, then stabilize its doorway."
	elif current_level_scene == BACKROOMS_SCENE:
		if collected_notes >= total_notes and total_notes > 0 and not _are_pressure_plates_satisfied():
			objective = "The yellow exit needs the floor switch before it will hold."
		else:
			objective = "Recover the two yellow-room records. Stay quiet; something wakes as the count rises."
	elif current_level_scene == HOUSE_BUILDER_DEMO_SCENE:
		objective = "Survey the generated hall, compare its two doorways, and recover the room record."
	elif current_level_scene == UNLIT_EVIDENCE_DEMO_SCENE:
		if collected_notes < total_notes:
			objective = "Read the maintenance test before entering the dark service hall."
		elif not _are_breaker_requirements_satisfied():
			objective = "Hold the work light, cross the silhouette, and reach the breaker."
		else:
			objective = "The breaker is spent. Keep a flashlight on the silhouette and reach the exit."
	elif BranchCatalog.find_by_scene(current_level_scene) != null:
		objective = BranchCatalog.find_by_scene(current_level_scene).objective
	elif current_level_scene == CORRIDOR_SCENE:
		objective = "Run the corridor. Sprint only when you can afford to be heard."
	elif current_level_scene == FOURTH_ROOM_SCENE:
		if _is_journal_complete():
			objective = "The field journal is complete. Leave through the final opening."
		else:
			objective = "Verify the Watcher and the pulsing false doorway before choosing an exit."

	if level_exit and _is_level_exit_open():
		if current_level_scene == FOURTH_ROOM_SCENE:
			if _is_journal_complete():
				objective = "The field journal is complete. Leave through the final opening."
		else:
			objective = "The doorway is open. Regroup and enter it."

	ui.set_objective(objective)


func _is_journal_complete() -> bool:
	return monster_journal.unlocked and is_equal_approx(float(monster_journal.get_completion_ratio()), 1.0)


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
	if current_level_scene == HOUSE_BUILDER_DEMO_SCENE:
		return "House Survey: Repeated Hall"
	if current_level_scene == UNLIT_EVIDENCE_DEMO_SCENE:
		return "The Unlit: Maintenance Wing"
	var branch := BranchCatalog.find_by_scene(current_level_scene)
	if branch != null:
		return branch.title
	if current_level_scene == CORRIDOR_SCENE:
		return "Corridor: Do Not Sprint"
	if current_level_scene == FOURTH_ROOM_SCENE:
		return "Final Room: Do Not Stare"
	return "Unknown Room"


func _get_victory_summary() -> String:
	return "You escaped after recovering %s records. The last room lets you leave, but it keeps the shape of your shadow." % session_collected_notes


func _is_network_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _log_server_event(event_name: String, data := {}) -> void:
	if not network.is_dedicated_server() and not _is_network_server():
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

#endregion
