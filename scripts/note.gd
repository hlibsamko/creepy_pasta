class_name CollectibleNote
extends Area3D

signal collected(note_id: String, note_text: String)

@export_multiline var note_text := ""

var collected_once := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if collected_once:
		return
	if not body.has_method("has_control") or not body.has_control():
		return

	collected_once = true
	collected.emit(name, note_text)
