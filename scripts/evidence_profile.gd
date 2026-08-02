@tool
class_name EvidenceProfile
extends Resource

@export_multiline var note_text := ""
@export var journal_entry_id := ""
@export_range(0, 32, 1) var journal_fact_index := 0
@export var journal_rumor_id := ""
