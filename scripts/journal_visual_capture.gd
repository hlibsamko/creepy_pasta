extends Node

@onready var ui: GameUi = $GameUi
@onready var journal: MonsterJournal = $MonsterJournal

var frame_index := 0


func _ready() -> void:
	journal.unlock()
	journal.discover("listener", 2)
	journal.discover_rumor("listener", "light_barrier")
	journal.discover_rumor("mimic", "replicated_room")
	journal.discover_rumor("mimic", "double_pulse_safe")
	journal.discover("mimic", 3)
	ui.hide_menu()
	ui.show_journal(journal.get_progress_text(), journal.get_rendered_text())


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index == 15:
		ui.journal_body.scroll_to_line(9)
