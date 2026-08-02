extends Node

const GAME_UI_SCENE := preload("res://scenes/game_ui.tscn")

var retry_count := 0
var menu_count := 0


func _ready() -> void:
	var ui := GAME_UI_SCENE.instantiate() as GameUi
	add_child(ui)
	ui.retry_requested.connect(_on_retry_requested)
	ui.main_menu_requested.connect(_on_main_menu_requested)
	await get_tree().process_frame

	ui.show_death("Smoke death reason")
	if not ui.death_panel.visible or not ui.is_death_visible() or ui.is_victory_visible():
		_fail("Death panel did not become visible")
		return
	if ui.death_reason_label.text != "Smoke death reason":
		_fail("Death reason was not applied")
		return
	ui.death_retry_button.pressed.emit()
	ui.death_menu_button.pressed.emit()

	ui.hide_death()
	ui.show_victory("Smoke victory summary")
	if not ui.victory_panel.visible or not ui.is_victory_visible() or ui.is_death_visible():
		_fail("Victory panel did not become visible")
		return
	if ui.victory_text.text != "Smoke victory summary":
		_fail("Victory summary was not applied")
		return
	ui.victory_retry_button.pressed.emit()
	ui.victory_menu_button.pressed.emit()

	if retry_count != 2:
		_fail("End-state retry buttons emitted %s times instead of 2" % retry_count)
		return
	if menu_count != 2:
		_fail("End-state menu buttons emitted %s times instead of 2" % menu_count)
		return
	ui.show_threat_warning(0.35, 2.1)
	if not ui.threat_warning.visible or "2.1s" not in ui.threat_warning.text:
		_fail("Watcher gaze warning did not show its countdown")
		return
	ui.hide_threat_warning()
	if ui.threat_warning.visible:
		_fail("Watcher gaze warning did not clear")
		return

	print("[smoke] UI end states OK")
	get_tree().quit()


func _on_retry_requested() -> void:
	retry_count += 1


func _on_main_menu_requested() -> void:
	menu_count += 1


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
