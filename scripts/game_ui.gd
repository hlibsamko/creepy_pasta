class_name GameUi
extends CanvasLayer

signal host_requested
signal join_requested(ip_address: String)
signal offline_requested
signal reconnect_requested
signal retry_requested
signal main_menu_requested
signal note_puzzle_completed(note_id: String, note_text: String)
signal note_puzzle_cancelled(note_id: String)

enum PuzzleType {
	MATCH_DOTS,
	SEQUENCE_LOCK,
	CODE_LOCK,
}

@onready var menu: Control = $Menu
@onready var status_label: Label = $Menu/Panel/Margin/Box/StatusLabel
@onready var ip_edit: LineEdit = $Menu/Panel/Margin/Box/IpEdit
@onready var host_button: Button = $Menu/Panel/Margin/Box/Buttons/HostButton
@onready var join_button: Button = $Menu/Panel/Margin/Box/Buttons/JoinButton
@onready var offline_button: Button = $Menu/Panel/Margin/Box/Buttons/OfflineButton
@onready var reconnect_button: Button = $Menu/Panel/Margin/Box/Buttons/ReconnectButton
@onready var fullscreen_button: Button = $Menu/Panel/Margin/Box/Buttons/FullscreenButton
@onready var version_label: Label = $Menu/Panel/Margin/Box/VersionLabel
@onready var hud_label: Label = $HudLabel
@onready var objective_label: Label = $ObjectiveLabel
@onready var pointer_hint: Label = $PointerHint
@onready var level_banner: Label = $LevelBanner
@onready var puzzle_panel: Control = $PuzzlePanel
@onready var puzzle_text: Label = $PuzzlePanel/Panel/Margin/Box/PuzzleText
@onready var puzzle_progress: Label = $PuzzlePanel/Panel/Margin/Box/PuzzleProgress
@onready var reset_puzzle_button: Button = $PuzzlePanel/Panel/Margin/Box/PuzzleButtons/ResetPuzzleButton
@onready var close_puzzle_button: Button = $PuzzlePanel/Panel/Margin/Box/PuzzleButtons/ClosePuzzleButton
@onready var death_panel: Control = $DeathPanel
@onready var death_reason_label: Label = $DeathPanel/Panel/Margin/Box/DeathReason
@onready var death_retry_button: Button = $DeathPanel/Panel/Margin/Box/DeathButtons/RetryButton
@onready var death_menu_button: Button = $DeathPanel/Panel/Margin/Box/DeathButtons/MenuButton
@onready var victory_panel: Control = $VictoryPanel
@onready var victory_text: Label = $VictoryPanel/Panel/Margin/Box/VictoryText
@onready var victory_retry_button: Button = $VictoryPanel/Panel/Margin/Box/VictoryButtons/RetryButton
@onready var victory_menu_button: Button = $VictoryPanel/Panel/Margin/Box/VictoryButtons/MenuButton
@onready var dialogue_panel: Control = $DialoguePanel
@onready var dialogue_speaker: Label = $DialoguePanel/Panel/Margin/Box/Speaker
@onready var dialogue_body: RichTextLabel = $DialoguePanel/Panel/Margin/Box/Body
@onready var dialogue_hint: Label = $DialoguePanel/Panel/Margin/Box/Hint

@onready var left_dots: Array[Button] = [
	$PuzzlePanel/Panel/Margin/Box/Dots/LeftDots/RedLeft,
	$PuzzlePanel/Panel/Margin/Box/Dots/LeftDots/BlueLeft,
	$PuzzlePanel/Panel/Margin/Box/Dots/LeftDots/GreenLeft,
]
@onready var right_dots: Array[Button] = [
	$PuzzlePanel/Panel/Margin/Box/Dots/RightDots/BlueRight,
	$PuzzlePanel/Panel/Margin/Box/Dots/RightDots/GreenRight,
	$PuzzlePanel/Panel/Margin/Box/Dots/RightDots/RedRight,
]

var active_note_id := ""
var active_note_text := ""
var active_puzzle_type := PuzzleType.MATCH_DOTS
var selected_dot: Button
var selected_color := ""
var selected_side := ""
var matched_pairs := 0
var sequence_code: Array[int] = []
var sequence_index := 0
var code_lock_code := ""
var code_lock_input := ""
var extra_hint := ""
var level_banner_tween: Tween


func _ready() -> void:
	version_label.text = GameVersion.get_display_version()
	host_button.pressed.connect(host_requested.emit)
	join_button.pressed.connect(_emit_join_requested)
	offline_button.pressed.connect(offline_requested.emit)
	reconnect_button.pressed.connect(reconnect_requested.emit)
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	reset_puzzle_button.pressed.connect(_reset_puzzle)
	close_puzzle_button.pressed.connect(_cancel_puzzle)
	death_retry_button.pressed.connect(retry_requested.emit)
	death_menu_button.pressed.connect(main_menu_requested.emit)
	victory_retry_button.pressed.connect(retry_requested.emit)
	victory_menu_button.pressed.connect(main_menu_requested.emit)
	for dot in left_dots:
		_connect_puzzle_dot(dot, "left")
	for dot in right_dots:
		_connect_puzzle_dot(dot, "right")
	pointer_hint.hide()
	level_banner.hide()
	puzzle_panel.hide()
	death_panel.hide()
	victory_panel.hide()
	dialogue_panel.hide()
	if OS.has_feature("web"):
		host_button.hide()
		ip_edit.hide()
		join_button.text = "Play Online"
		offline_button.text = "Play Offline"
		status_label.text = "Desktop browser recommended. Start online or play offline."


func set_join_address(address: String) -> void:
	ip_edit.text = address
	ip_edit.placeholder_text = address


func show_menu() -> void:
	menu.show()


func hide_menu() -> void:
	menu.hide()


func is_menu_visible() -> bool:
	return menu.visible


func set_status(text: String) -> void:
	status_label.text = text


func set_connecting(is_connecting: bool) -> void:
	join_button.disabled = is_connecting
	reconnect_button.disabled = is_connecting
	offline_button.disabled = is_connecting


func show_pointer_hint() -> void:
	pointer_hint.show()


func hide_pointer_hint() -> void:
	pointer_hint.hide()


func show_level_banner(text: String) -> void:
	if level_banner_tween:
		level_banner_tween.kill()
	level_banner.text = text
	level_banner.modulate.a = 1.0
	level_banner.show()
	level_banner_tween = create_tween()
	level_banner_tween.tween_interval(1.4)
	level_banner_tween.tween_property(level_banner, "modulate:a", 0.0, 0.55)
	level_banner_tween.tween_callback(level_banner.hide)


func show_death(reason: String) -> void:
	pointer_hint.hide()
	level_banner.hide()
	puzzle_panel.hide()
	menu.hide()
	death_reason_label.text = reason
	death_panel.show()


func hide_death() -> void:
	death_panel.hide()


func show_victory(summary := "") -> void:
	pointer_hint.hide()
	level_banner.hide()
	puzzle_panel.hide()
	menu.hide()
	death_panel.hide()
	if summary != "":
		victory_text.text = summary
	victory_panel.show()


func hide_victory() -> void:
	victory_panel.hide()


func show_dialogue(speaker: String, text: String, page_index: int, page_count: int) -> void:
	dialogue_speaker.text = speaker
	dialogue_body.text = _format_dialogue_text(text)
	dialogue_hint.text = "Ctrl: next (%s/%s)" % [page_index + 1, page_count]
	dialogue_panel.show()


func hide_dialogue() -> void:
	dialogue_panel.hide()


func is_dialogue_visible() -> bool:
	return dialogue_panel.visible


func update_hud(collected_notes: int, total_notes: int, last_note := "") -> void:
	var text := "%s | Move keys + mouse. Shift sprint. Esc frees cursor. Notes: %s/%s" % [GameVersion.get_display_version(), collected_notes, total_notes]
	if extra_hint != "":
		text += " | %s" % extra_hint
	if last_note != "":
		text += " | %s" % last_note
	hud_label.text = text


func set_objective(text: String) -> void:
	objective_label.text = text
	objective_label.visible = text != ""


func set_extra_hint(text: String) -> void:
	extra_hint = text


func show_note_puzzle(note_id: String, note_text: String, puzzle_type := PuzzleType.MATCH_DOTS) -> void:
	pointer_hint.hide()
	active_note_id = note_id
	active_note_text = note_text
	active_puzzle_type = puzzle_type
	if active_puzzle_type == PuzzleType.CODE_LOCK:
		_apply_code_lock_layout(note_id)
	elif active_puzzle_type == PuzzleType.SEQUENCE_LOCK:
		_apply_sequence_puzzle_layout(note_id)
	else:
		puzzle_text.text = "Connect the matching colored dots to pick up this fragment."
		_apply_random_puzzle_layout(note_id)
	_reset_puzzle()
	puzzle_panel.show()


func _emit_join_requested() -> void:
	join_requested.emit(ip_edit.text)


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _connect_puzzle_dot(dot: Button, side: String) -> void:
	dot.set_meta("puzzle_side", side)
	dot.pressed.connect(_on_puzzle_dot_pressed.bind(dot))


func _on_puzzle_dot_pressed(dot: Button) -> void:
	if dot.disabled:
		return
	if active_puzzle_type == PuzzleType.CODE_LOCK:
		_on_code_button_pressed(dot)
		return
	if active_puzzle_type == PuzzleType.SEQUENCE_LOCK:
		_on_sequence_button_pressed(dot)
		return

	var color_name := str(dot.get_meta("puzzle_color"))
	var side := str(dot.get_meta("puzzle_side"))
	if not selected_dot:
		_select_dot(dot, color_name, side)
		return

	if selected_side == side:
		_clear_selected_dot()
		_select_dot(dot, color_name, side)
		return

	if selected_color == color_name:
		_complete_pair(dot)
	else:
		_clear_selected_dot()
		puzzle_progress.text = "Wrong colors. Try again."


func _select_dot(dot: Button, color_name: String, side: String) -> void:
	selected_dot = dot
	selected_color = color_name
	selected_side = side
	dot.text = "X"
	puzzle_progress.text = "Now choose the matching dot."


func _complete_pair(dot: Button) -> void:
	selected_dot.disabled = true
	dot.disabled = true
	selected_dot.text = "OK"
	dot.text = "OK"
	selected_dot = null
	selected_color = ""
	selected_side = ""
	matched_pairs += 1
	puzzle_progress.text = "Pairs connected: %s/3" % matched_pairs
	if matched_pairs >= 3:
		puzzle_panel.hide()
		note_puzzle_completed.emit(active_note_id, active_note_text)


func _clear_selected_dot() -> void:
	if selected_dot and not selected_dot.disabled:
		selected_dot.text = "o"
	selected_dot = null
	selected_color = ""
	selected_side = ""


func _apply_random_puzzle_layout(note_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(note_id.hash())

	var colors := [
		{"name": "red", "value": Color(1.0, 0.22, 0.18)},
		{"name": "blue", "value": Color(0.28, 0.55, 1.0)},
		{"name": "green", "value": Color(0.25, 0.95, 0.45)},
		{"name": "yellow", "value": Color(1.0, 0.86, 0.22)},
		{"name": "purple", "value": Color(0.74, 0.42, 1.0)},
		{"name": "cyan", "value": Color(0.24, 0.95, 0.95)},
	]
	var picked := _pick_random_entries(colors, 3, rng)
	var left_layout := _shuffled_entries(picked, rng)
	var right_layout := _shuffled_entries(picked, rng)

	_apply_dot_layout(left_dots, left_layout)
	_apply_dot_layout(right_dots, right_layout)


func _apply_sequence_puzzle_layout(note_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(note_id.hash())
	sequence_code.clear()
	for _i in range(4):
		sequence_code.append(rng.randi_range(1, 6))

	var buttons := left_dots + right_dots
	for index in range(buttons.size()):
		var button := buttons[index]
		var number := index + 1
		button.set_meta("puzzle_number", number)
		button.self_modulate = Color(0.78, 0.86, 0.72)
		button.text = str(number)
	puzzle_text.text = "Repeat the signal: %s" % _format_sequence_code()


func _apply_code_lock_layout(note_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(note_id.hash())
	var first := rng.randi_range(1, 6)
	var second := rng.randi_range(1, 6)
	var third := rng.randi_range(1, 6)
	code_lock_code = "%s%s%s" % [first, second, third]
	code_lock_input = ""

	var buttons := left_dots + right_dots
	for index in range(buttons.size()):
		var button := buttons[index]
		var number := index + 1
		button.set_meta("puzzle_number", number)
		button.self_modulate = Color(0.82, 0.78, 0.62)
		button.text = str(number)
	puzzle_text.text = "Enter the three-number door code. Clue: each digit is one lower than %s." % _format_code_lock_clue()


func _on_sequence_button_pressed(dot: Button) -> void:
	var pressed_number := int(dot.get_meta("puzzle_number"))
	if pressed_number != sequence_code[sequence_index]:
		sequence_index = 0
		puzzle_progress.text = "Wrong signal. Sequence reset."
		return

	sequence_index += 1
	puzzle_progress.text = "Signal steps: %s/%s" % [sequence_index, sequence_code.size()]
	if sequence_index >= sequence_code.size():
		puzzle_panel.hide()
		note_puzzle_completed.emit(active_note_id, active_note_text)


func _on_code_button_pressed(dot: Button) -> void:
	code_lock_input += str(int(dot.get_meta("puzzle_number")))
	puzzle_progress.text = "Code entered: %s/%s" % [code_lock_input.length(), code_lock_code.length()]

	if code_lock_input.length() < code_lock_code.length():
		return

	if code_lock_input == code_lock_code:
		puzzle_panel.hide()
		note_puzzle_completed.emit(active_note_id, active_note_text)
	else:
		code_lock_input = ""
		puzzle_progress.text = "Wrong code. Try again."


func _format_sequence_code() -> String:
	var parts: Array[String] = []
	for number in sequence_code:
		parts.append(str(number))
	return " ".join(parts)


func _format_code_lock_clue() -> String:
	var parts: Array[String] = []
	for character in code_lock_code:
		var number := int(character)
		parts.append(str((number % 6) + 1))
	return " ".join(parts)


func _pick_random_entries(entries: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var available := entries.duplicate()
	var picked := []
	for _i in range(count):
		var index := rng.randi_range(0, available.size() - 1)
		picked.append(available[index])
		available.remove_at(index)
	return picked


func _shuffled_entries(entries: Array, rng: RandomNumberGenerator) -> Array:
	var shuffled := entries.duplicate()
	for index in range(shuffled.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var entry = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = entry
	return shuffled


func _apply_dot_layout(dots: Array[Button], colors: Array) -> void:
	for index in range(dots.size()):
		var dot := dots[index]
		var color_data: Dictionary = colors[index]
		var dot_color: Color = color_data["value"]
		dot.set_meta("puzzle_color", str(color_data["name"]))
		dot.self_modulate = dot_color


func _reset_puzzle() -> void:
	selected_dot = null
	selected_color = ""
	selected_side = ""
	matched_pairs = 0
	sequence_index = 0
	code_lock_input = ""
	if active_puzzle_type == PuzzleType.CODE_LOCK:
		puzzle_progress.text = "Code entered: 0/%s" % code_lock_code.length()
	elif active_puzzle_type == PuzzleType.SEQUENCE_LOCK:
		puzzle_progress.text = "Signal steps: 0/%s" % sequence_code.size()
	else:
		puzzle_progress.text = "Pairs connected: 0/3"
	for dot in left_dots + right_dots:
		dot.disabled = false
		if active_puzzle_type == PuzzleType.SEQUENCE_LOCK or active_puzzle_type == PuzzleType.CODE_LOCK:
			dot.text = str(dot.get_meta("puzzle_number"))
		else:
			dot.text = "o"


func _cancel_puzzle() -> void:
	puzzle_panel.hide()
	note_puzzle_cancelled.emit(active_note_id)


func _format_dialogue_text(text: String) -> String:
	return text.replace("**The Corridor Monster**", "[b]The Corridor Monster[/b]")
