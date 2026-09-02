extends Node

const GAME_UI_SCENE := preload("res://scenes/game_ui.tscn")
const FORBIDDEN_CONTROL_TEXT: Array[String] = [
	"Ctrl:",
	"Shift sprint",
	"Esc frees",
	"Press Q",
	"Press Shift",
]


func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	var ui := GAME_UI_SCENE.instantiate() as GameUi
	add_child(ui)
	await get_tree().process_frame

	ui.update_hud(0, 3)
	if not ui.hud_label.text.contains("Records: 0/3") or ui.hud_label.text.contains("Notes:"):
		_fail("HUD does not describe purposeful pickups as records")
		return
	ui.show_dialogue("Smoke", "Smoke page", 0, 1)
	var rendered_text := "%s\n%s\n%s" % [
		ui.hud_label.text,
		ui.dialogue_hint.text,
		ui.pointer_hint.text,
	]

	for forbidden in FORBIDDEN_CONTROL_TEXT:
		if forbidden in rendered_text:
			_fail("UI control text still contains hardcoded label: %s" % forbidden)
			return

	var long_message := "Purposeful evidence about the copied threshold and the room beyond it. ".repeat(4)
	ui.update_hud(2, 2, long_message)
	ui.set_objective("A two-line objective stays above the recovered evidence without sharing its rectangle.")
	await get_tree().process_frame
	if not ui.hud_label.text.ends_with("...") or ui.hud_label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		_fail("Long recovered evidence is not bounded by the responsive HUD")
		return
	var objective_rect := ui.objective_label.get_global_rect()
	var hud_rect := ui.hud_label.get_global_rect()
	if objective_rect.end.y > hud_rect.position.y:
		_fail("Responsive objective and HUD rectangles overlap: objective=%s hud=%s" % [objective_rect, hud_rect])
		return

	print("[smoke] UI control text OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
