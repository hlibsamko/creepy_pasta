extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")
const NEXT_PLACE_SCENE := preload("res://scenes/next_place.tscn")
const BACKROOMS_SCENE := preload("res://scenes/backrooms/backrooms_builder_demo.tscn")
const UNLIT_EVIDENCE_SCENE := preload("res://scenes/endless_house/unlit_evidence_demo.tscn")
const FOURTH_ROOM_SCENE := preload("res://scenes/fourth_room.tscn")
const BREAKER_TRIGGER_SCENE := preload("res://scenes/common/breaker_outage_trigger_basic.tscn")

var main: Node


func _ready() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	await get_tree().process_frame
	_assert_level_sequence()
	_assert_session_reassignment_cleanup()
	_assert_online_player_reassignment_state()
	await _assert_same_level_session_switch_rebuilds_scene()
	_assert_level_state("initial level", 2, 1, 0, true)
	_assert_active_note_limit("initial level")
	_assert_authoritative_note_copy("initial level")
	_assert_client_discovery_whitelist("initial level")
	_assert_note_gated_monster_definitions("initial level")
	_assert_pressure_plate_definitions("initial level")
	_assert_exit_definition("initial level")
	await _assert_note_collection_guards()
	main.call("_load_level_scene", main.LEVEL_SCENE)
	await get_tree().process_frame
	_assert_opening_rumor_source()
	_assert_opening_chase_layout()
	_assert_plain_note_collection_preserves_input()
	_assert_offline_restart_restores_player()
	main.call("_load_level_scene", main.LEVEL_SCENE)
	await get_tree().process_frame
	await _assert_note_interaction_restores_input()
	await _assert_debug_unlit_preview()
	_assert_debug_house_preview()

	main.call("_load_level_scene", NEXT_PLACE_SCENE)
	await get_tree().process_frame
	_assert_level_state("next place", 2, 0, 1, true)
	_assert_active_note_limit("next place")
	_assert_authoritative_note_copy("next place")
	_assert_client_discovery_whitelist("next place")
	_assert_note_gated_monster_definitions("next place")
	_assert_pressure_plate_definitions("next place")
	_assert_exit_definition("next place")
	_assert_level_dialogue("next place")
	_assert_journal_grant_npc()
	_assert_room_survey_source()
	_assert_mimic_record_source()
	_assert_exit_closes_when_pressure_plate_releases()

	main.call("_load_level_scene", BACKROOMS_SCENE)
	await get_tree().process_frame
	_assert_level_state("backrooms builder", 2, 2, 1, true)
	_assert_active_note_limit("backrooms builder")
	_assert_authoritative_note_copy("backrooms builder")
	_assert_client_discovery_whitelist("backrooms builder")
	_assert_note_gated_monster_definitions("backrooms builder")
	_assert_pressure_plate_definitions("backrooms builder")
	_assert_exit_definition("backrooms builder")
	_assert_backrooms_evidence_records()
	_assert_runtime_evidence_copy()
	_assert_backrooms_chaser_pacing()
	_assert_backrooms_wall_height()
	_assert_level_dialogue("backrooms builder")
	_assert_conflicting_survivor()

	var stale_backrooms_monster: Node = main.get("level").find_child(
		"GeneratedAmbushChaser2",
		true,
		false
	)
	main.call("_load_level_scene", main.HOUSE_BUILDER_DEMO_SCENE)
	_assert_stale_monster_death_ignored(stale_backrooms_monster)
	await get_tree().process_frame
	_assert_level_state("house survey", 1, 1, 0, true)
	_assert_active_note_limit("house survey")
	_assert_authoritative_note_copy("house survey")
	_assert_client_discovery_whitelist("house survey")
	_assert_note_gated_monster_definitions("house survey")
	_assert_pressure_plate_definitions("house survey")
	_assert_exit_definition("house survey")
	_assert_house_production_evidence()

	main.call("_load_level_scene", UNLIT_EVIDENCE_SCENE)
	await get_tree().process_frame
	_assert_level_state("Unlit staged authority", 1, 1, 1, true)
	_assert_active_note_limit("Unlit staged authority")
	_assert_authoritative_note_copy("Unlit staged authority")
	_assert_client_discovery_whitelist("Unlit staged authority")
	_assert_note_gated_monster_definitions("Unlit staged authority")
	_assert_pressure_plate_definitions("Unlit staged authority")
	_assert_exit_definition("Unlit staged authority")
	_assert_unlit_production_copy()
	_assert_unlit_breaker_definitions()
	_assert_unlit_authoritative_deadline()
	_assert_unlit_server_monster_state()

	main.call("_load_level_scene", main.CORRIDOR_SCENE)
	await get_tree().process_frame
	_assert_client_discovery_whitelist("corridor")
	_assert_note_gated_monster_definitions("corridor")
	_assert_exit_definition("corridor")

	main.call("_load_level_scene", FOURTH_ROOM_SCENE)
	await get_tree().process_frame
	_assert_level_state("fourth room", 2, 2, 0, true)
	_assert_active_note_limit("fourth room")
	_assert_authoritative_note_copy("fourth room")
	_assert_client_discovery_whitelist("fourth room")
	_assert_note_gated_monster_definitions("fourth room")
	_assert_exit_definition("fourth room")
	_assert_level_dialogue("fourth room")
	_assert_final_journal_hook()
	_assert_watcher_warning_buffer()
	_assert_mimic_final_sources()
	_assert_journal_completion_gate()
	_assert_optional_environmental_evidence()

	var pressure_states: Dictionary = main.call("_get_pressure_plate_states")
	main.call("_apply_pressure_plate_states", pressure_states)
	var monster_states: Dictionary = main.call("_get_monster_activation_states")
	main.call("_apply_monster_activation_states", monster_states)

	print("[smoke] Main state discovery OK")
	get_tree().quit()


func _assert_level_sequence() -> void:
	main.set("current_level_scene", main.LEVEL_SCENE)
	if main.call("_get_next_level_scene") != NEXT_PLACE_SCENE:
		_fail("Level sequence does not route level -> next_place")
		return
	main.set("current_level_scene", NEXT_PLACE_SCENE)
	if main.call("_get_next_level_scene") != BACKROOMS_SCENE:
		_fail("Level sequence does not route next_place -> backrooms")
		return
	main.set("current_level_scene", BACKROOMS_SCENE)
	if main.call("_get_next_level_scene") != main.HOUSE_BUILDER_DEMO_SCENE:
		_fail("Level sequence does not route backrooms -> house survey")
		return
	main.set("current_level_scene", main.HOUSE_BUILDER_DEMO_SCENE)
	if main.call("_get_next_level_scene") != UNLIT_EVIDENCE_SCENE:
		_fail("Level sequence does not route house survey -> The Unlit")
		return
	if not main.SESSION_LEVEL_PATHS.has(UNLIT_EVIDENCE_SCENE.resource_path):
		_fail("The server-owned Unlit room is missing from the online route")
		return
	main.set("current_level_scene", UNLIT_EVIDENCE_SCENE)
	if main.call("_get_next_level_scene") != main.CORRIDOR_SCENE:
		_fail("Level sequence does not route The Unlit -> corridor")
		return
	main.set("current_level_scene", main.CORRIDOR_SCENE)
	if main.call("_get_next_level_scene") != FOURTH_ROOM_SCENE:
		_fail("Level sequence does not route corridor -> fourth_room")
		return
	main.set("current_level_scene", main.LEVEL_SCENE)


func _assert_session_reassignment_cleanup() -> void:
	const PEER_ID := 9101
	var previous_sessions: Dictionary = main.get("online_sessions")
	var previous_peer_sessions: Dictionary = main.get("peer_session_ids")
	var old_state: Dictionary = main.call("_create_online_session_state", "SMOKE_OLD")
	old_state["members"] = [PEER_ID]
	var next_state: Dictionary = main.call("_create_online_session_state", "SMOKE_NEXT")
	main.set("online_sessions", {
		"SMOKE_OLD": old_state,
		"SMOKE_NEXT": next_state,
	})
	main.set("peer_session_ids", {PEER_ID: "SMOKE_OLD"})

	main.call("_remove_peer_before_online_session_assignment", PEER_ID, "SMOKE_NEXT")
	var sessions_after_move: Dictionary = main.get("online_sessions")
	if sessions_after_move.has("SMOKE_OLD"):
		_fail("Switching sessions leaked an empty hidden server slot")
		return

	var retained_state: Dictionary = main.call("_create_online_session_state", "SMOKE_NEXT")
	retained_state["members"] = [PEER_ID]
	main.set("online_sessions", {"SMOKE_NEXT": retained_state})
	main.set("peer_session_ids", {PEER_ID: "SMOKE_NEXT"})
	main.call("_remove_peer_before_online_session_assignment", PEER_ID, "SMOKE_NEXT")
	if not (main.get("online_sessions") as Dictionary).has("SMOKE_NEXT"):
		_fail("Rejoining the current session deleted its active state")
		return

	var active_state: Dictionary = main.call("_create_online_session_state", "SMOKE_ACTIVE")
	active_state["members"] = [PEER_ID]
	var finished_state: Dictionary = main.call("_create_online_session_state", "SMOKE_FINISHED")
	finished_state["members"] = [PEER_ID + 1]
	finished_state["finished"] = true
	var empty_state: Dictionary = main.call("_create_online_session_state", "SMOKE_EMPTY")
	main.set("online_sessions", {
		"SMOKE_ACTIVE": active_state,
		"SMOKE_FINISHED": finished_state,
		"SMOKE_EMPTY": empty_state,
	})
	var visible_sessions: Array = main.call("_serialize_online_sessions")
	if visible_sessions.size() != 1 or str(visible_sessions[0].get("id", "")) != "SMOKE_ACTIVE":
		_fail("Session browser exposed an empty or already-finished room")
		return
	if (
		not bool(main.call("_is_online_session_joinable", "SMOKE_ACTIVE"))
		or bool(main.call("_is_online_session_joinable", "SMOKE_FINISHED"))
		or bool(main.call("_is_online_session_joinable", "SMOKE_EMPTY"))
	):
		_fail("Server joinability disagrees with the active-session browser")
		return

	var reconnect_state: Dictionary = main.call("_create_online_session_state", "SMOKE_RESUME")
	reconnect_state["members"] = [PEER_ID]
	main.set("online_sessions", {"SMOKE_RESUME": reconnect_state})
	main.set("peer_session_ids", {PEER_ID: "SMOKE_RESUME"})
	main.call("_remove_peer_from_online_session", PEER_ID, false)
	var retained_sessions: Dictionary = main.get("online_sessions")
	if not retained_sessions.has("SMOKE_RESUME"):
		_fail("A disconnected final player lost the session before reconnect grace")
		return
	var retained_empty: Dictionary = retained_sessions["SMOKE_RESUME"]
	var empty_since_msec := int(retained_empty.get("empty_since_msec", 0))
	if (
		empty_since_msec <= 0
		or not bool(main.call("_is_online_session_reconnectable", "SMOKE_RESUME", empty_since_msec))
	):
		_fail("Retained session did not enter its bounded reconnect window")
		return
	if not (main.call("_serialize_online_sessions") as Array).is_empty():
		_fail("Empty reconnect reservation leaked into the public session browser")
		return
	main.call(
		"_prune_expired_online_sessions",
		empty_since_msec + int(main.SESSION_RECONNECT_GRACE_MSEC)
	)
	if (main.get("online_sessions") as Dictionary).has("SMOKE_RESUME"):
		_fail("Expired reconnect reservation continued consuming a server slot")
		return

	main.set("online_sessions", previous_sessions)
	main.set("peer_session_ids", previous_peer_sessions)


func _assert_online_player_reassignment_state() -> void:
	const PEER_ID := 9102
	var previous_active_session_id := str(main.get("active_session_id"))
	var player_root: Node = main.get("players")
	var existing: Node = player_root.get_node_or_null(str(PEER_ID))
	if existing:
		existing.free()
	main.call(
		"_spawn_player_remote",
		PEER_ID,
		Vector3.ZERO,
		Color.WHITE,
		0.0,
		"SMOKE_OLD"
	)
	var destination := Vector3(4.0, 0.2, 4.8)
	main.call(
		"_move_player_to_online_session_remote",
		PEER_ID,
		destination,
		-PI * 0.5,
		"SMOKE_NEXT"
	)
	var player: Node3D = player_root.get_node(str(PEER_ID))
	if (
		str(player.get("session_id")) != "SMOKE_NEXT"
		or not player.global_position.is_equal_approx(destination)
		or not is_equal_approx(player.rotation.y, -PI * 0.5)
	):
		_fail("Existing player did not move cleanly into its newly assigned session")
		return
	main.set("active_session_id", "SMOKE_NEXT")
	main.call("_update_session_status")
	if str(main.get("ui").session_label.text) != "SMOKE_NEXT | 1 player":
		_fail("Compact HUD session status did not follow player reassignment")
		return
	player.free()
	main.set("active_session_id", previous_active_session_id)
	main.call("_update_session_status")


func _assert_same_level_session_switch_rebuilds_scene() -> void:
	var first_session_notes: Array[String] = ["Note1"]
	var clean_session_notes: Array[String] = []
	var empty_journal: Dictionary = main.call("_create_empty_journal_snapshot")
	main.set("active_session_id", "SMOKE_OLD")
	main.call(
		"_sync_session_state",
		main.LEVEL_SCENE.resource_path,
		first_session_notes,
		1,
		false,
		{},
		{},
		{},
		{},
		empty_journal,
		"SMOKE_OLD"
	)
	await get_tree().process_frame
	if main.call("_get_note_by_id", "Note1"):
		_fail("Collected owner-session note remained present before clean switch")
		return

	main.call(
		"_sync_session_state",
		main.LEVEL_SCENE.resource_path,
		clean_session_notes,
		0,
		false,
		{},
		{},
		{},
		{},
		empty_journal,
		"SMOKE_NEW"
	)
	await get_tree().process_frame
	if not main.call("_get_note_by_id", "Note1") or int(main.get("collected_notes")) != 0:
		_fail("Same-level clean session did not rebuild its uncollected evidence")
		return
	main.set("active_session_id", "")
	main.set("loaded_session_id", "")
	main.call("_update_session_status")


func _assert_level_state(
	label: String,
	min_notes: int,
	min_monsters: int,
	min_pressure_plates: int,
	needs_exit: bool
) -> void:
	var notes: Array = main.call("_get_level_notes")
	var monsters: Array = main.call("_get_level_monsters")
	var pressure_plates: Array = main.call("_get_level_pressure_plates")
	var spawn_positions: Array = main.call("_get_spawn_positions")
	var level_exit: Variant = main.get("level_exit")
	var has_exit := level_exit != null

	if notes.size() < min_notes:
		_fail("%s has %s notes, expected at least %s" % [label, notes.size(), min_notes])
		return
	if monsters.size() < min_monsters:
		_fail("%s has %s monsters, expected at least %s" % [label, monsters.size(), min_monsters])
		return
	if pressure_plates.size() < min_pressure_plates:
		_fail("%s has %s pressure plates, expected at least %s" % [label, pressure_plates.size(), min_pressure_plates])
		return
	if spawn_positions.is_empty():
		_fail("%s has no spawn positions" % label)
		return
	if needs_exit and not has_exit:
		_fail("%s has no discoverable level exit" % label)


func _assert_active_note_limit(label: String) -> void:
	var active_notes: Array = main.call("_get_level_notes")
	if active_notes.size() > 2:
		_fail("%s has %s active records; test flow allows at most 2" % [label, active_notes.size()])


func _assert_authoritative_note_copy(label: String) -> void:
	var level_scene: PackedScene = main.get("current_level_scene")
	var definitions: Dictionary = main.SESSION_NOTE_DEFINITIONS.get(level_scene.resource_path, {})
	var active_notes: Array = main.call("_get_level_notes")
	if definitions.size() != active_notes.size():
		_fail("%s server note whitelist does not match its active scene records" % label)
		return
	for note in active_notes:
		var note_id := str(note.name)
		if not definitions.has(note_id):
			_fail("%s server whitelist omitted active record %s" % [label, note_id])
			return
		var definition: Dictionary = definitions[note_id]
		if str(definition.get("text", "")) != str(note.get("note_text")):
			_fail("%s online copy differs from scene record %s" % [label, note_id])
			return
		if (
			not definition.has("position")
			or float(definition.get("collection_radius", 0.0)) <= 0.0
		):
			_fail("%s server record has no proximity rule: %s" % [label, note_id])
			return
		var expected_position: Vector3 = definition["position"]
		if (note as Node3D).global_position.distance_to(expected_position) > 0.01:
			_fail("%s server record position drifted: %s" % [label, note_id])
			return


func _assert_client_discovery_whitelist(label: String) -> void:
	var level_scene: PackedScene = main.get("current_level_scene")
	var allowed: Array = main.SESSION_CLIENT_DISCOVERIES.get(level_scene.resource_path, [])
	var level_node := main.get("level") as Node
	var allowed_keys := {}
	for definition: Dictionary in allowed:
		allowed_keys[_get_discovery_key(
			str(definition["source_id"]),
			bool(definition["unlock"]),
			str(definition["entry_id"]),
			int(definition["fact_index"]),
			str(definition["rumor_id"])
		)] = true
		var source := level_node.get_node_or_null(str(definition["source_id"]))
		if not source:
			_fail("%s discovery source is missing: %s" % [label, definition["source_id"]])
			return
		if source is DialogueNpc:
			if (
				not definition.has("position")
				or float(definition.get("interaction_radius", 0.0)) <= 0.0
			):
				_fail("%s dialogue discovery has no server proximity rule: %s" % [label, definition["source_id"]])
				return
			var observation_position: Vector3 = definition["position"]
			if (source as Node3D).global_position.distance_to(observation_position) > 0.01:
				_fail("%s dialogue discovery position drifted: %s" % [label, definition["source_id"]])
				return
		elif source is WatcherMonster or source is MimicDoor or source is LightShyMonster:
			if (
				not definition.has("position")
				or float(definition.get("observation_radius", 0.0)) <= 0.0
			):
				_fail("%s monster observation has no server range rule: %s" % [label, definition["source_id"]])
				return
			var expected_position: Vector3 = definition["position"]
			if (source as Node3D).global_position.distance_to(expected_position) > 0.01:
				_fail("%s monster observation position drifted: %s" % [label, definition["source_id"]])
				return
			if source is WatcherMonster:
				var watcher := source as WatcherMonster
				if float(definition["observation_radius"]) < watcher.trigger_distance:
					_fail("%s Watcher server range is shorter than its gameplay trigger" % label)
					return
				if (
					float(definition.get("facing_dot_min", 2.0)) < 0.75
					or float(definition["facing_dot_min"]) > watcher.gaze_dot_threshold
				):
					_fail("%s Watcher server facing rule drifted from gameplay" % label)
					return
			elif source is MimicDoor:
				var mimic := source as MimicDoor
				if float(definition["observation_radius"]) < mimic.observation_distance:
					_fail("%s False Door server range is shorter than its gameplay trigger" % label)
					return
				if definition.has("facing_dot_min"):
					_fail("%s False Door incorrectly requires facing for proximity evidence" % label)
					return
			elif source is LightShyMonster:
				var unlit := source as LightShyMonster
				if float(definition["observation_radius"]) < 18.0:
					_fail("%s Unlit server range is shorter than the player flashlight" % label)
					return
				if unlit.journal_entry_id != "unlit" or definition.has("facing_dot_min"):
					_fail("%s Unlit observation authority drifted from its beam rule" % label)
					return
		elif definition.has("interaction_radius") or definition.has("observation_radius"):
			_fail("%s discovery has an unsupported proximity rule: %s" % [label, definition["source_id"]])
			return

	var scene_keys := {}
	for source in level_node.find_children("*", "", true, false):
		var source_id := str(level_node.get_path_to(source))
		if source is DialogueNpc:
			var dialogue := source as DialogueNpc
			if dialogue.grants_journal or dialogue.journal_entry_id != "":
				scene_keys[_get_discovery_key(
					source_id,
					dialogue.grants_journal,
					dialogue.journal_entry_id,
					dialogue.journal_fact_index,
					dialogue.journal_rumor_id
				)] = true
		elif source is WatcherMonster:
			var watcher := source as WatcherMonster
			if watcher.journal_entry_id != "" and watcher.journal_fact_index_on_observation > 0:
				scene_keys[_get_discovery_key(
					source_id,
					false,
					watcher.journal_entry_id,
					watcher.journal_fact_index_on_observation,
					""
				)] = true
		elif source is MimicDoor:
			var mimic := source as MimicDoor
			if mimic.journal_entry_id != "" and mimic.journal_fact_index_on_observation > 0:
				scene_keys[_get_discovery_key(
					source_id,
					false,
					mimic.journal_entry_id,
					mimic.journal_fact_index_on_observation,
					""
				)] = true
		elif source is LightShyMonster:
			var unlit := source as LightShyMonster
			if unlit.journal_entry_id != "" and unlit.journal_fact_index_on_observation > 0:
				scene_keys[_get_discovery_key(
					source_id,
					false,
					unlit.journal_entry_id,
					unlit.journal_fact_index_on_observation,
					""
				)] = true

	if allowed_keys != scene_keys:
		_fail(
			"%s client discovery whitelist differs from scene sources: allowed=%s scene=%s"
			% [label, allowed_keys.keys(), scene_keys.keys()]
		)


func _get_discovery_key(
	source_id: String,
	should_unlock: bool,
	entry_id: String,
	fact_index: int,
	rumor_id: String
) -> String:
	return "%s|%s|%s|%d|%s" % [source_id, should_unlock, entry_id, fact_index, rumor_id]


func _assert_note_gated_monster_definitions(label: String) -> void:
	var level_scene: PackedScene = main.get("current_level_scene")
	var definitions: Array = main.SESSION_NOTE_GATED_MONSTERS.get(level_scene.resource_path, [])
	var defined_keys := {}
	for definition: Dictionary in definitions:
		var source_id := str(definition["source_id"])
		defined_keys["%s|%d|%s|%d" % [
			source_id,
			int(definition["notes_required"]),
			str(definition["entry_id"]),
			int(definition["fact_index"]),
		]] = true

	var scene_keys := {}
	var level_node := main.get("level") as Node
	for source in level_node.find_children("*", "", true, false):
		if not source is CorridorMonster:
			continue
		var listener := source as CorridorMonster
		if listener.notes_required_to_activate <= 0:
			continue
		var source_id := str(level_node.get_path_to(listener))
		scene_keys["%s|%d|%s|%d" % [
			source_id,
			listener.notes_required_to_activate,
			listener.journal_entry_id,
			listener.journal_fact_index_on_activation,
		]] = true

	if defined_keys != scene_keys:
		_fail(
			"%s note-gated monster definitions differ from scene sources: definitions=%s scene=%s"
			% [label, defined_keys.keys(), scene_keys.keys()]
		)


func _assert_exit_definition(label: String) -> void:
	var level_scene: PackedScene = main.get("current_level_scene")
	var definition: Dictionary = main.SESSION_EXIT_DEFINITIONS.get(level_scene.resource_path, {})
	var exit := main.get("level_exit") as Node3D
	if definition.is_empty() or not exit:
		_fail("%s has no server exit definition" % label)
		return
	var expected_position: Vector3 = definition["position"]
	if exit.global_position.distance_to(expected_position) > 0.01:
		_fail("%s server exit position drifted" % label)
		return
	if float(definition.get("activation_radius", 0.0)) <= 0.0:
		_fail("%s server exit has no activation radius" % label)


func _assert_pressure_plate_definitions(label: String) -> void:
	var level_scene: PackedScene = main.get("current_level_scene")
	var definitions: Dictionary = main.SESSION_PRESSURE_PLATE_DEFINITIONS.get(
		level_scene.resource_path,
		{}
	)
	var plates: Array = main.call("_get_level_pressure_plates")
	if definitions.size() != plates.size():
		_fail(
			"%s pressure definitions do not match scene plates: definitions=%d scene=%d"
			% [label, definitions.size(), plates.size()]
		)
		return
	var level_node := main.get("level") as Node3D
	for plate in plates:
		var plate_id := str(level_node.get_path_to(plate))
		if not definitions.has(plate_id):
			_fail("%s pressure definitions omitted %s" % [label, plate_id])
			return
		var definition: Dictionary = definitions[plate_id]
		var expected_position: Vector3 = definition["position"]
		if (plate as Node3D).global_position.distance_to(expected_position) > 0.01:
			_fail(
				"%s pressure definition position drifted for %s"
				% [label, plate_id]
			)
			return
		if float(definition.get("activation_radius", 0.0)) <= 0.0:
			_fail("%s pressure definition has no activation radius for %s" % [label, plate_id])
			return


func _assert_unlit_breaker_definitions() -> void:
	var level_node := main.get("level") as Node3D
	var level_path := UNLIT_EVIDENCE_SCENE.resource_path
	var definitions: Dictionary = main.SESSION_BREAKER_DEFINITIONS.get(level_path, {})
	var breakers := level_node.find_children("GeneratedBreakerTrigger*", "Area3D", true, false)
	if definitions.size() != 1 or breakers.size() != 1:
		_fail("Unlit staged breaker definitions do not match the generated scene")
		return
	var breaker := breakers[0] as Node3D
	var breaker_id := str(level_node.get_path_to(breaker))
	if not definitions.has(breaker_id):
		_fail("Unlit staged authority omitted its generated breaker path")
		return
	var definition: Dictionary = definitions[breaker_id]
	var work_light := level_node.get_node_or_null(str(definition.get("work_light_id", "")))
	if (
		breaker.global_position.distance_to(definition["position"]) > 0.01
		or float(definition.get("activation_radius", 0.0)) <= 0.0
		or not work_light
		or breaker.get("powered_light") != work_light
		or not is_equal_approx(
			float(definition.get("outage_duration", 0.0)),
			float(breaker.get("outage_duration"))
		)
		or not breaker.has_signal("outage_requested")
		or not breaker.has_method("set_authoritative_mode")
	):
		_fail("Unlit staged breaker authority drifted from its generated nodes")


func _assert_unlit_production_copy() -> void:
	var title := str(main.call("_get_level_title"))
	if title != "The Unlit: Maintenance Wing" or "prototype" in title.to_lower():
		_fail("The production Unlit room still exposes prototype title copy")


func _assert_unlit_authoritative_deadline() -> void:
	_assert_unlit_breaker_deadline_body()


func _assert_unlit_server_monster_state() -> void:
	main.call("_clear_players")
	main.call("_spawn_player", 1)
	var player := main.get("players").get_node_or_null("1") as Node3D
	var level_node := main.get("level") as Node3D
	var monster := level_node.find_child(
		"GeneratedLightShyMonster1",
		true,
		false
	) as LightShyMonster
	if not player or not monster:
		_fail("Unlit server state smoke could not create its player and creature")
		return
	player.set("session_id", "SMOKE_UNLIT_MONSTER")
	var level_path := UNLIT_EVIDENCE_SCENE.resource_path
	var definitions: Dictionary = main.SESSION_MONSTER_DEFINITIONS.get(level_path, {})
	var monster_id := str(level_node.get_path_to(monster))
	if definitions.size() != 1 or not definitions.has(monster_id):
		_fail("Unlit server authority does not whitelist its exact generated creature")
		return
	var definition: Dictionary = definitions[monster_id]
	var builder := level_node.get_node("EndlessHouseBuilder") as BackroomsBuilder
	var flashlight := player.get_node("Head/Flashlight") as SpotLight3D
	var work_light_definition: Dictionary = (definition["work_lights"] as Array)[0]
	var work_light := level_node.get_node(str(work_light_definition["source_id"])) as SpotLight3D
	if (
		monster.global_position.distance_to(definition["spawn_position"]) > 0.01
		or not is_equal_approx(float(definition["move_speed"]), monster.move_speed)
		or float(definition.get("kill_radius", 0.0)) < 0.9
		or str(definition.get("death_reason", "")) != monster.death_reason
		or str(definition["layout"]) != builder.layout
		or not is_equal_approx(float(definition["cell_size"]), builder.cell_size)
		or not is_equal_approx(float(definition["flashlight_range"]), flashlight.spot_range)
		or not is_equal_approx(float(definition["flashlight_angle"]), flashlight.spot_angle)
		or not work_light
		or work_light.global_position.distance_to(work_light_definition["position"]) > 0.01
		or not is_equal_approx(float(work_light_definition["range"]), work_light.spot_range)
		or not is_equal_approx(float(work_light_definition["angle"]), work_light.spot_angle)
	):
		_fail("Unlit server simulation constants drifted from the generated chamber")
		return

	var state := {
		"id": "SMOKE_UNLIT_MONSTER",
		"level_path": level_path,
		"collected_note_ids": [],
		"session_collected_notes": 0,
		"exit_open": false,
		"pressure_plate_states": {},
		"monster_activation_states": {},
		"level_mechanic_states": {},
		"monster_states": {},
		"journal_state": main.call("_create_empty_journal_snapshot"),
		"members": [],
		"finished": false,
	}
	const START_MSEC := 200000
	player.global_position = Vector3(4.0, 0.2, 4.0)
	player.look_at(Vector3(4.0, 0.2, 12.0), Vector3.UP)
	if not bool(main.call("_server_step_online_monsters", state, 1.0, START_MSEC)):
		_fail("Unlit server did not recognize its staged level")
		return
	var first_state: Dictionary = (state["monster_states"] as Dictionary)[monster_id]
	var first_position: Vector3 = first_state["position"]
	if (
		bool(first_state["illuminated"])
		or not is_equal_approx(
			first_position.distance_to(definition["spawn_position"]),
			float(definition["move_speed"])
		)
	):
		_fail("Unlit server movement did not advance at its bounded authored speed")
		return

	state["monster_states"] = {}
	player.global_position = Vector3(16.0, 0.2, 20.0)
	player.look_at(Vector3(24.0, 0.2, 20.0), Vector3.UP)
	main.call("_server_step_online_monsters", state, 1.0, START_MSEC + 1000)
	var held_state: Dictionary = (state["monster_states"] as Dictionary)[monster_id]
	if (
		not bool(held_state["illuminated"])
		or (held_state["position"] as Vector3).distance_to(definition["spawn_position"]) > 0.001
	):
		_fail("Unlit server did not hold the creature inside a player's clear flashlight beam")
		return
	var journal := MonsterJournal.new()
	journal.reset()
	journal.apply_snapshot(state["journal_state"])
	var observation_recorded := journal.has_fact("unlit", 2)
	journal.free()
	if not observation_recorded:
		_fail("Unlit server illumination did not grant its direct-observation fact")
		return

	state["monster_states"] = {}
	player.global_position = Vector3(24.0, 0.2, 4.0)
	player.look_at(Vector3(24.0, 0.2, 20.0), Vector3.UP)
	main.call("_server_step_online_monsters", state, 0.5, START_MSEC + 2000)
	var occluded_state: Dictionary = (state["monster_states"] as Dictionary)[monster_id]
	if (
		bool(occluded_state["illuminated"])
		or (occluded_state["position"] as Vector3).distance_to(definition["spawn_position"]) <= 0.1
	):
		_fail("Unlit server flashlight crossed solid layout walls")
		return

	player.set("session_id", "SMOKE_OTHER_SESSION")
	state["monster_states"] = {}
	var pressure_states: Dictionary = state["pressure_plate_states"]
	pressure_states[str(work_light_definition["power_source_id"])] = true
	state["pressure_plate_states"] = pressure_states
	main.call("_server_step_online_monsters", state, 1.0, START_MSEC + 3000)
	var work_light_state: Dictionary = (state["monster_states"] as Dictionary)[monster_id]
	if (
		not bool(work_light_state["illuminated"])
		or (work_light_state["position"] as Vector3).distance_to(definition["spawn_position"]) > 0.001
	):
		_fail("Unlit server work light did not hold the staged creature")
		return

	state["monster_states"] = {}
	state["level_mechanic_states"] = {
		str(work_light_definition["source_id"]): {
			"outage_deadline_msec": START_MSEC + 8000,
		},
	}
	player.set("session_id", "SMOKE_UNLIT_MONSTER")
	player.global_position = Vector3(4.0, 0.2, 4.0)
	player.look_at(Vector3(4.0, 0.2, 12.0), Vector3.UP)
	main.call("_server_step_online_monsters", state, 1.0, START_MSEC + 4000)
	var outage_state: Dictionary = (state["monster_states"] as Dictionary)[monster_id]
	if (
		bool(outage_state["illuminated"])
		or (outage_state["position"] as Vector3).distance_to(definition["spawn_position"]) <= 0.1
	):
		_fail("Unlit server outage left the work light active")
		return

	state["monster_states"] = {}
	main.call("_server_step_online_monsters", state, 1.0, START_MSEC + 9000)
	var recovered_state: Dictionary = (state["monster_states"] as Dictionary)[monster_id]
	if not bool(recovered_state["illuminated"]):
		_fail("Unlit server work light did not recover after its absolute outage deadline")
		return

	var isolated_state := state.duplicate(true)
	isolated_state["id"] = "SMOKE_EMPTY_SESSION"
	isolated_state["monster_states"] = {}
	isolated_state["pressure_plate_states"] = {}
	main.call("_server_step_online_monsters", isolated_state, 1.0, START_MSEC + 10000)
	var isolated_monster: Dictionary = (isolated_state["monster_states"] as Dictionary)[monster_id]
	if (isolated_monster["position"] as Vector3).distance_to(definition["spawn_position"]) > 0.001:
		_fail("Unlit server targeted a player from another online session")
		return

	state["monster_states"] = {}
	state["pressure_plate_states"] = {}
	state["level_mechanic_states"] = {}
	player.set("session_id", "SMOKE_UNLIT_MONSTER")
	player.global_position = definition["spawn_position"] + Vector3.UP * 0.2
	main.call("_server_step_online_monsters", state, 0.1, START_MSEC + 11000)
	var contact_latches: Dictionary = state.get("monster_kill_latches", {})
	var contact_peers: Array = contact_latches.get(monster_id, [])
	if contact_peers != [1]:
		_fail("Unlit server contact did not latch the matching session player exactly once")
		return
	main.call("_server_step_online_monsters", state, 0.1, START_MSEC + 11100)
	contact_peers = (state.get("monster_kill_latches", {}) as Dictionary).get(monster_id, [])
	if contact_peers != [1]:
		_fail("Unlit server contact latch duplicated a sustained collision")
		return
	player.global_position = Vector3(4.0, 0.2, 4.0)
	main.call("_server_step_online_monsters", state, 0.1, START_MSEC + 11200)
	contact_peers = (state.get("monster_kill_latches", {}) as Dictionary).get(monster_id, [])
	if not contact_peers.is_empty():
		_fail("Unlit server contact latch survived separation/respawn distance")
		return

	main.call("_reset_online_monster_runtime_state", state)
	if (
		not (state["monster_states"] as Dictionary).is_empty()
		or not (state["monster_kill_latches"] as Dictionary).is_empty()
	):
		_fail("Unlit Restart did not clear creature position and contact latches")
		return
	var restart_snapshot: Dictionary = main.call("_get_online_monster_snapshot", state)
	var expected_restart_state: Dictionary = restart_snapshot[monster_id]
	main.call("_apply_online_monster_states", restart_snapshot)
	if (
		not monster.is_authoritative_state_enabled()
		or monster.global_position.distance_to(expected_restart_state["position"]) > 0.001
		or monster.is_illuminated() != bool(expected_restart_state["illuminated"])
	):
		_fail("Unlit Restart/late-join snapshot did not restore authoritative client state")
	main.call("_clear_players")


func _assert_unlit_breaker_deadline_body() -> void:
	main.call("_clear_players")
	main.call("_spawn_player", 1)
	var player := main.get("players").get_node_or_null("1") as Node3D
	if not player:
		_fail("Unlit authority smoke could not create its server-side player")
		return
	player.set("session_id", "SMOKE_UNLIT")
	player.global_position = Vector3(4.0, 0.2, 4.0)
	var level_path := UNLIT_EVIDENCE_SCENE.resource_path
	var definitions: Dictionary = main.SESSION_BREAKER_DEFINITIONS[level_path]
	var breaker_id := str(definitions.keys()[0])
	var definition: Dictionary = definitions[breaker_id]
	var work_light_id := str(definition["work_light_id"])
	var state := {
		"id": "SMOKE_UNLIT",
		"level_path": level_path,
		"collected_note_ids": [],
		"session_collected_notes": 0,
		"exit_open": false,
		"pressure_plate_states": {},
		"monster_activation_states": {},
		"level_mechanic_states": {},
		"journal_state": main.call("_create_empty_journal_snapshot"),
		"members": [],
		"finished": false,
	}
	const START_MSEC := 100000
	if bool(main.call(
		"_server_apply_online_breaker_outage",
		state,
		1,
		breaker_id,
		START_MSEC
	)):
		_fail("Unlit server accepted the real breaker while the player was at spawn")
		return
	if not (state["level_mechanic_states"] as Dictionary).is_empty():
		_fail("Rejected Unlit breaker request still mutated the session")
		return
	player.global_position = Vector3(36.0, 0.2, 20.0)
	if not bool(main.call(
		"_server_apply_online_breaker_outage",
		state,
		1,
		breaker_id,
		START_MSEC
	)):
		_fail("Unlit server rejected a player standing at the real breaker")
		return
	if bool(state["exit_open"]):
		_fail("Unlit breaker opened the exit before the maintenance record")
		return
	var mechanic_states: Dictionary = state["level_mechanic_states"]
	var stored_work_light: Dictionary = mechanic_states.get(work_light_id, {})
	var expected_deadline := START_MSEC + roundi(float(definition["outage_duration"]) * 1000.0)
	if (
		not bool((mechanic_states.get(breaker_id, {}) as Dictionary).get("triggered", false))
		or int(stored_work_light.get("outage_deadline_msec", 0)) != expected_deadline
	):
		_fail("Unlit server did not store spent breaker plus absolute outage deadline")
		return
	state["collected_note_ids"] = ["GeneratedNote1"]
	main.call("_evaluate_online_session_exit", state)
	if not bool(state["exit_open"]):
		_fail("Unlit staged exit did not require both its record and spent breaker")
		return
	var journal := MonsterJournal.new()
	journal.reset()
	journal.apply_snapshot(state["journal_state"])
	var has_breaker_fact := journal.has_fact("unlit", 3)
	journal.free()
	if not has_breaker_fact:
		_fail("Authoritative Unlit breaker did not grant its survival evidence")
		return
	var restart_snapshot: Dictionary = main.call(
		"_get_online_mechanic_snapshot",
		state,
		START_MSEC + 1000
	)
	var late_join_snapshot: Dictionary = main.call(
		"_get_online_mechanic_snapshot",
		state,
		START_MSEC + 4000
	)
	var restart_outage := float((restart_snapshot[work_light_id] as Dictionary)["outage_remaining"])
	var late_join_outage := float((late_join_snapshot[work_light_id] as Dictionary)["outage_remaining"])
	if not is_equal_approx(restart_outage, 2.2) or not is_zero_approx(late_join_outage):
		_fail("Unlit deadline did not derive correct Restart/late-join remaining outage")
		return
	main.call("_apply_level_mechanic_states", restart_snapshot)
	var work_light: Node = main.get("level").get_node_or_null(work_light_id)
	var breaker: Node = main.get("level").get_node_or_null(breaker_id)
	if (
		not work_light
		or not breaker
		or not bool(work_light.call("is_in_outage"))
		or not bool(breaker.call("is_triggered"))
	):
		_fail("Unlit Restart snapshot did not restore active outage and spent breaker")
		return
	main.call("_apply_level_mechanic_states", late_join_snapshot)
	if bool(work_light.call("is_in_outage")) or not bool(breaker.call("is_triggered")):
		_fail("Unlit late join did not expire outage while retaining spent breaker")
		return
	if bool(main.call(
		"_server_apply_online_breaker_outage",
		state,
		1,
		breaker_id,
		START_MSEC + 5000
	)):
		_fail("Unlit one-shot breaker accepted a duplicate authority request")
	main.call("_clear_players")


func _assert_offline_restart_restores_player() -> void:
	_assert_offline_restart_body()


func _assert_stale_monster_death_ignored(stale_monster: Node) -> void:
	if not stale_monster:
		_fail("Stale death smoke could not retain the previous Backrooms monster")
		return
	var previous_reason := str(main.get("last_death_reason"))
	main.set("started", true)
	main.get("ui").hide_death()
	main.call("_on_player_killed", "Stale Backrooms contact", stale_monster)
	if (
		not bool(main.get("started"))
		or main.get("ui").death_panel.visible
		or str(main.get("last_death_reason")) != previous_reason
	):
		_fail("A removed Backrooms monster killed the player in the next level")


func _assert_offline_restart_body() -> void:
	main.call("_reset_session")
	main.call("_start_game")
	main.call("_spawn_player", 1)
	main.call("_on_player_killed", "Smoke death")
	main.call("_retry_after_end")
	var local_player: Node = main.get("players").get_node_or_null("1")
	if not bool(main.get("started")) or not local_player:
		_fail("Offline Restart did not restore a playable local player")
		return
	if main.get("ui").death_panel.visible or not bool(local_player.get("controls_enabled")):
		_fail("Offline Restart left death UI or disabled controls")
	main.call("_reset_session")


func _assert_backrooms_wall_height() -> void:
	var walls: Array[Node] = main.get("level").find_children("BackroomsWallBlock*", "StaticBody3D", true, false)
	if walls.is_empty():
		_fail("Backrooms generated no wall blocks")
		return
	var wall_mesh := walls[0].get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not wall_mesh or wall_mesh.mesh.get_aabb().size.y < 4.1:
		_fail("Backrooms wall blocks are still below the raised 4.2m height")


func _assert_backrooms_evidence_records() -> void:
	var survey_note: Node = main.get("level").find_child("GeneratedNote1", true, false)
	var index_note: Node = main.get("level").find_child("GeneratedNote3", true, false)
	if not survey_note or not index_note:
		_fail("Backrooms did not preserve its two active generated evidence IDs")
		return
	if (
		int(survey_note.get("puzzle_type")) != 0
		or str(survey_note.get("journal_entry_id")) != "house"
		or int(survey_note.get("journal_fact_index")) != 1
		or not str(survey_note.get("note_text")).contains("stayed fixed")
	):
		_fail("Backrooms Match Dots record is not purposeful House survey evidence")
		return
	if (
		int(index_note.get("puzzle_type")) != 2
		or str(index_note.get("journal_entry_id")) != "house"
		or int(index_note.get("journal_fact_index")) != 2
		or not str(index_note.get("note_text")).contains("restart at zero")
	):
		_fail("Backrooms Code Lock record is not purposeful House index evidence")
		return
	if str(survey_note.get("note_text")) == str(index_note.get("note_text")):
		_fail("Backrooms active records still share generic evidence text")
		return
	var definitions: Dictionary = main.SESSION_NOTE_DEFINITIONS.get(
		"res://scenes/backrooms/backrooms_builder_demo.tscn",
		{}
	)
	if (
		(definitions.get("GeneratedNote1", {}) as Dictionary).get("entry_id", "") != "house"
		or int((definitions.get("GeneratedNote1", {}) as Dictionary).get("fact_index", 0)) != 1
		or (definitions.get("GeneratedNote3", {}) as Dictionary).get("entry_id", "") != "house"
		or int((definitions.get("GeneratedNote3", {}) as Dictionary).get("fact_index", 0)) != 2
	):
		_fail("Server whitelist does not match the two Backrooms House records")


func _assert_runtime_evidence_copy() -> void:
	var previous_collected := int(main.get("collected_notes"))
	main.set("collected_notes", 0)
	main.call("_update_objective")
	var record_objective := str(main.get("ui").objective_label.text)
	main.set("collected_notes", int(main.get("total_notes")))
	main.call("_update_objective")
	var switch_objective := str(main.get("ui").objective_label.text)
	main.set("collected_notes", previous_collected)
	var runtime_copy := "%s\n%s\n%s" % [
		record_objective,
		switch_objective,
		main.call("_get_victory_summary"),
	]
	if "fragment" in runtime_copy.to_lower():
		_fail("Runtime objective or victory copy still describes purposeful records as fragments")
		return
	if (
		not record_objective.contains("two yellow-room records")
		or not switch_objective.contains("floor switch")
		or not runtime_copy.contains("recovering")
	):
		_fail("Runtime evidence copy lost its concrete record wording: %s" % runtime_copy)


func _assert_backrooms_chaser_pacing() -> void:
	const PLAYER_SPRINT_SPEED := 5.1
	var regular_chasers: Array[Node] = main.get("level").find_children("GeneratedChaser*", "CharacterBody3D", true, false)
	var ambush_chasers: Array[Node] = main.get("level").find_children("GeneratedAmbushChaser*", "CharacterBody3D", true, false)
	if regular_chasers.size() != 1 or ambush_chasers.size() != 1:
		_fail("Backrooms pacing check could not find both chaser roles")
		return
	var regular: Node = regular_chasers[0]
	var ambush: Node = ambush_chasers[0]
	var regular_sprint_speed := float(regular.get("move_speed")) * float(regular.get("sprint_speed_bonus"))
	var ambush_sprint_speed := float(ambush.get("move_speed")) * float(ambush.get("sprint_speed_bonus"))
	if regular_sprint_speed >= PLAYER_SPRINT_SPEED or ambush_sprint_speed >= PLAYER_SPRINT_SPEED:
		_fail(
			"Backrooms journal scaling made a chaser faster than the player: regular=%.2f ambush=%.2f" % [
				regular_sprint_speed,
				ambush_sprint_speed,
			]
		)
		return
	if ambush_sprint_speed <= regular_sprint_speed:
		_fail("Backrooms chasers lost their smaller late-variant speed difference")


func _assert_house_production_evidence() -> void:
	var survey_note: Node = main.get("level").find_child("GeneratedNote1", true, false)
	if (
		not survey_note
		or str(survey_note.get("journal_entry_id")) != "house"
		or int(survey_note.get("journal_fact_index")) != 3
		or not str(survey_note.get("note_text")).contains("no draft")
		or not str(survey_note.get("note_text")).contains("room tone")
	):
		_fail("Production House survey has no distinct physical-copy evidence")
		return
	var mimic_door: Node = main.get("level").find_child("GeneratedMimicDoor1", true, false)
	if (
		not mimic_door
		or str(mimic_door.get("journal_entry_id")) != "mimic"
		or int(mimic_door.get("journal_fact_index_on_observation")) != 2
	):
		_fail("House survey False Door does not provide its separate observation fact")
		return
	var definitions: Dictionary = main.SESSION_NOTE_DEFINITIONS.get(
		"res://scenes/endless_house/endless_house_builder_demo.tscn",
		{}
	)
	if (
		(definitions.get("GeneratedNote1", {}) as Dictionary).get("entry_id", "") != "house"
		or int((definitions.get("GeneratedNote1", {}) as Dictionary).get("fact_index", 0)) != 3
	):
		_fail("Server whitelist does not include the production House survey record")
		return
	if main.call(
		"_get_level_scene_by_path",
		"res://scenes/endless_house/endless_house_builder_demo.tscn"
	) != main.HOUSE_BUILDER_DEMO_SCENE:
		_fail("Online scene lookup cannot load the production House survey")


func _assert_watcher_warning_buffer() -> void:
	for monster in main.call("_get_level_monsters"):
		if monster is WatcherMonster:
			if float(monster.get("stare_time_to_kill")) < 3.0:
				_fail("Watcher warning buffer is shorter than three seconds")
			return
	_fail("Final room has no Watcher to validate warning buffer")


func _assert_note_collection_guards() -> void:
	main.set("collected_notes", 0)
	main.set("session_collected_notes", 0)
	var collected_ids: Array[String] = main.get("collected_note_ids")
	collected_ids.clear()

	main.call("_server_collect_note", "MissingSmokeNote")
	if int(main.get("collected_notes")) != 0 or int(main.get("session_collected_notes")) != 0:
		_fail("Missing note collection changed note counters")
		return

	main.call("_server_collect_note", "Note1")
	if int(main.get("collected_notes")) != 1 or int(main.get("session_collected_notes")) != 1:
		_fail("Valid note collection did not update counters once")
		return
	await get_tree().process_frame
	if not str(main.get("ui").hud_label.text).contains("Torn maintenance log"):
		_fail("Opening record text did not remain readable before the threat warning")
		return
	await get_tree().create_timer(1.25).timeout
	if not str(main.get("ui").hud_label.text).contains("Footsteps answered behind you"):
		_fail("Opening Listener activation did not reach the visible HUD")
		return

	main.call("_server_collect_note", "Note1")
	if int(main.get("collected_notes")) != 1 or int(main.get("session_collected_notes")) != 1:
		_fail("Duplicate note collection changed counters")


func _assert_plain_note_collection_preserves_input() -> void:
	main.set("started", true)
	main.call("_spawn_player", 1)
	var local_player: Node = main.get("players").get_node_or_null("1")
	if not local_player:
		_fail("Plain note smoke could not spawn a local player")
		return
	if not is_equal_approx(local_player.rotation.y, PI):
		_fail("Opening player did not face the chase route")
		return

	local_player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.call("_collect_note", "Note1", "Smoke plain fragment")
	if bool(local_player.get("controls_enabled")):
		_fail("Plain note collection changed local player controls")
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		_fail("Plain note collection changed mouse mode")
		return

	main.call("_clear_players")
	main.set("started", false)


func _assert_note_interaction_restores_input() -> void:
	main.set("started", true)
	main.set("collected_notes", 0)
	var collected_ids: Array[String] = main.get("collected_note_ids")
	collected_ids.clear()
	main.call("_spawn_player", 1)
	var local_player: Node = main.get("players").get_node_or_null("1")
	if not local_player:
		_fail("Note interaction smoke could not spawn a local player")
		return
	local_player.set_controls_enabled(false)

	var focus_probe := Button.new()
	focus_probe.name = "SmokeFocusProbe"
	focus_probe.focus_mode = Control.FOCUS_ALL
	main.get("ui").add_child(focus_probe)
	focus_probe.grab_focus()
	if get_viewport().gui_get_focus_owner() != focus_probe:
		focus_probe.queue_free()
		_fail("Smoke focus probe did not receive GUI focus")
		return

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.call("_on_note_puzzle_completed", "Note2", "Smoke fragment")
	await get_tree().process_frame
	if get_viewport().gui_get_focus_owner() != null:
		focus_probe.queue_free()
		_fail("Note interaction left GUI focus captured")
		return
	if not bool(local_player.get("controls_enabled")):
		focus_probe.queue_free()
		_fail("Note interaction did not re-enable local player controls")
		return
	if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		focus_probe.queue_free()
		_fail("Note interaction did not restore captured mouse input")
		return

	focus_probe.queue_free()
	main.call("_clear_players")
	main.set("started", false)


func _assert_debug_house_preview() -> void:
	var game_ui: Node = main.get("ui")
	main.network.close()
	game_ui.hide_menu()
	game_ui.hide_death()
	game_ui.hide_victory()
	game_ui.hide_dialogue()
	game_ui.hide_journal()
	main.set("started", true)
	main.call("_spawn_player", 1)
	var layout_dependent_event := InputEventKey.new()
	layout_dependent_event.pressed = true
	layout_dependent_event.keycode = KEY_F9
	if bool(main.call("_handle_debug_house_preview_input", layout_dependent_event)):
		_fail("House preview accepted a layout-dependent F9 keycode")
		return

	var physical_event := InputEventKey.new()
	physical_event.pressed = true
	physical_event.physical_keycode = KEY_F9
	if not bool(main.call("_handle_debug_house_preview_input", physical_event)):
		_fail("Physical F9 did not open the local House builder preview (debug=%s dedicated=%s peer=%s started=%s blocking=%s key=%s)" % [
			OS.is_debug_build(),
			main.network.is_dedicated_server(),
			multiplayer.has_multiplayer_peer(),
			main.get("started"),
			main.get("ui").is_blocking_overlay_visible(),
			physical_event.physical_keycode,
		])
		return
	if main.get("current_level_scene") != main.HOUSE_BUILDER_DEMO_SCENE:
		_fail("House preview did not load the generated demo scene")
		return
	_assert_level_state("house builder preview", 1, 1, 0, true)
	var local_player: Node3D = main.get("players").get_node_or_null("1")
	if not local_player or not is_equal_approx(local_player.rotation.y, -PI * 0.5):
		_fail("House preview did not face the player down the generated hall")
		return
	main.call("_clear_players")
	main.set("started", false)


func _assert_debug_unlit_preview() -> void:
	var game_ui: Node = main.get("ui")
	main.network.close()
	game_ui.hide_menu()
	game_ui.hide_death()
	game_ui.hide_victory()
	game_ui.hide_dialogue()
	game_ui.hide_journal()
	main.set("started", true)
	var session_records_before := int(main.get("session_collected_notes"))
	main.call("_spawn_player", 1)
	var layout_dependent_event := InputEventKey.new()
	layout_dependent_event.pressed = true
	layout_dependent_event.keycode = KEY_F8
	if bool(main.call("_handle_debug_unlit_preview_input", layout_dependent_event)):
		_fail("The Unlit preview accepted a layout-dependent F8 keycode")
		return

	var physical_event := InputEventKey.new()
	physical_event.pressed = true
	physical_event.physical_keycode = KEY_F8
	if not bool(main.call("_handle_debug_unlit_preview_input", physical_event)):
		_fail("Physical F8 did not open the local Unlit evidence preview")
		return
	if main.get("current_level_scene") != main.UNLIT_EVIDENCE_DEMO_SCENE:
		_fail("The Unlit preview did not load its isolated demo scene")
		return
	_assert_level_state("Unlit evidence preview", 1, 1, 1, true)
	var preview_level := main.get("level") as Node
	var preview_breakers := preview_level.find_children(
		"GeneratedBreakerTrigger*",
		"Area3D",
		true,
		false
	)
	if preview_breakers.size() != 1:
		_fail("The Unlit preview omitted its in-world breaker trigger")
		return
	var local_player: Node3D = main.get("players").get_node_or_null("1")
	if not local_player or not is_equal_approx(local_player.rotation.y, -PI * 0.5):
		_fail("The Unlit preview did not face the player toward its evidence route")
		return
	if not str(main.get("ui").objective_label.text).contains("maintenance test"):
		_fail("The Unlit preview did not show its mechanic-specific objective")
		return
	var preview_note: Node = main.call("_get_note_by_id", "GeneratedNote1")
	if not preview_note:
		_fail("The Unlit preview has no record for its solo debug assist")
		return
	main.call("_collect_note", "GeneratedNote1", str(preview_note.get("note_text")))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var preview_plates: Array = main.call("_get_level_pressure_plates")
	var preview_work_lights := preview_level.find_children(
		"GeneratedWorkLight*",
		"SpotLight3D",
		true,
		false
	)
	if (
		preview_plates.size() != 1
		or preview_work_lights.size() != 1
		or not bool(preview_plates[0].call("is_active"))
		or not bool(preview_work_lights[0].call("is_powered"))
		or bool(main.call("_is_level_exit_open"))
	):
		_fail("Completing the F8 record did not power the solo light while keeping the breaker gate closed")
		return
	if not str(main.get("ui").objective_label.text).contains("reach the breaker"):
		_fail("The Unlit preview did not advance from its record to the breaker task")
		return
	var unlit: Node = preview_level.find_child("GeneratedLightShyMonster1", true, false)
	if not unlit:
		_fail("The Unlit preview has no direct-observation source")
		return
	unlit.emit_signal("observed")
	if (
		not bool(main.get("monster_journal").call("has_fact", "unlit", 2))
		or not str(main.get("ui").status_label.text).contains("stops inside the beam")
	):
		_fail("The Unlit observation did not add its optional fact and concise HUD rule")
		return
	var work_light: Node = preview_work_lights[0]
	var breaker: Node = preview_breakers[0]
	if not work_light or not breaker:
		_fail("The Unlit preview has no snapshot-capable environmental mechanics")
		return
	breaker.call("trigger_outage")
	await get_tree().process_frame
	if not bool(main.call("_is_level_exit_open")):
		_fail("The spent Unlit breaker did not open the local preview exit")
		return
	var mechanic_states: Dictionary = main.call("_get_level_mechanic_states")
	var work_light_state_path := str(preview_level.get_path_to(work_light))
	var breaker_state_path := str(preview_level.get_path_to(breaker))
	if (
		mechanic_states.size() != 2
		or not mechanic_states.has(work_light_state_path)
		or not mechanic_states.has(breaker_state_path)
	):
		_fail("Main did not collect stable level-relative environmental mechanic states")
		return
	var pressure_states: Dictionary = main.call("_get_pressure_plate_states")
	var exit_was_open := bool(main.call("_is_level_exit_open"))
	var work_light_instance_id := work_light.get_instance_id()
	var breaker_instance_id := breaker.get_instance_id()
	main.call("_load_level_scene", main.UNLIT_EVIDENCE_DEMO_SCENE)
	main.call("_apply_collected_note_state")
	main.call("_apply_pressure_plate_states", pressure_states)
	main.call("_apply_level_mechanic_states", mechanic_states)
	main.call("_apply_level_exit_state", exit_was_open)
	await get_tree().process_frame
	await get_tree().physics_frame
	preview_level = main.get("level") as Node
	preview_work_lights = preview_level.find_children(
		"GeneratedWorkLight*",
		"SpotLight3D",
		true,
		false
	)
	preview_breakers = preview_level.find_children(
		"GeneratedBreakerTrigger*",
		"Area3D",
		true,
		false
	)
	preview_plates = main.call("_get_level_pressure_plates")
	if preview_work_lights.size() != 1 or preview_breakers.size() != 1:
		_fail("Reloading the Unlit preview did not regenerate its environmental mechanics")
		return
	var restored_work_light: Node = preview_work_lights[0]
	var restored_breaker: Node = preview_breakers[0]
	if (
		restored_work_light.get_instance_id() == work_light_instance_id
		or restored_breaker.get_instance_id() == breaker_instance_id
		or str(preview_level.get_path_to(restored_work_light)) != work_light_state_path
		or str(preview_level.get_path_to(restored_breaker)) != breaker_state_path
		or not bool(restored_breaker.call("is_triggered"))
		or not bool(restored_work_light.call("is_in_outage"))
		or preview_plates.size() != 1
		or not bool(preview_plates[0].call("is_active"))
		or not bool(main.call("_is_level_exit_open"))
	):
		_fail("Restart-style reload did not restore stable plate, mechanic, and exit state")
		return
	main.call("_on_level_exit_entered")
	await get_tree().process_frame
	if (
		main.get("current_level_scene") != main.LEVEL_SCENE
		or int(main.get("session_collected_notes")) != session_records_before
		or not main.get("players").get_node_or_null("1")
	):
		_fail("Leaving the F8 preview did not return to a playable Room 1 state")
		return
	main.call("_clear_players")
	main.set("started", false)


func _assert_exit_closes_when_pressure_plate_releases() -> void:
	var note_total := int(main.get("total_notes"))
	main.set("collected_notes", note_total)
	for plate in main.call("_get_level_pressure_plates"):
		if plate.has_method("set_latched_active"):
			plate.set_latched_active(true)

	main.call("_evaluate_level_exit_unlock")
	if not bool(main.call("_is_level_exit_open")):
		_fail("Next place exit did not open after notes and pressure plate were satisfied")
		return

	for plate in main.call("_get_level_pressure_plates"):
		if plate.has_method("set_latched_active"):
			plate.set_latched_active(false)
	main.call("_evaluate_level_exit_unlock")
	if bool(main.call("_is_level_exit_open")):
		_fail("Next place exit stayed open after pressure plate state was cleared")


func _assert_level_dialogue(label: String) -> void:
	var loaded_level: Node = main.get("level")
	var dialogue_npcs := loaded_level.get_node_or_null("DialogueNpcs")
	if not dialogue_npcs or dialogue_npcs.get_child_count() <= 0:
		_fail("%s has no dialogue NPCs" % label)
		return
	for npc in dialogue_npcs.get_children():
		if npc.has_method("get_dialogue_pages") and not npc.get_dialogue_pages().is_empty():
			return
	_fail("%s has dialogue NPCs but no dialogue pages" % label)


func _assert_journal_grant_npc() -> void:
	var dialogue_npcs: Node = main.get("level").get_node_or_null("DialogueNpcs")
	for npc in dialogue_npcs.get_children():
		if (
			bool(npc.get("grants_journal"))
			and str(npc.get("journal_entry_id")) == "listener"
			and str(npc.get("dialogue_text")).contains("Tomas")
			and str(npc.get("dialogue_text")).contains("bright-light rule")
		):
			return
	_fail("Mara does not connect her history to the journal's evidence rule")


func _assert_mimic_record_source() -> void:
	for note in main.call("_get_level_notes"):
		if (
			str(note.get("journal_entry_id")) == "mimic"
			and int(note.get("journal_fact_index")) == 1
			and int(note.get("visual_type")) == 3
		):
			return
	_fail("Next place has no False Door voice-recorder clue")


func _assert_room_survey_source() -> void:
	for note in main.call("_get_level_notes"):
		if (
			str(note.get("journal_entry_id")) == "mimic"
			and str(note.get("journal_rumor_id")) == "replicated_room"
			and int(note.get("visual_type")) == 2
		):
			return
	_fail("Next place has no purposeful survey-panel theory for the False Door")


func _assert_conflicting_survivor() -> void:
	var dialogue_npcs: Node = main.get("level").get_node_or_null("DialogueNpcs")
	if not dialogue_npcs:
		_fail("Backrooms has no survivor dialogue root")
		return
	for npc in dialogue_npcs.get_children():
		if (
			str(npc.get("speaker_name")) == "Elias"
			and str(npc.get("journal_entry_id")) == "mimic"
			and str(npc.get("journal_rumor_id")) == "double_pulse_safe"
			and not bool(npc.get("grants_journal"))
			and str(npc.get("dialogue_text")).contains("maintenance surveyor")
			and str(npc.get("dialogue_text")).contains("full light cycle from several steps away")
		):
			return
	_fail("Elias has no history or actionable method behind his conflicting False Door rumor")


func _assert_opening_rumor_source() -> void:
	var dialogue_npcs: Node = main.get("level").get_node_or_null("DialogueNpcs")
	for npc in dialogue_npcs.get_children():
		if (
			str(npc.get("journal_entry_id")) == "listener"
			and str(npc.get("journal_rumor_id")) == "light_barrier"
			and str(npc.get("dialogue_text")).contains("no reliable outside")
		):
			return
	_fail("Opening radio no longer introduces the house or its unverified Listener rumor")


func _assert_opening_chase_layout() -> void:
	var loaded_level: Node3D = main.get("level")
	var threshold := loaded_level.get_node_or_null("SafeThresholdMarker") as Marker3D
	var opening_listener := loaded_level.get_node_or_null("Monsters/OpeningListener") as Node3D
	var spawn_positions: Array = main.call("_get_spawn_positions")
	if not threshold or not opening_listener or spawn_positions.size() < 2:
		_fail("Opening chase lacks a threshold, Listener, or co-op spawn markers")
		return
	var first_spawn: Vector3 = spawn_positions[0]
	if opening_listener.position.z >= first_spawn.z:
		_fail("Opening Listener is not staged behind the players")
		return
	var spawn_center: Vector3 = (spawn_positions[0] + spawn_positions[1]) * 0.5
	var listener_to_spawn := (spawn_center - opening_listener.position).normalized()
	if (-opening_listener.global_basis.z).dot(listener_to_spawn) < 0.95:
		_fail("Opening Listener does not face the players before its first chase")
		return
	for note in main.call("_get_level_notes"):
		var note_z := (note as Node3D).position.z
		if note_z <= first_spawn.z or note_z >= threshold.position.z:
			_fail("Opening evidence is not arranged along the chase route")
			return
	if not loaded_level.has_node("ThresholdLeftWall") or not loaded_level.has_node("ThresholdRightWall"):
		_fail("Opening safe threshold has no readable doorway geometry")


func _assert_final_journal_hook() -> void:
	var dialogue_npcs: Node = main.get("level").get_node_or_null("DialogueNpcs")
	for npc in dialogue_npcs.get_children():
		if str(npc.get("journal_entry_id")) == "watcher" and int(npc.get("journal_fact_index")) == 3:
			return
	_fail("Final room has no dialogue hook for the third Watcher fact")


func _assert_mimic_final_sources() -> void:
	var has_mimic := false
	var observation_test: DialogueNpc
	var has_final_record := false
	for monster in main.call("_get_level_monsters"):
		if str(monster.get("journal_entry_id")) == "mimic":
			has_mimic = true
	var dialogue_npcs: Node = main.get("level").get_node_or_null("DialogueNpcs")
	for npc in dialogue_npcs.get_children():
		if str(npc.get("journal_entry_id")) == "mimic" and int(npc.get("journal_fact_index")) == 2:
			observation_test = npc as DialogueNpc
	for note in main.call("_get_level_notes"):
		if str(note.get("journal_entry_id")) == "mimic" and int(note.get("journal_fact_index")) == 3:
			has_final_record = true
	if not has_mimic or not observation_test or not has_final_record:
		_fail("Final room lacks the False Door, explicit threshold test, or identifying record")
		return
	var journal: Node = main.get("monster_journal")
	journal.reset()
	journal.unlock()
	main.call("_start_dialogue", observation_test)
	main.call("_end_dialogue", true)
	if not journal.has_fact("mimic", 2):
		_fail("Completing the threshold test did not record its exact observation")


func _assert_journal_completion_gate() -> void:
	var journal: Node = main.get("monster_journal")
	journal.reset()
	if bool(main.call("_is_journal_complete")):
		_fail("Locked empty journal passed the victory completion gate")
		return
	journal.unlock()
	journal.discover("listener", 3)
	journal.discover("watcher", 3)
	journal.discover("mimic", 3)
	if bool(main.call("_is_journal_complete")):
		_fail("Later facts implicitly satisfied missing journal evidence")
		return
	for fact_index in range(1, 4):
		journal.discover("listener", fact_index)
		journal.discover("watcher", fact_index)
		journal.discover("mimic", fact_index)
	if not bool(main.call("_is_journal_complete")):
		_fail("Complete journal did not pass the victory completion gate")


func _assert_optional_environmental_evidence() -> void:
	var journal: Node = main.get("monster_journal")
	var required_fact_count := int(journal.call("get_discovered_fact_count"))
	var required_entry_count := int(journal.call("get_completed_entry_count"))
	var trigger := BREAKER_TRIGGER_SCENE.instantiate()
	main.get("level").add_child(trigger)
	main.call("_connect_environmental_evidence")
	trigger.emit_signal("evidence_observed")
	if not bool(journal.call("has_fact", "unlit", 3)):
		_fail("Main did not route environmental evidence into the optional Unlit journal")
		return
	if not str(main.get("ui").status_label.text).contains("work light died"):
		_fail("Breaker evidence did not show its concise flashlight response")
		return
	if (
		int(journal.call("get_discovered_fact_count")) != required_fact_count
		or int(journal.call("get_completed_entry_count")) != required_entry_count
		or not bool(main.call("_is_journal_complete"))
	):
		_fail("Optional environmental evidence changed required victory progress")
	trigger.queue_free()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
