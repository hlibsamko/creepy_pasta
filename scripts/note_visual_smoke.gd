extends Node

const NOTE_SCENE := preload("res://scenes/note.tscn")
const EXPECTED_VISUALS := ["GlowOrb", "PaperNote", "SurveyPlate", "VoiceRecorder"]


func _ready() -> void:
	for visual_type in EXPECTED_VISUALS.size():
		var note := NOTE_SCENE.instantiate()
		note.visual_type = visual_type
		add_child(note)
		var visuals := note.get_node_or_null("Visuals")
		if not visuals:
			_fail("Collectible note has no visual variants root")
			return
		var visible_names := []
		for visual in visuals.get_children():
			if visual.visible:
				visible_names.append(str(visual.name))
		if visible_names != [EXPECTED_VISUALS[visual_type]]:
			_fail("Collectible visual %s showed %s" % [visual_type, visible_names])
			return
		note.queue_free()

	var disabled_note := NOTE_SCENE.instantiate()
	disabled_note.enabled_for_gameplay = false
	disabled_note.visual_type = 2
	add_child(disabled_note)
	if disabled_note.visible or disabled_note.monitoring or disabled_note.monitorable:
		_fail("Disabled evidence remained visible or interactive")
		return

	print("[smoke] Collectible evidence visual variants OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
