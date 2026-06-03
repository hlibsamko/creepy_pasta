class_name CollectibleNote
extends Area3D

signal collected(note_id: String, note_text: String)
signal puzzle_requested(note_id: String, note_text: String)

@export_multiline var note_text := ""
@export var requires_puzzle := false

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
		puzzle_requested.emit(name, note_text)
		return

	collected.emit(name, note_text)


func reset_collection_attempt() -> void:
	collected_once = false
