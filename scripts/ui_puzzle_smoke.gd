extends Node

const GAME_UI_SCENE := preload("res://scenes/game_ui.tscn")

var ui: GameUi
var completed_notes: Array[String] = []


func _ready() -> void:
	ui = GAME_UI_SCENE.instantiate() as GameUi
	add_child(ui)
	ui.note_puzzle_completed.connect(_on_note_puzzle_completed)
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	await get_tree().process_frame
	var puzzle_types: Array[int] = [
		GameUi.PuzzleType.MATCH_DOTS,
		GameUi.PuzzleType.SEQUENCE_LOCK,
		GameUi.PuzzleType.CODE_LOCK,
		GameUi.PuzzleType.POLARITY_SWITCH,
	]

	for puzzle_type in puzzle_types:
		var note_id := "SmokeNote%s" % puzzle_type
		ui.show_note_puzzle(note_id, "Smoke note", puzzle_type)
		await get_tree().process_frame
		if not ui.puzzle_panel.visible:
			push_error("Puzzle panel did not open for puzzle type %s" % puzzle_type)
			get_tree().quit(1)
			return
		ui._reset_puzzle()
		await get_tree().process_frame
		if puzzle_type == GameUi.PuzzleType.SEQUENCE_LOCK and not _get_numbered_button(0):
			_fail("Signal lock keypad does not provide a zero button")
			return
		if puzzle_type == GameUi.PuzzleType.CODE_LOCK:
			_assert_zero_digit_code_lock()
		_solve_puzzle(puzzle_type)
		await get_tree().process_frame
		if ui.puzzle_panel.visible:
			_fail("Puzzle panel stayed open after solving puzzle type %s" % puzzle_type)
			return
		if not completed_notes.has(note_id):
			_fail("Puzzle type %s did not emit completion" % puzzle_type)
			return

	print("[smoke] UI puzzle modes solve OK")
	get_tree().quit()


func _on_note_puzzle_completed(note_id: String, _note_text: String) -> void:
	completed_notes.append(note_id)


func _solve_puzzle(puzzle_type: int) -> void:
	match puzzle_type:
		GameUi.PuzzleType.MATCH_DOTS:
			_solve_match_dots()
		GameUi.PuzzleType.SEQUENCE_LOCK:
			_solve_sequence_lock()
		GameUi.PuzzleType.CODE_LOCK:
			_solve_code_lock()
		GameUi.PuzzleType.POLARITY_SWITCH:
			_solve_polarity_switch()


func _solve_match_dots() -> void:
	for left_dot in ui.left_dots:
		var left_color := str(left_dot.get_meta("puzzle_color"))
		for right_dot in ui.right_dots:
			if str(right_dot.get_meta("puzzle_color")) == left_color:
				ui._on_puzzle_dot_pressed(left_dot)
				ui._on_puzzle_dot_pressed(right_dot)
				break


func _solve_sequence_lock() -> void:
	for number in ui.sequence_code:
		ui._on_puzzle_dot_pressed(_get_numbered_button(number))


func _solve_code_lock() -> void:
	for character in ui.code_lock_code:
		ui._on_puzzle_dot_pressed(_get_numbered_button(int(character)))


func _assert_zero_digit_code_lock() -> void:
	if not _get_numbered_button(0):
		_fail("Code lock keypad does not provide a zero button")
		return
	ui.code_lock_code = "230"
	if ui._format_code_lock_clue() != "3 4 1":
		_fail("Code lock clue 3 4 1 does not resolve to 230")
		return
	ui._reset_puzzle()


func _solve_polarity_switch() -> void:
	var start_mask := _get_polarity_mask(ui.polarity_states)
	var solution := _find_polarity_solution(start_mask)
	if solution.is_empty() and start_mask != 63:
		_fail("Polarity smoke could not find a solution")
		return
	for button_index in solution:
		ui._on_puzzle_dot_pressed(_get_numbered_button(button_index + 1))


func _find_polarity_solution(start_mask: int) -> Array[int]:
	var queue: Array[Dictionary] = [{"mask": start_mask, "path": []}]
	var visited := {start_mask: true}
	while not queue.is_empty():
		var entry: Dictionary = queue.pop_front()
		var mask := int(entry["mask"])
		var path: Array = entry["path"]
		if mask == 63:
			var typed_path: Array[int] = []
			for index in path:
				typed_path.append(int(index))
			return typed_path
		for index in range(6):
			var next_mask := _toggle_polarity_mask(mask, index)
			if visited.has(next_mask):
				continue
			visited[next_mask] = true
			var next_path := path.duplicate()
			next_path.append(index)
			queue.append({"mask": next_mask, "path": next_path})
	return []


func _toggle_polarity_mask(mask: int, index: int) -> int:
	var affected: Array[int] = [index]
	var row := index % 3
	if row > 0:
		affected.append(index - 1)
	if row < 2:
		affected.append(index + 1)
	if index < 3:
		affected.append(index + 3)
	else:
		affected.append(index - 3)

	for affected_index in affected:
		mask = mask ^ (1 << affected_index)
	return mask


func _get_polarity_mask(states: Array[bool]) -> int:
	var mask := 0
	for index in range(states.size()):
		if states[index]:
			mask |= 1 << index
	return mask


func _get_numbered_button(number: int) -> Button:
	for button in ui.left_dots + ui.right_dots:
		if int(button.get_meta("puzzle_number")) == number:
			return button
	return null


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
