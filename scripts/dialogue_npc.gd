class_name DialogueNpc
extends Area3D

signal player_entered(npc: DialogueNpc)
signal player_exited(npc: DialogueNpc)

@export var speaker_name := "Stranger"
@export_multiline var dialogue_text := ""
@export var grants_journal := false
@export var journal_entry_id := ""
@export_range(0, 3, 1) var journal_fact_index := 0
@export var journal_rumor_id := ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_dialogue_pages() -> Array[String]:
	var pages: Array[String] = []
	for page in dialogue_text.split("\n\n", false):
		var clean_page := page.strip_edges()
		if clean_page != "":
			pages.append(clean_page)
	return pages


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("has_control") and body.has_control():
		player_entered.emit(self)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("has_control") and body.has_control():
		player_exited.emit(self)
