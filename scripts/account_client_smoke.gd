extends Node

const ACCOUNT_PANEL_SCENE := preload("res://scenes/account_panel.tscn")
const ACCOUNT_SERVICE_SCRIPT := preload("res://scripts/account_service.gd")
const ACCOUNT_PANEL_SCRIPT := preload("res://scripts/account_panel.gd")


func _ready() -> void:
	var service: ACCOUNT_SERVICE_SCRIPT = ACCOUNT_SERVICE_SCRIPT.new()
	add_child(service)
	service.set("_access_token", "smoke-access-token")
	service.set("_refresh_token", "smoke-refresh-token")
	service.set("_profile", service.call("_safe_profile", {
		"display_name": "Smoke Investigator",
		"friend_code": "SMOKE-01",
		"email": "must-not-appear@example.test",
	}))
	service.set("_progress", {
		"verified_playtime_seconds": 5400,
		"death_count": 3,
		"achievements": [
			{"id": "first_record", "title": "First Record", "description": "Recovered one record."},
		],
	})
	service.set("_friends", [
		{"display_name": "Known Friend", "friend_code": "FRIEND-1"},
	])
	service.set("_friend_requests", [
		{"display_name": "Pending Friend", "friend_code": "PENDING-1"},
	])

	var panel: ACCOUNT_PANEL_SCRIPT = ACCOUNT_PANEL_SCENE.instantiate() as ACCOUNT_PANEL_SCRIPT
	panel.refresh_on_open = false
	panel.set_account_service(service)
	add_child(panel)
	await get_tree().process_frame
	if not service.is_authenticated() or not panel.signed_in_box.visible or panel.signed_out_row.visible:
		_fail("Account panel did not render the signed-in state")
		return
	if service.get_profile().has("email"):
		_fail("Account service retained an email in the UI profile")
		return

	panel.show_profile()
	await get_tree().process_frame
	if not panel.is_modal_visible() or "Smoke Investigator" not in panel.profile_name.text:
		_fail("Account profile did not open with the current display name")
		return
	if "1.5 hours" not in panel.playtime_label.text or panel.deaths_label.text != "Deaths: 3":
		_fail("Account profile did not render verified progress")
		return
	if panel.achievements_list.get_child_count() != 1:
		_fail("Account profile did not render achievements")
		return
	if "must-not-appear" in _collect_visible_text(panel):
		_fail("Account UI exposed an email address")
		return

	panel.show_friends()
	await get_tree().process_frame
	if panel.friends_list.get_child_count() != 1 or panel.requests_list.get_child_count() != 1:
		_fail("Account friends view did not render friends and incoming requests")
		return

	service.call("_clear_authenticated_state")
	await get_tree().process_frame
	if panel.signed_in_box.visible or not panel.signed_out_row.visible or panel.is_modal_visible():
		_fail("Account panel did not return to the signed-out state")
		return
	if not str(service.get("_access_token")).is_empty() or not str(service.get("_refresh_token")).is_empty():
		_fail("Account service retained credentials after sign-out")
		return
	var unauthenticated_ticket: Dictionary = await service.create_game_ticket()
	if bool(unauthenticated_ticket.get("ok", true)) \
			or not unauthenticated_ticket.has("ticket") \
			or not unauthenticated_ticket.has("expires_at") \
			or str(unauthenticated_ticket.get("error", "")).is_empty():
		_fail("Game-ticket coroutine did not return the documented unauthenticated result")
		return

	print("[smoke] Account client states OK")
	get_tree().quit()


func _collect_visible_text(root: Node) -> String:
	var values := PackedStringArray()
	for child in root.find_children("*", "Label", true, false):
		var label := child as Label
		if label.visible:
			values.append(label.text)
	return "\n".join(values)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
