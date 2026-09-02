extends Node

const EVIDENCE_PROFILE_SCRIPT := preload("res://scripts/evidence_profile.gd")


func _ready() -> void:
	var builder := BackroomsBuilder.new()
	var match_evidence := EVIDENCE_PROFILE_SCRIPT.new()
	match_evidence.note_text = "Match evidence"
	match_evidence.journal_entry_id = "house"
	match_evidence.journal_fact_index = 1
	var code_evidence := EVIDENCE_PROFILE_SCRIPT.new()
	code_evidence.note_text = "Code evidence"
	code_evidence.journal_entry_id = "house"
	code_evidence.journal_fact_index = 2
	builder.match_dots_evidence = match_evidence
	builder.code_lock_evidence = code_evidence
	builder.layout = "##########\n#SHGPRT..#\n#.DQKO...#\n#WCMABULE#\n##########"
	add_child(builder)
	await get_tree().process_frame

	var plates := builder.find_children("*", "Area3D", true, false)
	var has_latched_plate := false
	var has_hold_plate := false
	var has_group_hold_plate := false
	for plate in plates:
		if not plate.has_method("is_active"):
			continue
		var latch_once := bool(plate.get("latch_once"))
		var required_players := int(plate.get("required_players"))
		has_latched_plate = has_latched_plate or (latch_once and required_players == 1)
		has_hold_plate = has_hold_plate or (not latch_once and required_players == 1)
		has_group_hold_plate = has_group_hold_plate or (not latch_once and required_players == 2)
		if not latch_once and plate.has_method("set_synced_active"):
			plate.set_synced_active(true)
			if bool(plate.get("latched")):
				_fail("Non-latching pressure plate latched after sync apply")
				return

	if not has_latched_plate:
		_fail("Builder variants smoke did not create a latch-once pressure plate")
		return
	if not has_hold_plate:
		_fail("Builder variants smoke did not create a one-player hold plate")
		return
	if not has_group_hold_plate:
		_fail("Builder variants smoke did not create a two-player group hold plate")
		return

	if builder.find_children("*", "Area3D", true, false).size() < 7:
		_fail("Builder variants smoke did not create expected gameplay areas")
		return
	if not _has_ambush_chaser(builder):
		_fail("Builder variants smoke did not create an ambush chaser")
		return
	if not _has_playable_chaser_speeds(builder):
		return
	if not _has_preserved_kit_offsets(builder):
		return
	if builder.find_children("GeneratedMimicDoor*", "Area3D", true, false).size() != 1:
		_fail("Builder variants smoke did not create exactly one False Door")
		return
	var light_shy_monsters := builder.find_children("GeneratedLightShyMonster*", "CharacterBody3D", true, false)
	if light_shy_monsters.size() != 1 or not light_shy_monsters[0].has_method("is_illuminated"):
		_fail("Builder variants smoke did not create one functional The Unlit")
		return
	if not await _has_wired_unlit_mechanics(builder, light_shy_monsters[0]):
		return
	if not _has_distinct_evidence_profiles(builder):
		return

	print("[smoke] Backrooms builder variants OK")
	get_tree().quit()


func _has_preserved_kit_offsets(builder: Node) -> bool:
	var floors := builder.find_children("BackroomsFloorTile*", "StaticBody3D", true, false)
	var walls := builder.find_children("BackroomsWallBlock*", "StaticBody3D", true, false)
	var ceilings := builder.find_children("BackroomsCeilingTile*", "MeshInstance3D", true, false)
	var lights := builder.find_children("BackroomsFluorescentLight*", "Node3D", true, false)
	var barriers := builder.find_children("BackroomsLowBarrier*", "StaticBody3D", true, false)
	if floors.is_empty() or walls.is_empty() or ceilings.is_empty() or lights.is_empty() or barriers.is_empty():
		_fail("Backrooms kit offset check could not find all geometry roles")
		return false
	if not is_equal_approx((floors[0] as Node3D).global_position.y, -0.1):
		_fail("Backrooms floor lost its authored vertical offset")
		return false
	if not is_equal_approx((walls[0] as Node3D).global_position.y, 2.1):
		_fail("Backrooms walls no longer reach their authored height")
		return false
	if not is_equal_approx((ceilings[0] as Node3D).global_position.y, 4.12):
		_fail("Backrooms ceiling collapsed onto the floor")
		return false
	if not is_equal_approx((lights[0] as Node3D).global_position.y, 4.02):
		_fail("Backrooms fluorescent light lost its ceiling offset")
		return false
	if not is_equal_approx((barriers[0] as Node3D).global_position.y, 0.575):
		_fail("Backrooms low barrier lost its floor-height offset")
		return false
	return true


func _has_ambush_chaser(builder: Node) -> bool:
	for monster in builder.find_children("GeneratedAmbushChaser*", "CharacterBody3D", true, false):
		if int(monster.get("notes_required_to_activate")) == 3 and float(monster.get("sprint_hearing_range")) >= 30.0:
			return true
	return false


func _has_playable_chaser_speeds(builder: Node) -> bool:
	var normal_chasers := builder.find_children("GeneratedChaser*", "CharacterBody3D", true, false)
	var ambush_chasers := builder.find_children("GeneratedAmbushChaser*", "CharacterBody3D", true, false)
	if normal_chasers.size() != 1 or ambush_chasers.size() != 1:
		_fail("Builder variants smoke could not isolate both Backrooms chaser roles")
		return false
	var normal: Node = normal_chasers[0]
	var ambush: Node = ambush_chasers[0]
	var normal_sprint_speed := float(normal.get("move_speed")) * float(normal.get("sprint_speed_bonus"))
	var ambush_sprint_speed := float(ambush.get("move_speed")) * float(ambush.get("sprint_speed_bonus"))
	if normal_sprint_speed >= 4.0:
		_fail("Regular Backrooms chaser is still too fast for early playtesting")
		return false
	if ambush_sprint_speed > 4.35:
		_fail("Late Backrooms chaser is still too fast before journal scaling")
		return false
	if ambush_sprint_speed <= normal_sprint_speed:
		_fail("Backrooms chaser variants lost their readable speed difference")
		return false
	return true


func _has_wired_unlit_mechanics(builder: Node, unlit: Node3D) -> bool:
	var work_lights := builder.find_children("GeneratedWorkLight*", "SpotLight3D", true, false)
	var breaker_triggers := builder.find_children("GeneratedBreakerTrigger*", "Area3D", true, false)
	if work_lights.size() != 1 or breaker_triggers.size() != 1:
		_fail("Builder variants smoke did not create one work light and breaker trigger")
		return false
	var work_light: Node3D = work_lights[0]
	var breaker: Node = breaker_triggers[0]
	var power_source: Node = work_light.get("power_source")
	if (
		not power_source
		or bool(power_source.get("latch_once"))
		or int(power_source.get("required_players")) != 1
	):
		_fail("Generated work light did not receive its one-player non-latching plate")
		return false
	if breaker.get("powered_light") != work_light:
		_fail("Generated breaker did not bind to its nearest work light")
		return false
	if not is_equal_approx(float(work_light.get("spot_range")), float(builder.get("work_light_range"))):
		_fail("Generated work light did not receive the builder range")
		return false
	var light_forward := -work_light.global_basis.z.normalized()
	var direction_to_unlit := (
		unlit.global_position + Vector3.UP * 0.55 - work_light.global_position
	).normalized()
	if light_forward.dot(direction_to_unlit) < 0.995:
		_fail("Generated work light did not aim at its nearest The Unlit")
		return false
	power_source.call("set_synced_active", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not bool(work_light.call("is_powered")):
		_fail("Generated work light did not react to its generated pressure plate")
		return false
	return true


func _has_distinct_evidence_profiles(builder: Node) -> bool:
	var notes := builder.find_children("GeneratedNote*", "Area3D", true, false)
	if notes.size() != 4:
		_fail("Builder variants smoke did not create all four forced puzzle records")
		return false
	var notes_by_puzzle := {}
	for note in notes:
		notes_by_puzzle[int(note.get("puzzle_type"))] = note
	for puzzle_type in range(4):
		if not notes_by_puzzle.has(puzzle_type):
			_fail("Builder variants smoke omitted forced puzzle type %d" % puzzle_type)
			return false
	var match_note: Node = notes_by_puzzle[0]
	var code_note: Node = notes_by_puzzle[2]
	if (
		str(match_note.get("note_text")) != "Match evidence"
		or str(match_note.get("journal_entry_id")) != "house"
		or int(match_note.get("journal_fact_index")) != 1
	):
		_fail("Match Dots record did not receive its editor evidence profile")
		return false
	if (
		str(code_note.get("note_text")) != "Code evidence"
		or str(code_note.get("journal_entry_id")) != "house"
		or int(code_note.get("journal_fact_index")) != 2
	):
		_fail("Code Lock record did not receive its editor evidence profile")
		return false
	if str(notes_by_puzzle[1].get("note_text")) == "":
		_fail("Unconfigured puzzle record lost the builder-wide fallback text")
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
