extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")


func _ready() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.player_id = 42
	add_child(player)
	await get_tree().process_frame

	if (
		not bool(player.call("_is_remote_sync_sender_valid", 42))
		or bool(player.call("_is_remote_sync_sender_valid", 7))
	):
		_fail("Remote player sync sender validation does not match player ownership")
		return

	player.global_position = Vector3.ZERO
	player.call("reset_remote_sync_tracking")
	var sprint_position := Vector3.ZERO
	for _frame in 120:
		sprint_position.x += 5.1 / 60.0
		if not bool(player.call(
			"_try_accept_remote_sync_position",
			sprint_position,
			1.0 / 60.0
		)):
			_fail("Remote sync rejected sustained legal sprint movement")
			return

	player.global_position = Vector3.ZERO
	player.call("reset_remote_sync_tracking")
	if not bool(player.call(
		"_try_accept_remote_sync_position",
		Vector3(2.5, 0.0, 0.0),
		0.5
	)):
		_fail("Remote sync rejected legal movement after a half-second packet gap")
		return
	if bool(player.call(
		"_try_accept_remote_sync_position",
		Vector3(20.0, 0.0, 0.0),
		1.0 / 60.0
	)):
		_fail("Remote sync accepted a horizontal teleport")
		return
	if bool(player.call(
		"_try_accept_remote_sync_position",
		Vector3(2.5, 20.0, 0.0),
		1.0 / 60.0
	)):
		_fail("Remote sync accepted a vertical teleport")
		return
	if bool(player.call(
		"_try_accept_remote_sync_position",
		Vector3(NAN, 0.0, 0.0),
		1.0 / 60.0
	)):
		_fail("Remote sync accepted a non-finite position")
		return

	player.global_position = Vector3(100.0, 0.2, -40.0)
	player.call("reset_remote_sync_tracking")
	if not bool(player.call(
		"_try_accept_remote_sync_position",
		Vector3(100.05, 0.2, -40.0),
		1.0 / 60.0
	)):
		_fail("Respawn baseline reset did not accept movement from the new spawn")
		return

	print("[smoke] Remote player sync ownership and movement budget OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
