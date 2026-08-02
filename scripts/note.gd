@tool
class_name CollectibleNote
extends Area3D

signal collected(note_id: String, note_text: String)
signal puzzle_requested(note_id: String, note_text: String, puzzle_type: int)

@export_multiline var note_text := ""
@export var enabled_for_gameplay := true
@export var requires_puzzle := false
@export_enum("Match Dots", "Sequence Lock", "Code Lock", "Polarity Switch") var puzzle_type := 0
@export_enum("Glow Orb", "Paper Note", "Survey Plate", "Voice Recorder") var visual_type := 0:
	set(value):
		visual_type = clampi(value, 0, 3)
		if is_inside_tree():
			_apply_visual_type()
@export var journal_entry_id := ""
@export_range(0, 3, 1) var journal_fact_index := 0
@export var journal_rumor_id := ""

var collected_once := false


func _ready() -> void:
	_apply_visual_type()
	_apply_enabled_state()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not enabled_for_gameplay:
		return
	if collected_once:
		return
	if not body.has_method("has_control") or not body.has_control():
		return

	collected_once = true
	if requires_puzzle:
		puzzle_requested.emit(name, note_text, puzzle_type)
		return

	collected.emit(name, note_text)


func reset_collection_attempt() -> void:
	collected_once = false


func is_enabled_for_gameplay() -> bool:
	return enabled_for_gameplay


func _apply_enabled_state() -> void:
	visible = enabled_for_gameplay
	monitoring = enabled_for_gameplay
	monitorable = enabled_for_gameplay


func _apply_visual_type() -> void:
	var visuals := get_node_or_null("Visuals")
	if not visuals:
		return
	for index in visuals.get_child_count():
		visuals.get_child(index).visible = index == visual_type
