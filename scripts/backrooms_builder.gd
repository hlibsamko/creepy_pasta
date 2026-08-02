@tool
class_name BackroomsBuilder
extends Node3D

const FLOOR_SCENE := preload("res://scenes/backrooms/kit/backrooms_floor_tile.tscn")
const WALL_SCENE := preload("res://scenes/backrooms/kit/backrooms_wall_block.tscn")
const CEILING_SCENE := preload("res://scenes/backrooms/kit/backrooms_ceiling_tile.tscn")
const LIGHT_SCENE := preload("res://scenes/backrooms/kit/backrooms_fluorescent_light.tscn")
const LOW_BARRIER_SCENE := preload("res://scenes/backrooms/kit/backrooms_low_barrier.tscn")
const LEVEL_EXIT_SCENE := preload("res://scenes/common/level_exit_basic.tscn")
const PRESSURE_PLATE_SCENE := preload("res://scenes/common/pressure_plate_basic.tscn")
const NOTE_SCENE := preload("res://scenes/note.tscn")
const WATCHER_MONSTER_SCENE := preload("res://scenes/common/watcher_monster_basic.tscn")
const CHASER_MONSTER_SCENE := preload("res://scenes/common/chaser_monster_basic.tscn")
const MIMIC_DOOR_SCENE := preload("res://scenes/common/mimic_door_basic.tscn")
const LIGHT_SHY_MONSTER_SCENE := preload("res://scenes/common/light_shy_monster_basic.tscn")
const PRESSURE_POWERED_SPOTLIGHT_SCENE := preload("res://scenes/common/pressure_powered_spotlight_basic.tscn")
const BREAKER_OUTAGE_TRIGGER_SCENE := preload("res://scenes/common/breaker_outage_trigger_basic.tscn")
const EVIDENCE_PROFILE_SCRIPT := preload("res://scripts/evidence_profile.gd")
const VALID_LAYOUT_SYMBOLS := "#.LSENDQKOndqkoWCAMUBPHGRT"

@export_group("Visual Kit")
@export var floor_scene: PackedScene = FLOOR_SCENE:
	set(value):
		floor_scene = value
		_request_rebuild()

@export var wall_scene: PackedScene = WALL_SCENE:
	set(value):
		wall_scene = value
		_request_rebuild()

@export var ceiling_scene: PackedScene = CEILING_SCENE:
	set(value):
		ceiling_scene = value
		_request_rebuild()

@export var light_scene: PackedScene = LIGHT_SCENE:
	set(value):
		light_scene = value
		_request_rebuild()

@export var low_barrier_scene: PackedScene = LOW_BARRIER_SCENE:
	set(value):
		low_barrier_scene = value
		_request_rebuild()

@export_group("Layout")

@export var cell_size := 4.0:
	set(value):
		cell_size = max(value, 1.0)
		_request_rebuild()

@export_multiline var layout := "#########\n#...L...#\n#.#...#.#\n#...L...#\n#########":
	set(value):
		layout = value
		_request_rebuild()

@export var rebuild_in_editor := true:
	set(value):
		rebuild_in_editor = value
		_request_rebuild()

@export var generate_markers := true:
	set(value):
		generate_markers = value
		_request_rebuild()

@export var generate_level_exit := true:
	set(value):
		generate_level_exit = value
		_request_rebuild()

@export var generate_notes := true:
	set(value):
		generate_notes = value
		_request_rebuild()

@export var generate_watcher_monsters := true:
	set(value):
		generate_watcher_monsters = value
		_request_rebuild()

@export var generate_chaser_monsters := true:
	set(value):
		generate_chaser_monsters = value
		_request_rebuild()

@export var generate_mimic_doors := true:
	set(value):
		generate_mimic_doors = value
		_request_rebuild()

@export var generate_light_shy_monsters := true:
	set(value):
		generate_light_shy_monsters = value
		_request_rebuild()

@export_group("Generated Evidence")
@export_multiline var generated_note_text := "The yellow rooms remember every shortcut."
@export var generated_notes_require_puzzle := true
@export_enum("Match Dots", "Sequence Lock", "Code Lock", "Polarity Switch") var generated_note_puzzle_type := 3
@export_enum("Glow Orb", "Paper Note", "Survey Plate", "Voice Recorder") var generated_note_visual_type := 2
@export var match_dots_evidence: EVIDENCE_PROFILE_SCRIPT
@export var sequence_lock_evidence: EVIDENCE_PROFILE_SCRIPT
@export var code_lock_evidence: EVIDENCE_PROFILE_SCRIPT
@export var polarity_switch_evidence: EVIDENCE_PROFILE_SCRIPT

@export_group("Threats")
@export_range(0.5, 10.0, 0.05) var chaser_move_speed := 3.25
@export_range(1.0, 3.0, 0.01) var chaser_sprint_speed_multiplier := 1.18
@export_range(0.5, 10.0, 0.05) var ambush_move_speed := 3.7
@export_range(1.0, 3.0, 0.01) var ambush_sprint_speed_multiplier := 1.16
@export_range(0, 32, 1) var ambush_notes_required_to_activate := 3
@export_range(4.0, 40.0, 0.5) var work_light_range := 24.0

var generated_root: Node3D
var generated_geometry_root: Node3D
var generated_markers_root: Node3D
var generated_mechanics_root: Node3D
var generated_notes_root: Node3D
var generated_monsters_root: Node3D
var spawn_marker_count := 0
var exit_marker_count := 0
var note_count := 0
var watcher_count := 0
var chaser_count := 0
var mimic_count := 0
var light_shy_count := 0
var work_light_count := 0
var breaker_trigger_count := 0
var generated_work_lights: Array[Node3D] = []
var generated_breaker_triggers: Array[Node3D] = []


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_clear_generated()
	spawn_marker_count = 0
	exit_marker_count = 0
	note_count = 0
	watcher_count = 0
	chaser_count = 0
	mimic_count = 0
	light_shy_count = 0
	work_light_count = 0
	breaker_trigger_count = 0
	generated_work_lights.clear()
	generated_breaker_triggers.clear()
	generated_root = Node3D.new()
	generated_root.name = "GeneratedBackrooms"
	add_child(generated_root)
	if Engine.is_editor_hint():
		generated_root.owner = get_tree().edited_scene_root
	generated_geometry_root = _add_generated_group("Geometry")
	generated_markers_root = _add_generated_group("Markers")
	generated_mechanics_root = _add_generated_group("Mechanics")
	generated_notes_root = _add_generated_group("Notes")
	generated_monsters_root = _add_generated_group("Monsters")

	var rows := _get_rows()
	for z in rows.size():
		var row := rows[z]
		for x in row.length():
			var marker := row.substr(x, 1)
			var position := Vector3(x * cell_size, 0.0, z * cell_size)
			match marker:
				"#":
					_add_piece(wall_scene, position)
				".", "L", "S", "E", "N", "D", "Q", "K", "O", "n", "d", "q", "k", "o", "W", "C", "A", "M", "U", "B", "P", "H", "G", "R", "T":
					_add_piece(floor_scene, position)
					_add_piece(ceiling_scene, position)
					if marker == "L":
						_add_piece(light_scene, position)
					elif marker == "B":
						_add_piece(low_barrier_scene, position)
					elif marker == "P":
						_add_pressure_plate(position + Vector3(0.0, 0.03, 0.0), true, 1)
					elif marker == "H":
						_add_pressure_plate(position + Vector3(0.0, 0.03, 0.0), false, 1)
					elif marker == "G":
						_add_pressure_plate(position + Vector3(0.0, 0.03, 0.0), false, 2)
					elif marker == "R":
						var work_plate := _add_pressure_plate(
							position + Vector3(0.0, 0.03, 0.0),
							false,
							1
						)
						_add_powered_work_light(position, work_plate)
					elif marker == "T":
						_add_breaker_outage_trigger(position)
					elif marker == "S":
						_add_marker("SpawnMarker", position + Vector3(0.0, 0.2, 0.0))
					elif marker == "E":
						_add_marker("ExitMarker", position + Vector3(0.0, 1.15, 0.0))
						_add_level_exit(position + Vector3(0.0, 1.15, 0.0), _get_door_yaw(rows, x, z))
					elif marker in ["N", "D", "Q", "K", "O"]:
						_add_note(position + Vector3(0.0, 0.55, 0.0), _get_note_puzzle_type_for_marker(marker))
					elif marker in ["n", "d", "q", "k", "o"]:
						_add_note(position + Vector3(0.0, 0.55, 0.0), _get_note_puzzle_type_for_marker(marker.to_upper()), false)
					elif marker == "W":
						_add_watcher_monster(position + Vector3(0.0, 1.1, 0.0))
					elif marker == "C":
						_add_chaser_monster(position + Vector3(0.0, 0.9, 0.0), false)
					elif marker == "A":
						_add_chaser_monster(position + Vector3(0.0, 0.9, 0.0), true)
					elif marker == "M":
						_add_mimic_door(position + Vector3(0.0, 1.15, 0.0), _get_door_yaw(rows, x, z))
					elif marker == "U":
						_add_light_shy_monster(position)
				_:
					pass
	_wire_generated_unlit_mechanics()


func _request_rebuild() -> void:
	if is_inside_tree():
		update_configuration_warnings()
	if Engine.is_editor_hint() and rebuild_in_editor and is_inside_tree():
		call_deferred("rebuild")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var rows := _get_rows()
	if rows.is_empty():
		warnings.append("Layout is empty; no level content will be generated.")
		return warnings

	var expected_width := rows[0].length()
	var unknown_symbols := PackedStringArray()
	var symbol_positions := {}
	for marker in ["S", "E", "R", "T", "U"]:
		symbol_positions[marker] = []
	for z in rows.size():
		var row := rows[z]
		if row.length() != expected_width:
			warnings.append(
				"Layout row %d is %d cells wide; expected %d."
				% [z + 1, row.length(), expected_width]
			)
		for x in row.length():
			var marker := row.substr(x, 1)
			if not VALID_LAYOUT_SYMBOLS.contains(marker) and marker not in unknown_symbols:
				unknown_symbols.append(marker)
			if symbol_positions.has(marker):
				symbol_positions[marker].append(Vector2i(x, z))

	if not unknown_symbols.is_empty():
		warnings.append(
			"Layout contains unsupported symbols: %s." % ", ".join(unknown_symbols)
		)
	if symbol_positions["S"].is_empty():
		warnings.append("Layout has no S spawn marker.")
	if generate_level_exit and symbol_positions["E"].is_empty():
		warnings.append("Layout has no E exit marker while level-exit generation is enabled.")

	var work_stations: Array = symbol_positions["R"]
	var triggers: Array = symbol_positions["T"]
	var unlit_targets: Array = symbol_positions["U"]
	if not triggers.is_empty() and work_stations.is_empty():
		warnings.append("T breaker cells require at least one R powered work-light station.")
	if not work_stations.is_empty() and unlit_targets.is_empty():
		warnings.append("R work-light cells have no U target for automatic aiming.")
	if _has_ambiguous_nearest_pair(work_stations, unlit_targets):
		warnings.append(
			"An R work light is equally close to multiple U targets; separate the encounter clusters."
		)
	if _has_ambiguous_nearest_pair(triggers, work_stations):
		warnings.append(
			"A T breaker is equally close to multiple R work lights; separate the encounter clusters."
		)
	return warnings


func _has_ambiguous_nearest_pair(origins: Array, candidates: Array) -> bool:
	if candidates.size() < 2:
		return false
	for origin: Vector2i in origins:
		var nearest_distance := INF
		var nearest_count := 0
		for candidate: Vector2i in candidates:
			var distance := Vector2(origin).distance_squared_to(Vector2(candidate))
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_count = 1
			elif is_equal_approx(distance, nearest_distance):
				nearest_count += 1
		if nearest_count > 1:
			return true
	return false


func _get_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for raw_row in layout.split("\n"):
		var row := raw_row.strip_edges()
		if not row.is_empty():
			rows.append(row)
	return rows


func _get_door_yaw(rows: PackedStringArray, x: int, z: int) -> float:
	var horizontal_openings := int(_is_layout_walkable(rows, x - 1, z)) + int(_is_layout_walkable(rows, x + 1, z))
	var vertical_openings := int(_is_layout_walkable(rows, x, z - 1)) + int(_is_layout_walkable(rows, x, z + 1))
	if horizontal_openings > vertical_openings:
		return PI * 0.5
	return 0.0


func _is_layout_walkable(rows: PackedStringArray, x: int, z: int) -> bool:
	if z < 0 or z >= rows.size() or x < 0 or x >= rows[z].length():
		return false
	return rows[z].substr(x, 1) != "#"


func _add_piece(scene: PackedScene, position: Vector3) -> void:
	if not scene:
		return
	var piece := scene.instantiate() as Node3D
	piece.position += position
	generated_geometry_root.add_child(piece)
	if Engine.is_editor_hint():
		piece.owner = get_tree().edited_scene_root


func _add_generated_group(group_name: String) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	generated_root.add_child(group)
	if Engine.is_editor_hint():
		group.owner = get_tree().edited_scene_root
	return group


func _add_marker(prefix: String, position: Vector3) -> void:
	if not generate_markers:
		return

	var marker := Marker3D.new()
	marker.position = position
	if prefix == "SpawnMarker":
		spawn_marker_count += 1
		marker.name = "%s%d" % [prefix, spawn_marker_count]
	else:
		exit_marker_count += 1
		marker.name = "%s%d" % [prefix, exit_marker_count]
	generated_markers_root.add_child(marker)
	if Engine.is_editor_hint():
		marker.owner = get_tree().edited_scene_root


func _add_level_exit(position: Vector3, yaw: float) -> void:
	if not generate_level_exit:
		return

	var level_exit := LEVEL_EXIT_SCENE.instantiate() as Node3D
	level_exit.position = position
	level_exit.rotation.y = yaw
	generated_markers_root.add_child(level_exit)
	if Engine.is_editor_hint():
		level_exit.owner = get_tree().edited_scene_root


func _add_pressure_plate(position: Vector3, latch_once: bool, required_players: int) -> Node3D:
	var pressure_plate := PRESSURE_PLATE_SCENE.instantiate() as Node3D
	pressure_plate.position = position
	pressure_plate.set("latch_once", latch_once)
	pressure_plate.set("required_players", required_players)
	if not latch_once:
		pressure_plate.set("inactive_color", Color(0.18, 0.26, 0.34, 1.0))
		pressure_plate.set("active_color", Color(0.42, 0.78, 1.0, 1.0))
	generated_mechanics_root.add_child(pressure_plate)
	if Engine.is_editor_hint():
		pressure_plate.owner = get_tree().edited_scene_root
	return pressure_plate


func _add_powered_work_light(position: Vector3, pressure_plate: Node3D) -> void:
	work_light_count += 1
	var work_light := PRESSURE_POWERED_SPOTLIGHT_SCENE.instantiate() as Node3D
	work_light.name = "GeneratedWorkLight%d" % work_light_count
	work_light.position = position + Vector3(0.0, 2.65, 0.0)
	work_light.set("spot_range", work_light_range)
	generated_mechanics_root.add_child(work_light)
	if work_light.has_method("set_power_source"):
		work_light.call("set_power_source", pressure_plate)
	generated_work_lights.append(work_light)
	if Engine.is_editor_hint():
		work_light.owner = get_tree().edited_scene_root


func _add_breaker_outage_trigger(position: Vector3) -> void:
	breaker_trigger_count += 1
	var trigger := BREAKER_OUTAGE_TRIGGER_SCENE.instantiate() as Node3D
	trigger.name = "GeneratedBreakerTrigger%d" % breaker_trigger_count
	trigger.position = position
	generated_mechanics_root.add_child(trigger)
	generated_breaker_triggers.append(trigger)
	if Engine.is_editor_hint():
		trigger.owner = get_tree().edited_scene_root


func _wire_generated_unlit_mechanics() -> void:
	var unlit_monsters: Array[Node3D] = []
	for monster in generated_monsters_root.find_children(
		"GeneratedLightShyMonster*",
		"CharacterBody3D",
		true,
		false
	):
		unlit_monsters.append(monster as Node3D)

	for work_light in generated_work_lights:
		var nearest_unlit := _find_nearest_node(work_light, unlit_monsters)
		if nearest_unlit:
			work_light.look_at(nearest_unlit.global_position + Vector3.UP * 0.55, Vector3.UP)

	for trigger in generated_breaker_triggers:
		var nearest_light := _find_nearest_node(trigger, generated_work_lights)
		if nearest_light and trigger.has_method("set_powered_light"):
			trigger.call("set_powered_light", nearest_light)


func _find_nearest_node(origin: Node3D, candidates: Array[Node3D]) -> Node3D:
	var nearest: Node3D
	var nearest_distance := INF
	for candidate in candidates:
		var distance := origin.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _add_note(position: Vector3, puzzle_type: int, enabled_for_gameplay := true) -> void:
	if not generate_notes:
		return

	note_count += 1
	var note := NOTE_SCENE.instantiate() as Node3D
	var evidence_profile := _get_evidence_profile(puzzle_type)
	note.name = "GeneratedNote%d" % note_count
	note.position = position
	note.set("note_text", _get_evidence_text(evidence_profile))
	note.set("enabled_for_gameplay", enabled_for_gameplay)
	note.set("requires_puzzle", generated_notes_require_puzzle)
	note.set("puzzle_type", puzzle_type)
	note.set("visual_type", generated_note_visual_type)
	if evidence_profile:
		note.set("journal_entry_id", evidence_profile.journal_entry_id)
		note.set("journal_fact_index", evidence_profile.journal_fact_index)
		note.set("journal_rumor_id", evidence_profile.journal_rumor_id)
	generated_notes_root.add_child(note)
	if Engine.is_editor_hint():
		note.owner = get_tree().edited_scene_root


func _get_evidence_profile(puzzle_type: int) -> EVIDENCE_PROFILE_SCRIPT:
	match puzzle_type:
		0:
			return match_dots_evidence
		1:
			return sequence_lock_evidence
		2:
			return code_lock_evidence
		3:
			return polarity_switch_evidence
		_:
			return null


func _get_evidence_text(profile: EVIDENCE_PROFILE_SCRIPT) -> String:
	if profile and not profile.note_text.strip_edges().is_empty():
		return profile.note_text
	return generated_note_text


func _get_note_puzzle_type_for_marker(marker: String) -> int:
	match marker:
		"D":
			return 0
		"Q":
			return 1
		"K":
			return 2
		"O":
			return 3
		_:
			return generated_note_puzzle_type


func _add_watcher_monster(position: Vector3) -> void:
	if not generate_watcher_monsters:
		return

	watcher_count += 1
	var watcher := WATCHER_MONSTER_SCENE.instantiate() as Node3D
	watcher.name = "GeneratedWatcher%d" % watcher_count
	watcher.position = position
	generated_monsters_root.add_child(watcher)
	if Engine.is_editor_hint():
		watcher.owner = get_tree().edited_scene_root


func _add_chaser_monster(position: Vector3, ambush_variant: bool) -> void:
	if not generate_chaser_monsters:
		return

	chaser_count += 1
	var chaser := CHASER_MONSTER_SCENE.instantiate() as Node3D
	chaser.name = "GeneratedAmbushChaser%d" % chaser_count if ambush_variant else "GeneratedChaser%d" % chaser_count
	chaser.position = position
	chaser.set("move_speed", ambush_move_speed if ambush_variant else chaser_move_speed)
	chaser.set(
		"sprint_speed_bonus",
		ambush_sprint_speed_multiplier if ambush_variant else chaser_sprint_speed_multiplier
	)
	if ambush_variant:
		chaser.set("start_delay", 1.2)
		chaser.set("death_reason", "The late thing in the yellow rooms caught you")
		chaser.set("sprint_hearing_range", 30.0)
		chaser.set("notes_required_to_activate", ambush_notes_required_to_activate)
		chaser.set("patrol_radius", 6.5)
		chaser.set("patrol_wait_time", 0.8)
	generated_monsters_root.add_child(chaser)
	if Engine.is_editor_hint():
		chaser.owner = get_tree().edited_scene_root


func _add_mimic_door(position: Vector3, yaw: float) -> void:
	if not generate_mimic_doors:
		return

	mimic_count += 1
	var mimic := MIMIC_DOOR_SCENE.instantiate() as Node3D
	mimic.name = "GeneratedMimicDoor%d" % mimic_count
	mimic.position = position
	mimic.rotation.y = yaw
	generated_monsters_root.add_child(mimic)
	if Engine.is_editor_hint():
		mimic.owner = get_tree().edited_scene_root


func _add_light_shy_monster(position: Vector3) -> void:
	if not generate_light_shy_monsters:
		return

	light_shy_count += 1
	var monster := LIGHT_SHY_MONSTER_SCENE.instantiate() as Node3D
	monster.name = "GeneratedLightShyMonster%d" % light_shy_count
	monster.position = position
	generated_monsters_root.add_child(monster)
	if Engine.is_editor_hint():
		monster.owner = get_tree().edited_scene_root


func _clear_generated() -> void:
	var existing := get_node_or_null("GeneratedBackrooms")
	if existing:
		remove_child(existing)
		existing.queue_free()
