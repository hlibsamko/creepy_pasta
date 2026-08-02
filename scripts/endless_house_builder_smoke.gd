extends Node

const HOUSE_DEMO := preload("res://scenes/endless_house/endless_house_builder_demo.tscn")


func _ready() -> void:
	var demo := HOUSE_DEMO.instantiate()
	add_child(demo)
	await get_tree().process_frame

	var builder := demo.get_node_or_null("EndlessHouseBuilder") as BackroomsBuilder
	if not builder:
		_fail("Endless House demo has no reusable builder node")
		return
	if builder.floor_scene.resource_path != "res://scenes/endless_house/kit/house_floor_tile.tscn":
		_fail("Endless House builder did not retain its custom floor kit")
		return
	if builder.wall_scene.resource_path != "res://scenes/endless_house/kit/house_wall_block.tscn":
		_fail("Endless House builder did not retain its custom wall kit")
		return
	if builder.find_children("HouseFloorTile*", "StaticBody3D", true, false).is_empty():
		_fail("Endless House builder did not generate house floor geometry")
		return
	if builder.find_children("HouseWallBlock*", "StaticBody3D", true, false).is_empty():
		_fail("Endless House builder did not generate house wall geometry")
		return
	if not _has_preserved_kit_offsets(builder):
		return
	if builder.find_children("SpawnMarker*", "Marker3D", true, false).size() != 1:
		_fail("Endless House demo did not generate exactly one spawn marker")
		return
	if builder.find_children("LevelExit*", "Area3D", true, false).size() != 1:
		_fail("Endless House demo did not generate exactly one real exit")
		return
	var evidence_notes := builder.find_children("GeneratedNote*", "Area3D", true, false)
	if evidence_notes.size() != 1:
		_fail("Endless House demo did not generate exactly one evidence note")
		return
	var evidence_note: Node = evidence_notes[0]
	if (
		str(evidence_note.get("journal_entry_id")) != "house"
		or int(evidence_note.get("journal_fact_index")) != 3
		or not str(evidence_note.get("note_text")).contains("floor dust")
		or not str(evidence_note.get("note_text")).contains("no draft")
		or not str(evidence_note.get("note_text")).contains("room tone")
	):
		_fail("Endless House record does not provide its authored physical-copy evidence")
		return
	var mimic_doors := builder.find_children("GeneratedMimicDoor*", "Area3D", true, false)
	if mimic_doors.size() != 1 or not mimic_doors[0].has_signal("killed_player"):
		_fail("Endless House demo did not generate one functional False Door")
		return
	var exits := builder.find_children("LevelExit*", "Area3D", true, false)
	if not is_equal_approx(float(mimic_doors[0].rotation.y), PI * 0.5):
		_fail("House False Door did not face its horizontal dead end")
		return
	if not is_zero_approx(float(exits[0].rotation.y)):
		_fail("House real exit did not face its vertical approach")
		return
	var level_exit := exits[0] as LevelExit
	var draft_cue := level_exit.get_node_or_null("DraftCue") as Node3D
	if not draft_cue or not draft_cue.has_method("set_active") or draft_cue.visible:
		_fail("House real exit does not keep its draft cue hidden while closed")
		return
	if not level_exit.has_method("has_room_tone_cue") or not level_exit.has_room_tone_cue():
		_fail("House real exit lost its steady room-tone test")
		return
	if mimic_doors[0].get_node_or_null("DraftCue"):
		_fail("House False Door incorrectly copied the real exit draft cue")
		return
	if mimic_doors[0].has_method("has_room_tone_cue"):
		_fail("House False Door incorrectly copied the real exit room tone")
		return
	var room_tone: AudioStreamWAV = level_exit.call("_create_room_tone_stream")
	var expected_room_tone_samples := int(
		level_exit.ROOM_TONE_MIX_RATE * level_exit.ROOM_TONE_DURATION
	)
	if (
		room_tone.loop_mode != AudioStreamWAV.LOOP_FORWARD
		or room_tone.loop_begin != 0
		or room_tone.loop_end != expected_room_tone_samples
	):
		_fail("House real exit room tone is not a continuous loop")
		return
	level_exit.open()
	var initial_stream_position := (draft_cue.get_node("StreamLeft") as Node3D).position
	await get_tree().create_timer(0.08).timeout
	if not draft_cue.visible:
		_fail("House real exit did not reveal its physical draft cue when opened")
		return
	if DisplayServer.get_name() != "headless":
		if not level_exit.room_tone_player or not level_exit.room_tone_player.playing:
			_fail("House real exit did not start its positional room tone when opened")
			return
	if (draft_cue.get_node("StreamLeft") as Node3D).position.is_equal_approx(initial_stream_position):
		_fail("House real exit draft cue is visible but not moving")
		return
	level_exit.close()
	if draft_cue.visible:
		_fail("House real exit draft cue remained visible after closing")
		return
	if DisplayServer.get_name() != "headless" and level_exit.room_tone_player.playing:
		_fail("House real exit room tone continued after closing")
		return

	var survey_steps := _get_survey_steps(builder.layout)
	if survey_steps.is_empty():
		return
	if not (survey_steps["note"] < survey_steps["mimic"] and survey_steps["mimic"] < survey_steps["exit"]):
		_fail("House survey no longer presents evidence, False Door, and real exit in order")
		return

	builder.rebuild()
	await get_tree().process_frame
	if builder.find_children("GeneratedBackrooms", "Node3D", true, false).size() != 1:
		_fail("Endless House rebuild duplicated its generated root")
		return
	if builder.find_children("GeneratedMimicDoor*", "Area3D", true, false).size() != 1:
		_fail("Endless House rebuild changed its False Door count")
		return

	print("[smoke] Endless House reusable builder kit OK")
	get_tree().quit()


func _has_preserved_kit_offsets(builder: Node) -> bool:
	var floors := builder.find_children("HouseFloorTile*", "StaticBody3D", true, false)
	var walls := builder.find_children("HouseWallBlock*", "StaticBody3D", true, false)
	var ceilings := builder.find_children("HouseCeilingTile*", "MeshInstance3D", true, false)
	var lights := builder.find_children("HouseCeilingLamp*", "Node3D", true, false)
	var sideboards := builder.find_children("HouseLowSideboard*", "StaticBody3D", true, false)
	if floors.is_empty() or walls.is_empty() or ceilings.is_empty() or lights.is_empty() or sideboards.is_empty():
		_fail("Endless House kit offset check could not find all geometry roles")
		return false
	if not is_equal_approx((floors[0] as Node3D).global_position.y, -0.1):
		_fail("Endless House floor lost its authored vertical offset")
		return false
	if not is_equal_approx((walls[0] as Node3D).global_position.y, 1.6):
		_fail("Endless House walls no longer rise from floor to ceiling")
		return false
	if not is_equal_approx((ceilings[0] as Node3D).global_position.y, 3.12):
		_fail("Endless House ceiling collapsed onto the floor")
		return false
	if not is_equal_approx((lights[0] as Node3D).global_position.y, 2.96):
		_fail("Endless House ceiling lamp lost its authored offset")
		return false
	if not is_equal_approx((sideboards[0] as Node3D).global_position.y, 0.56):
		_fail("Endless House sideboard lost its floor-height offset")
		return false
	return true


func _get_survey_steps(layout: String) -> Dictionary:
	var rows := PackedStringArray()
	for raw_row in layout.split("\n"):
		var row := raw_row.strip_edges()
		if not row.is_empty():
			rows.append(row)

	var targets := {}
	for z in rows.size():
		for x in rows[z].length():
			var marker := rows[z].substr(x, 1)
			if marker == "S":
				targets["spawn"] = Vector2i(x, z)
			elif marker == "D":
				targets["note_position"] = Vector2i(x, z)
			elif marker == "M":
				targets["mimic_position"] = Vector2i(x, z)
			elif marker == "E":
				targets["exit_position"] = Vector2i(x, z)
	for required_key in ["spawn", "note_position", "mimic_position", "exit_position"]:
		if not targets.has(required_key):
			_fail("House survey layout is missing %s" % required_key)
			return {}

	var distances := _get_layout_distances(rows, targets["spawn"])
	var result := {}
	for target_name in ["note", "mimic", "exit"]:
		var position_key := "%s_position" % target_name
		var position: Vector2i = targets[position_key]
		if not distances.has(position):
			_fail("House survey %s is unreachable from spawn" % target_name)
			return {}
		result[target_name] = int(distances[position])
	return result


func _get_layout_distances(rows: PackedStringArray, start: Vector2i) -> Dictionary:
	var distances := {start: 0}
	var queue: Array[Vector2i] = [start]
	var index := 0
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while index < queue.size():
		var position := queue[index]
		index += 1
		for direction in directions:
			var next_position := position + direction
			if distances.has(next_position):
				continue
			if next_position.y < 0 or next_position.y >= rows.size():
				continue
			if next_position.x < 0 or next_position.x >= rows[next_position.y].length():
				continue
			if rows[next_position.y].substr(next_position.x, 1) == "#":
				continue
			distances[next_position] = int(distances[position]) + 1
			queue.append(next_position)
	return distances


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
