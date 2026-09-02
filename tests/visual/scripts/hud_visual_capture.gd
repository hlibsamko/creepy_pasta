extends Node

@onready var ui: GameUi = $Ui


func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	ui.hide_menu()
	ui.hide_death()
	ui.hide_victory()
	ui.hide_dialogue()
	ui.hide_journal()
	ui.set_session_status("S014 | 2 players")
	ui.set_objective("Survey the repeated hall, compare its two thresholds, and recover the room record.")
	ui.update_hud(
		1,
		1,
		"Survey record: this copy matches every measurement, but its false threshold has no draft and returns no room tone. Shape survives before air and sound."
	)
