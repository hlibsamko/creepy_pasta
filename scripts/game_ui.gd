class_name GameUi
extends CanvasLayer

signal host_requested
signal join_requested(ip_address: String)
signal offline_requested
signal note_puzzle_completed(note_id: String, note_text: String)
signal note_puzzle_cancelled(note_id: String)

@onready var menu: Control = $Menu
@onready var status_label: Label = $Menu/Panel/Margin/Box/StatusLabel
@onready var ip_edit: LineEdit = $Menu/Panel/Margin/Box/IpEdit
@onready var host_button: Button = $Menu/Panel/Margin/Box/Buttons/HostButton
@onready var join_button: Button = $Menu/Panel/Margin/Box/Buttons/JoinButton
@onready var offline_button: Button = $Menu/Panel/Margin/Box/Buttons/OfflineButton
@onready var hud_label: Label = $HudLabel
@onready var puzzle_panel: Control = $PuzzlePanel
@onready var puzzle_text: Label = $PuzzlePanel/Panel/Margin/Box/PuzzleText
@onready var puzzle_progress: Label = $PuzzlePanel/Panel/Margin/Box/PuzzleProgress
@onready var reset_puzzle_button: Button = $PuzzlePanel/Panel/Margin/Box/PuzzleButtons/ResetPuzzleButton
@onready var close_puzzle_button: Button = $PuzzlePanel/Panel/Margin/Box/PuzzleButtons/ClosePuzzleButton
@onready var death_panel: Control = $DeathPanel
@onready var death_reason_label: Label = $DeathPanel/Panel/Margin/Box/DeathReason
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
var selected_dot: Button
var selected_color := ""
var selected_side := ""
var matched_pairs := 0
var extra_hint := ""


func _ready() -> void:
	host_button.pressed.connect(host_requested.emit)
	join_button.pressed.connect(_emit_join_requested)
	offline_button.pressed.connect(offline_requested.emit)
	reset_puzzle_button.pressed.connect(_reset_puzzle)
	close_puzzle_button.pressed.connect(_cancel_puzzle)
	for dot in left_dots:
		_connect_puzzle_dot(dot, "left")
	for dot in right_dots:
		_connect_puzzle_dot(dot, "right")
	puzzle_panel.hide()
	death_panel.hide()
	dialogue_panel.hide()
	if OS.has_feature("web"):
		host_button.disabled = true
		host_button.tooltip_text = "Browser builds can join WebSocket servers, but cannot host ENet games."
		status_label.text = "Join the online server or play offline."


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


func show_death(reason: String) -> void:
	puzzle_panel.hide()
	menu.hide()
	death_reason_label.text = reason
	death_panel.show()


func hide_death() -> void:
	death_panel.hide()


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
	var text := "WASD + mouse. Shift sprint. Esc frees cursor. Notes: %s/%s" % [collected_notes, total_notes]
	if extra_hint != "":
		text += " | %s" % extra_hint
	if last_note != "":
		text += " | %s" % last_note
	hud_label.text = text


func set_extra_hint(text: String) -> void:
	extra_hint = text


func show_note_puzzle(note_id: String, note_text: String) -> void:
	active_note_id = note_id
	active_note_text = note_text
	puzzle_text.text = "Connect the matching colored dots to pick up this fragment."
	_apply_random_puzzle_layout(note_id)
	_reset_puzzle()
	puzzle_panel.show()


func _emit_join_requested() -> void:
	join_requested.emit(ip_edit.text)


func _connect_puzzle_dot(dot: Button, side: String) -> void:
	dot.set_meta("puzzle_side", side)
	dot.pressed.connect(_on_puzzle_dot_pressed.bind(dot))


func _on_puzzle_dot_pressed(dot: Button) -> void:
	if dot.disabled:
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
	puzzle_progress.text = "Pairs connected: 0/3"
	for dot in left_dots + right_dots:
		dot.disabled = false
		dot.text = "o"


func _cancel_puzzle() -> void:
	puzzle_panel.hide()
	note_puzzle_cancelled.emit(active_note_id)


func _format_dialogue_text(text: String) -> String:
	return text.replace("**The Corridor Monster**", "[b]The Corridor Monster[/b]")
