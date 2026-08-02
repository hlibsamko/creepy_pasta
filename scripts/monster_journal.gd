class_name MonsterJournal
extends Node

const ENTRY_ORDER := ["listener", "watcher", "mimic"]
const DISPLAY_ORDER := ["listener", "watcher", "mimic", "unlit", "house"]
const ENTRIES := {
	"listener": {
		"title": "The Listener",
		"facts": [
			"It follows abrupt footsteps and treats sprinting as a beacon.",
			"Once alerted, it follows sound through lit rooms and accelerates toward the loudest moving target.",
			"Walking, closed routes, and broken lines of pursuit can make it search elsewhere.",
		],
		"rumors": {
			"light_barrier": {
				"text": "Bright light is a boundary the Listener cannot cross.",
				"source": "Prior radio log",
				"disputed_by_fact": 2,
			},
		},
	},
	"watcher": {
		"title": "The Watcher",
		"facts": [
			"It becomes dangerous when someone holds its gaze.",
			"Walls and solid cover interrupt whatever passes between its face and yours.",
			"Brief glances are safer than trying to track every movement.",
		],
		"rumors": {},
	},
	"mimic": {
		"title": "The False Door",
		"facts": [
			"It copies familiar doors and sometimes answers in voices taken from the house.",
			"A copied threshold has no draft or room tone behind its glow.",
			"Its light repeats two close pulses; a real opening holds steady.",
		],
		"rumors": {
			"replicated_room": {
				"text": "False Doors only grow where a room has copied its own floor plan.",
				"source": "Room 2 survey",
				"disputed_by_fact": 0,
			},
			"double_pulse_safe": {
				"text": "Two close light pulses mean a doorway is resetting safely.",
				"source": "Elias",
				"disputed_by_fact": 3,
			},
		},
	},
	"unlit": {
		"title": "The Unlit",
		"facts": [
			"Maintenance surveys kept its silhouette inside one chalk mark only while a work lamp faced it.",
			"A direct beam turns its warning band cold and stops its approach until the light moves away.",
			"A breaker outage releases it even while the floor switch remains held.",
		],
		"rumors": {},
	},
	"house": {
		"title": "House Records (optional)",
		"facts": [
			"Chalk survey marks can remain fixed while the corridor around them changes.",
			"Maintenance labels count downward and restart at zero, as if copied rooms are being indexed.",
			"The copies preserve measurements first; air movement and room tone fail before the shape does.",
		],
		"rumors": {},
	},
}

var unlocked := false
var discovered_facts := {}
var discovered_rumors := {}


func _ready() -> void:
	reset()


func reset() -> void:
	unlocked = false
	discovered_facts.clear()
	discovered_rumors.clear()
	for entry_id in DISPLAY_ORDER:
		discovered_facts[entry_id] = []
		discovered_rumors[entry_id] = []


func unlock() -> bool:
	if unlocked:
		return false
	unlocked = true
	return true


func discover(entry_id: String, fact_index: int) -> bool:
	if not is_valid_fact(entry_id, fact_index):
		return false
	var facts: Array = discovered_facts[entry_id]
	if facts.has(fact_index):
		return false
	facts.append(fact_index)
	facts.sort()
	return true


func discover_rumor(entry_id: String, rumor_id: String) -> bool:
	if not is_valid_rumor(entry_id, rumor_id):
		return false
	var rumors: Array = discovered_rumors[entry_id]
	if rumors.has(rumor_id):
		return false
	rumors.append(rumor_id)
	return true


func has_fact(entry_id: String, fact_index: int) -> bool:
	return is_valid_entry(entry_id) and (discovered_facts[entry_id] as Array).has(fact_index)


func has_rumor(entry_id: String, rumor_id: String) -> bool:
	return is_valid_entry(entry_id) and (discovered_rumors[entry_id] as Array).has(rumor_id)


func is_rumor_disputed(entry_id: String, rumor_id: String) -> bool:
	if not has_rumor(entry_id, rumor_id):
		return false
	var rumor: Dictionary = (ENTRIES[entry_id]["rumors"] as Dictionary)[rumor_id]
	var disputed_by_fact := int(rumor.get("disputed_by_fact", 0))
	return disputed_by_fact > 0 and has_fact(entry_id, disputed_by_fact)


func is_valid_entry(entry_id: String) -> bool:
	return ENTRIES.has(entry_id)


func is_valid_fact(entry_id: String, fact_index: int) -> bool:
	return is_valid_entry(entry_id) and fact_index >= 1 and fact_index <= get_fact_total(entry_id)


func is_valid_rumor(entry_id: String, rumor_id: String) -> bool:
	if not is_valid_entry(entry_id) or rumor_id == "":
		return false
	return (ENTRIES[entry_id]["rumors"] as Dictionary).has(rumor_id)


func get_fact_total(entry_id: String) -> int:
	if not is_valid_entry(entry_id):
		return 0
	return (ENTRIES[entry_id]["facts"] as Array).size()


func get_completed_entry_count() -> int:
	var completed := 0
	for entry_id in ENTRY_ORDER:
		if (discovered_facts[entry_id] as Array).size() >= get_fact_total(entry_id):
			completed += 1
	return completed


func get_discovered_fact_count() -> int:
	var discovered := 0
	for entry_id in ENTRY_ORDER:
		discovered += (discovered_facts[entry_id] as Array).size()
	return discovered


func get_total_fact_count() -> int:
	var total := 0
	for entry_id in ENTRY_ORDER:
		total += get_fact_total(entry_id)
	return total


func get_completion_ratio() -> float:
	var total := get_total_fact_count()
	if total <= 0:
		return 0.0
	return float(get_discovered_fact_count()) / float(total)


func get_entry_completion_ratio(entry_id: String) -> float:
	var total := get_fact_total(entry_id)
	if total <= 0:
		return 0.0
	return float((discovered_facts[entry_id] as Array).size()) / float(total)


func get_snapshot() -> Dictionary:
	return {
		"unlocked": unlocked,
		"discovered_facts": discovered_facts.duplicate(true),
		"discovered_rumors": discovered_rumors.duplicate(true),
	}


func apply_snapshot(snapshot: Dictionary) -> void:
	reset()
	unlocked = bool(snapshot.get("unlocked", false))
	var synced_facts: Dictionary = snapshot.get("discovered_facts", {})
	var synced_rumors: Dictionary = snapshot.get("discovered_rumors", {})
	for entry_id in DISPLAY_ORDER:
		for fact_index in synced_facts.get(entry_id, []):
			discover(entry_id, int(fact_index))
		for rumor_id in synced_rumors.get(entry_id, []):
			discover_rumor(entry_id, str(rumor_id))

	# Accept snapshots from builds that stored a cumulative fact count.
	var legacy_counts: Dictionary = snapshot.get("fact_counts", {})
	for entry_id in ENTRY_ORDER:
		for fact_index in range(1, int(legacy_counts.get(entry_id, 0)) + 1):
			discover(entry_id, fact_index)


func get_progress_text() -> String:
	return "%s/%s creatures | %s/%s verified" % [
		get_completed_entry_count(),
		ENTRY_ORDER.size(),
		get_discovered_fact_count(),
		get_total_fact_count(),
	]


func get_rendered_text() -> String:
	var sections := PackedStringArray()
	for entry_id in DISPLAY_ORDER:
		if not _should_render_entry(entry_id):
			continue
		var entry: Dictionary = ENTRIES[entry_id]
		var facts: Array = entry["facts"]
		var lines := PackedStringArray()
		lines.append("[font_size=22]%s[/font_size]" % entry["title"])
		if (discovered_facts[entry_id] as Array).is_empty():
			lines.append("[color=#777777]No verified observations.[/color]")
		for index in range(facts.size()):
			if has_fact(entry_id, index + 1):
				lines.append("- %s" % facts[index])
			else:
				lines.append("[color=#666666]- Unverified[/color]")
		_append_rumors(lines, entry_id)
		sections.append("\n".join(lines))
	return "\n\n".join(sections)


func _should_render_entry(entry_id: String) -> bool:
	if ENTRY_ORDER.has(entry_id):
		return true
	return (
		not (discovered_facts[entry_id] as Array).is_empty()
		or not (discovered_rumors[entry_id] as Array).is_empty()
	)


func _append_rumors(lines: PackedStringArray, entry_id: String) -> void:
	for rumor_id in discovered_rumors[entry_id]:
		var rumor: Dictionary = (ENTRIES[entry_id]["rumors"] as Dictionary)[rumor_id]
		var source := str(rumor.get("source", "Unknown source"))
		if is_rumor_disputed(entry_id, rumor_id):
			lines.append("[color=#9b7777][s]Rumor (%s): %s[/s]  DISPUTED[/color]" % [source, rumor["text"]])
		else:
			lines.append("[color=#d7b45a]Rumor (%s): %s[/color]" % [source, rumor["text"]])
