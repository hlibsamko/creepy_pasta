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

@export_multiline var generated_note_text := "The yellow rooms remember every shortcut."
@export var generated_notes_require_puzzle := true
@export_enum("Match Dots", "Sequence Lock", "Code Lock") var generated_note_puzzle_type := 2

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


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_clear_generated()
	spawn_marker_count = 0
	exit_marker_count = 0
	note_count = 0
	watcher_count = 0
	chaser_count = 0
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
					_add_piece(WALL_SCENE, position)
				".", "L", "S", "E", "N", "W", "C", "B", "P":
					_add_piece(FLOOR_SCENE, position)
					_add_piece(CEILING_SCENE, position)
					if marker == "L":
						_add_piece(LIGHT_SCENE, position)
					elif marker == "B":
						_add_piece(LOW_BARRIER_SCENE, position)
					elif marker == "P":
						_add_pressure_plate(position + Vector3(0.0, 0.03, 0.0))
					elif marker == "S":
						_add_marker("SpawnMarker", position + Vector3(0.0, 0.2, 0.0))
					elif marker == "E":
						_add_marker("ExitMarker", position + Vector3(0.0, 1.15, 0.0))
						_add_level_exit(position + Vector3(0.0, 1.15, 0.0))
					elif marker == "N":
						_add_note(position + Vector3(0.0, 0.55, 0.0))
					elif marker == "W":
						_add_watcher_monster(position + Vector3(0.0, 1.1, 0.0))
					elif marker == "C":
						_add_chaser_monster(position + Vector3(0.0, 0.9, 0.0))
				_:
					pass


func _request_rebuild() -> void:
	if Engine.is_editor_hint() and rebuild_in_editor and is_inside_tree():
		call_deferred("rebuild")


func _get_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for raw_row in layout.split("\n"):
		var row := raw_row.strip_edges()
		if not row.is_empty():
			rows.append(row)
	return rows


func _add_piece(scene: PackedScene, position: Vector3) -> void:
	var piece := scene.instantiate() as Node3D
	piece.position = position
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


func _add_level_exit(position: Vector3) -> void:
	if not generate_level_exit:
		return

	var level_exit := LEVEL_EXIT_SCENE.instantiate() as Node3D
	level_exit.position = position
	generated_markers_root.add_child(level_exit)
	if Engine.is_editor_hint():
		level_exit.owner = get_tree().edited_scene_root


func _add_pressure_plate(position: Vector3) -> void:
	var pressure_plate := PRESSURE_PLATE_SCENE.instantiate() as Node3D
	pressure_plate.position = position
	generated_mechanics_root.add_child(pressure_plate)
	if Engine.is_editor_hint():
		pressure_plate.owner = get_tree().edited_scene_root


func _add_note(position: Vector3) -> void:
	if not generate_notes:
		return

	note_count += 1
	var note := NOTE_SCENE.instantiate() as Node3D
	note.name = "GeneratedNote%d" % note_count
	note.position = position
	note.set("note_text", generated_note_text)
	note.set("requires_puzzle", generated_notes_require_puzzle)
	note.set("puzzle_type", generated_note_puzzle_type)
	generated_notes_root.add_child(note)
	if Engine.is_editor_hint():
		note.owner = get_tree().edited_scene_root


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


func _add_chaser_monster(position: Vector3) -> void:
	if not generate_chaser_monsters:
		return

	chaser_count += 1
	var chaser := CHASER_MONSTER_SCENE.instantiate() as Node3D
	chaser.name = "GeneratedChaser%d" % chaser_count
	chaser.position = position
	generated_monsters_root.add_child(chaser)
	if Engine.is_editor_hint():
		chaser.owner = get_tree().edited_scene_root


func _clear_generated() -> void:
	var existing := get_node_or_null("GeneratedBackrooms")
	if existing:
		remove_child(existing)
		existing.queue_free()
