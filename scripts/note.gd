class_name CollectibleNote
extends Area3D

signal collected(note_id: String, note_text: String)
signal puzzle_requested(note_id: String, note_text: String, puzzle_type: int)

@export_multiline var note_text := ""
@export var requires_puzzle := false
@export_enum("Match Dots", "Sequence Lock", "Code Lock") var puzzle_type := 0

var collected_once := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
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
