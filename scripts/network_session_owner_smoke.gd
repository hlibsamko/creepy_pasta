extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")

var main: Node
var completed := false


func _ready() -> void:
	main = MAIN_SCENE.instantiate()
	main.name = "Main"
	get_tree().root.call_deferred("add_child", main)
	await get_tree().process_frame
	main.network.connected_to_server.connect(_on_connected)
	var error: Error = main.network.join("ws://127.0.0.1:24567")
	if error != OK:
		_fail("Owner could not connect: %s" % error)
		return
	get_tree().create_timer(14.0).timeout.connect(_on_timeout)


func _on_connected() -> void:
	await get_tree().process_frame
	main._server_create_online_session.rpc_id(1)
	await get_tree().create_timer(0.8).timeout
	if str(main.active_session_id) == "":
		_fail("Owner did not create a session")
		return
	await _move_local_player_to(Vector3(-4.9, 0.2, -1.8))
	main._request_collect_note.rpc_id(1, "Note1")
	await get_tree().create_timer(1.0).timeout
	if int(main.collected_notes) != 1:
		_fail("Owner session did not collect Note1")
		return
	await get_tree().create_timer(7.0).timeout
	if int(main.collected_notes) != 1:
		_fail("Another session changed the owner progress")
		return
	completed = true
	print("[smoke] Owner session retained isolated progress")
	get_tree().quit()


func _move_local_player_to(target_position: Vector3) -> void:
	var local_player := main.players.get_node_or_null(str(multiplayer.get_unique_id())) as Node3D
	if not local_player:
		_fail("Owner movement helper could not find the local player")
		return
	var start_position := local_player.global_position
	var step_count := maxi(ceili(start_position.distance_to(target_position) / (4.8 * 0.05)), 1)
	local_player.call("set_controls_enabled", false)
	for step in range(1, step_count + 1):
		var next_position := start_position.lerp(target_position, float(step) / float(step_count))
		local_player.global_position = next_position
		local_player.rpc("_sync_state", next_position, local_player.rotation.y, 0.0)
		await get_tree().create_timer(0.05).timeout
	local_player.call("set_controls_enabled", true)
	await get_tree().create_timer(0.2).timeout


func _on_timeout() -> void:
	if not completed:
		_fail("Owner session isolation smoke timed out")


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
