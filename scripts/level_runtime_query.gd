class_name LevelRuntimeQuery
extends RefCounted

## Pure scene-tree queries shared by the runtime coordinator.
##
## Gameplay scenes may reorganize visual children freely as long as their semantic
## nodes keep the signals and methods queried here. Network/RPC ownership remains
## in `main.gd`; this helper only discovers nodes and serializes local state.


static func marker_positions(level_root: Node, prefix: String) -> Array:
	var positions := []
	if not level_root:
		return positions
	for child in level_root.find_children("%s*" % prefix, "Marker3D", true, false):
		positions.append((child as Marker3D).global_position)
	return positions


static func notes(level_root: Node) -> Array:
	var found_notes := []
	if not level_root:
		return found_notes
	for candidate in level_root.find_children("*", "Area3D", true, false):
		if not candidate.has_signal("collected"):
			continue
		if candidate.has_method("is_enabled_for_gameplay") and not bool(candidate.call("is_enabled_for_gameplay")):
			continue
		found_notes.append(candidate)
	return found_notes


static func monsters(level_root: Node) -> Array:
	var found_monsters := []
	if not level_root:
		return found_monsters
	for candidate in level_root.find_children("*", "", true, false):
		if candidate.has_signal("killed_player") or candidate.has_method("stop_chase"):
			found_monsters.append(candidate)
	return found_monsters


static func pressure_plates(level_root: Node) -> Array:
	var found_plates := []
	if not level_root:
		return found_plates
	for candidate in level_root.find_children("*", "Area3D", true, false):
		if candidate.has_signal("active_changed") and candidate.has_method("is_active"):
			found_plates.append(candidate)
	return found_plates


static func note_by_id(level_root: Node, note_id: String) -> Node:
	for note in notes(level_root):
		if note.name == note_id:
			return note
	return null


static func pressure_plate_states(level_root: Node) -> Dictionary:
	var states := {}
	if not level_root:
		return states
	for plate in pressure_plates(level_root):
		states[str(level_root.get_path_to(plate))] = bool(plate.call("is_active"))
	return states


static func apply_pressure_plate_states(level_root: Node, states: Dictionary) -> void:
	if not level_root:
		return
	for plate in pressure_plates(level_root):
		var state_id := str(level_root.get_path_to(plate))
		if not states.has(state_id):
			continue
		if plate.has_method("set_synced_active"):
			plate.call("set_synced_active", bool(states[state_id]))
		elif plate.has_method("set_latched_active"):
			plate.call("set_latched_active", bool(states[state_id]))


static func monster_activation_states(level_root: Node) -> Dictionary:
	var states := {}
	if not level_root:
		return states
	for monster in monsters(level_root):
		if monster.has_method("is_note_gated_activated"):
			states[str(level_root.get_path_to(monster))] = bool(monster.call("is_note_gated_activated"))
	return states


static func apply_monster_activation_states(level_root: Node, states: Dictionary) -> void:
	if not level_root:
		return
	for monster in monsters(level_root):
		var state_id := str(level_root.get_path_to(monster))
		if states.has(state_id) and monster.has_method("set_note_gated_activated"):
			monster.call("set_note_gated_activated", bool(states[state_id]))


static func mechanic_states(level_root: Node) -> Dictionary:
	var states := {}
	if not level_root:
		return states
	for mechanic in level_root.find_children("*", "", true, false):
		if mechanic.has_method("get_sync_state") and mechanic.has_method("apply_sync_state"):
			states[str(level_root.get_path_to(mechanic))] = mechanic.call("get_sync_state")
	return states


static func apply_mechanic_states(level_root: Node, states: Dictionary) -> void:
	if not level_root:
		return
	for mechanic in level_root.find_children("*", "", true, false):
		if not mechanic.has_method("apply_sync_state"):
			continue
		var state_id := str(level_root.get_path_to(mechanic))
		if states.has(state_id) and states[state_id] is Dictionary:
			mechanic.call("apply_sync_state", states[state_id])


static func pressure_plates_satisfied(level_root: Node) -> bool:
	for plate in pressure_plates(level_root):
		if not bool(plate.call("is_active")):
			return false
	return true
