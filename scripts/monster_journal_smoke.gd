extends Node

const MONSTER_JOURNAL_SCRIPT := preload("res://scripts/monster_journal.gd")


func _ready() -> void:
	var journal := MONSTER_JOURNAL_SCRIPT.new()
	add_child(journal)
	if journal.unlocked or not journal.discovered_facts.has("listener"):
		_fail("Journal did not initialize locked with known entry slots")
		return
	if journal.get_rendered_text().contains("House Records"):
		_fail("Empty optional House records cluttered the initial bestiary")
		return
	if journal.get_rendered_text().contains("The Unlit"):
		_fail("Empty optional Unlit entry cluttered the initial bestiary")
		return
	if not journal.unlock():
		_fail("Journal did not report its first unlock")
		return
	if not journal.discover("listener", 3):
		_fail("Journal did not record an independent verified fact")
		return
	if journal.has_fact("listener", 1) or journal.has_fact("listener", 2):
		_fail("A later fact implicitly unlocked earlier facts")
		return
	if journal.get_completed_entry_count() != 0:
		_fail("A single later fact completed a creature entry")
		return
	if journal.discover("listener", 3):
		_fail("Journal allowed a duplicate fact discovery")
		return
	if journal.discover("missing", 1):
		_fail("Journal accepted an unknown creature entry")
		return

	if not journal.discover_rumor("listener", "light_barrier"):
		_fail("Journal did not record a known rumor")
		return
	if journal.is_rumor_disputed("listener", "light_barrier"):
		_fail("Journal disputed a rumor before contradictory evidence")
		return
	if not journal.discover("listener", 2) or not journal.is_rumor_disputed("listener", "light_barrier"):
		_fail("Verified evidence did not dispute its linked rumor")
		return
	if not journal.discover_rumor("mimic", "double_pulse_safe"):
		_fail("Journal did not record the second survivor's False Door rumor")
		return
	if not journal.discover_rumor("mimic", "replicated_room"):
		_fail("Journal did not record the room survey theory")
		return
	if journal.is_rumor_disputed("mimic", "double_pulse_safe"):
		_fail("False Door rumor was disputed before its identifying light evidence")
		return
	if not journal.discover("house", 1):
		_fail("Journal did not record optional evidence about the house")
		return
	if not journal.discover("unlit", 2):
		_fail("Journal did not record optional direct observation of The Unlit")
		return
	if journal.get_discovered_fact_count() != 2:
		_fail("Optional House or Unlit evidence changed required bestiary progress")
		return

	var snapshot: Dictionary = journal.get_snapshot()
	journal.reset()
	journal.apply_snapshot(snapshot)
	if not journal.unlocked or not journal.has_fact("listener", 2) or not journal.has_fact("listener", 3):
		_fail("Journal snapshot did not restore independent fact progress")
		return
	if not journal.has_rumor("listener", "light_barrier"):
		_fail("Journal snapshot did not restore rumor progress")
		return
	if not journal.has_rumor("mimic", "double_pulse_safe"):
		_fail("Journal snapshot did not restore the second survivor's rumor")
		return
	if not journal.has_rumor("mimic", "replicated_room"):
		_fail("Journal snapshot did not restore the room survey theory")
		return
	if not journal.has_fact("house", 1):
		_fail("Journal snapshot did not restore optional house evidence")
		return
	if not journal.has_fact("unlit", 2):
		_fail("Journal snapshot did not restore optional Unlit evidence")
		return
	var rendered := journal.get_rendered_text()
	if (
		not rendered.contains("lit rooms")
		or not rendered.contains("DISPUTED")
		or not rendered.contains("Prior radio log")
		or not rendered.contains("Room 2 survey")
		or not rendered.contains("Elias")
		or not rendered.contains("House Records (optional)")
		or not rendered.contains("survey marks")
		or not rendered.contains("The Unlit")
		or rendered.contains("prototype")
		or not rendered.contains("direct beam")
	):
		_fail("Journal rendering omitted creature evidence, sources, or optional records")
		return
	if not is_equal_approx(journal.get_completion_ratio(), 2.0 / 9.0):
		_fail("Journal completion ratio did not reflect independent facts")
		return
	if not is_equal_approx(journal.get_entry_completion_ratio("listener"), 2.0 / 3.0):
		_fail("Journal entry ratio did not reflect Listener-specific evidence")
		return
	if not is_zero_approx(journal.get_entry_completion_ratio("missing")):
		_fail("Unknown journal entry reported knowledge progress")
		return
	if not journal.discover("mimic", 3) or not journal.is_rumor_disputed("mimic", "double_pulse_safe"):
		_fail("Verified double-pulse evidence did not dispute the survivor's rumor")
		return

	journal.discover("listener", 1)
	for fact_index in range(1, 4):
		journal.discover("watcher", fact_index)
		journal.discover("mimic", fact_index)
	if journal.get_completed_entry_count() != 3 or not is_equal_approx(journal.get_completion_ratio(), 1.0):
		_fail("Journal did not report a complete bestiary")
		return
	if not journal.discover("house", 2) or journal.get_completed_entry_count() != 3:
		_fail("Completing optional house records changed the creature count")
		return
	if (
		not journal.discover("unlit", 1)
		or not journal.discover("unlit", 3)
		or journal.get_completed_entry_count() != 3
		or not is_equal_approx(journal.get_completion_ratio(), 1.0)
	):
		_fail("Completing optional Unlit evidence changed required victory progress")
		return

	var legacy_journal := MONSTER_JOURNAL_SCRIPT.new()
	add_child(legacy_journal)
	legacy_journal.apply_snapshot({"unlocked": true, "fact_counts": {"listener": 2}})
	if not legacy_journal.has_fact("listener", 1) or not legacy_journal.has_fact("listener", 2):
		_fail("Journal did not migrate a cumulative legacy snapshot")
		return

	print("[smoke] Monster journal independent evidence OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
