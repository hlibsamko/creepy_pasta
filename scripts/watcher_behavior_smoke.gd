extends Node3D

const WATCHER_SCENE := preload("res://scenes/common/watcher_monster_basic.tscn")

class ControlledProbe extends Node3D:
	var controlled := true
	var camera: Camera3D

	func _ready() -> void:
		add_to_group("players")
		var head := Node3D.new()
		head.name = "Head"
		add_child(head)
		camera = Camera3D.new()
		camera.name = "Camera3D"
		head.add_child(camera)

	func has_control() -> bool:
		return controlled


func _ready() -> void:
	var watcher := WATCHER_SCENE.instantiate() as WatcherMonster
	watcher.position = Vector3(0.0, 0.0, 0.0)
	add_child(watcher)
	var probe := ControlledProbe.new()
	probe.position = Vector3(0.0, 0.0, 4.0)
	add_child(probe)
	await get_tree().process_frame

	watcher.set_knowledge_profile(0.0, 0.0)
	watcher.call("_process", 0.5)
	var baseline_stare := watcher.stare_time
	probe.camera.rotation.y = PI
	watcher.call("_process", 0.25)
	if watcher.stare_time >= baseline_stare or watcher.gaze_warning_active:
		_fail("Baseline Watcher did not calm immediately after gaze broke")
		return

	watcher.stare_time = 0.0
	probe.camera.rotation.y = 0.0
	watcher.set_knowledge_profile(0.4, 1.0 / 3.0)
	watcher.call("_process", 0.5)
	var remembered_stare := watcher.stare_time
	probe.camera.rotation.y = PI
	watcher.call("_process", 0.4)
	if not is_equal_approx(watcher.stare_time, remembered_stare) or not watcher.gaze_warning_active:
		_fail("Learned Watcher did not retain attention during its warning hold")
		return

	var advanced_positions := []
	watcher.advanced.connect(func(position: Vector3) -> void: advanced_positions.append(position))
	watcher.stare_time = 0.0
	watcher.attention_hold_remaining = 0.0
	watcher.position = Vector3.ZERO
	probe.camera.rotation.y = 0.0
	watcher.set_knowledge_profile(0.7, 2.0 / 3.0)
	watcher.call("_process", 0.1)
	probe.camera.rotation.y = PI
	watcher.call("_process", watcher.attention_hold_seconds)
	watcher.call("_process", 0.01)
	if advanced_positions.size() != 1 or watcher.position.z <= 0.0:
		_fail("Advanced Watcher did not take one clear step toward its last observer")
		return
	watcher.call("_process", 1.0)
	if advanced_positions.size() != 1:
		_fail("Advanced Watcher repeated movement without a new gaze")
		return
	if watcher.stare_time_to_kill < 3.0:
		_fail("Knowledge progression removed the Watcher's three-second safety buffer")
		return

	print("[smoke] Watcher attention memory and learned step OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
