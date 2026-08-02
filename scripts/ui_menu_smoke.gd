extends Node

const GAME_UI_SCENE := preload("res://scenes/game_ui.tscn")

var host_count := 0
var join_count := 0
var offline_count := 0
var reconnect_count := 0
var reset_count := 0
var journal_close_count := 0
var journal_open_count := 0
var create_session_count := 0
var refresh_sessions_count := 0
var joined_session_id := ""


func _ready() -> void:
	var ui := GAME_UI_SCENE.instantiate() as GameUi
	add_child(ui)
	ui.host_requested.connect(func() -> void: host_count += 1)
	ui.join_requested.connect(func(_address: String) -> void: join_count += 1)
	ui.offline_requested.connect(func() -> void: offline_count += 1)
	ui.reconnect_requested.connect(func() -> void: reconnect_count += 1)
	ui.reset_session_requested.connect(func(_address: String) -> void: reset_count += 1)
	ui.create_session_requested.connect(func() -> void: create_session_count += 1)
	ui.refresh_sessions_requested.connect(func() -> void: refresh_sessions_count += 1)
	ui.join_session_requested.connect(func(session_id: String) -> void: joined_session_id = session_id)
	ui.journal_closed.connect(func() -> void:
		journal_close_count += 1
		ui.hide_journal()
	)
	ui.journal_requested.connect(func() -> void: journal_open_count += 1)
	await get_tree().process_frame

	ui.set_join_address("127.0.0.1")
	ui.host_button.pressed.emit()
	ui.join_button.pressed.emit()
	ui.offline_button.pressed.emit()
	ui.reconnect_button.pressed.emit()
	ui.reset_session_button.pressed.emit()
	ui.show_session_browser([{"id": "S001", "name": "Session 001", "level": "Room 2", "players": 1}])
	ui.create_session_button.pressed.emit()
	ui.refresh_sessions_button.pressed.emit()
	var session_row := ui.session_list.get_child(0)
	if str(session_row.get_meta("session_id", "")) != "S001":
		_fail("Session browser row lost its explicit server session ID")
		return
	var session_join_button := session_row.get_node("JoinButton") as Button
	session_join_button.pressed.emit()
	ui.show_session_browser([{"id": "S002", "name": "Session 002", "level": "Room 1", "players": 2}])
	if ui.session_list.get_child_count() != 1:
		_fail("Rapid session-list refresh retained a stale row")
		return
	var refreshed_row := ui.session_list.get_child(0)
	if str(refreshed_row.get_meta("session_id", "")) != "S002":
		_fail("Rapid session-list refresh did not replace the stale session ID")
		return
	(refreshed_row.get_node("JoinButton") as Button).pressed.emit()

	if host_count != 1 or join_count != 1 or offline_count != 1 or reconnect_count != 1 or reset_count != 1:
		_fail("Menu buttons did not emit expected signals")
		return
	if create_session_count != 1 or refresh_sessions_count != 1 or joined_session_id != "S002":
		_fail("Session browser controls did not emit expected signals")
		return
	ui.set_session_status("S001 | 2 players")
	if ui.session_label.visible:
		_fail("In-game session status overlapped the connection menu")
		return

	ui.set_connecting(true)
	if not ui.join_button.disabled or not ui.offline_button.disabled or not ui.reconnect_button.disabled or not ui.reset_session_button.disabled:
		_fail("Connecting state did not disable join/offline/reconnect buttons")
		return
	ui.set_connecting(false)
	if ui.join_button.disabled or ui.offline_button.disabled or ui.reconnect_button.disabled or ui.reset_session_button.disabled:
		_fail("Connecting state did not restore join/offline/reconnect buttons")
		return

	ui.show_menu()
	if not ui.is_menu_visible():
		_fail("Menu did not become visible")
		return
	if not ui.is_blocking_overlay_visible():
		_fail("Visible menu was not treated as a blocking overlay")
		return
	ui.hide_menu()
	if ui.is_menu_visible():
		_fail("Menu did not hide")
		return
	if not ui.session_label.visible or ui.session_label.text != "S001 | 2 players":
		_fail("Compact online session status did not appear during gameplay")
		return
	if ui.is_blocking_overlay_visible():
		_fail("Hidden menu incorrectly blocked gameplay input")
		return
	ui.show_journal("0/2 creatures documented", "No verified observations.")
	if not ui.is_journal_visible() or not ui.is_blocking_overlay_visible():
		_fail("Visible journal did not block gameplay input")
		return
	ui.journal_close_button.pressed.emit()
	if journal_close_count != 1 or ui.is_journal_visible():
		_fail("Journal close button did not emit and hide correctly")
		return
	ui.set_journal_available(true)
	if not ui.journal_button.visible:
		_fail("Available journal button did not appear during gameplay")
		return
	ui.journal_button.pressed.emit()
	if journal_open_count != 1:
		_fail("Journal button did not emit its open request")
		return

	print("[smoke] UI menu OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
