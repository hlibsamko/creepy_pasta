extends Node

const CHASER_SCENE := preload("res://scenes/common/chaser_monster_basic.tscn")


class PlayerProbe extends CharacterBody3D:
	var controlled := true
	var is_sprinting := false

	func _ready() -> void:
		add_to_group("players")

	func has_control() -> bool:
		return controlled


func _ready() -> void:
	var walker := PlayerProbe.new()
	walker.name = "Walker"
	walker.position = Vector3(2.0, 0.0, 0.0)
	add_child(walker)

	var runner := PlayerProbe.new()
	runner.name = "Runner"
	runner.position = Vector3(3.0, 0.0, 0.0)
	runner.is_sprinting = true
	runner.velocity = Vector3(4.0, 0.0, 0.0)
	add_child(runner)

	var first: CorridorMonster = CHASER_SCENE.instantiate()
	first.name = "FirstListener"
	first.target_local_player_only = false
	add_child(first)
	first.set_physics_process(false)

	var second: CorridorMonster = CHASER_SCENE.instantiate()
	second.name = "SecondListener"
	second.target_local_player_only = false
	add_child(second)
	second.set_physics_process(false)

	first.set_knowledge_profile(0.0, 0.0)
	first.call("_face_movement_direction", Vector3.RIGHT)
	if (-first.global_basis.z).dot(Vector3.RIGHT) < 0.99:
		_fail("Listener visual did not turn toward its movement direction")
		return
	if first.get_knowledge_behavior_tier() != 0 or first.call("_find_target") != runner:
		_fail("Baseline Listener did not hear the nearby sprinting player")
		return
	runner.is_sprinting = false
	if first.call("_find_target") != walker:
		_fail("Baseline Listener kept a noisy target after the sprint stopped")
		return

	first.set_knowledge_profile(0.4, 1.0 / 3.0)
	runner.is_sprinting = true
	if first.call("_find_target") != runner:
		_fail("Focused Listener did not acquire the loudest target")
		return
	runner.is_sprinting = false
	walker.position = Vector3(0.5, 0.0, 0.0)
	if first.call("_find_target") != runner:
		_fail("Focused Listener did not remember the noisy player")
		return
	first.call("_update_behavior_memory", first.noisy_target_fixation_seconds + 0.1)
	if first.call("_find_target") != null or float(first.noise_search_remaining) <= 0.0:
		_fail("Focused Listener did not search the last noisy position")
		return

	first.set_knowledge_profile(0.8, 2.0 / 3.0)
	runner.is_sprinting = true
	first.call("_find_target")
	var intercept_point: Vector3 = first.call("_get_chase_position", runner)
	if intercept_point.x <= runner.global_position.x:
		_fail("Intercept Listener did not lead a sprinting target")
		return
	if first.get_knowledge_behavior_tier() != 2 or not first.get_knowledge_behavior_message().contains("cuts ahead"):
		_fail("Intercept Listener did not expose its readable behavior stage")
		return

	second.set_knowledge_profile(0.0, 0.0)
	second.call("_find_target")
	if second.get_knowledge_behavior_tier() != 0 or second.fixated_target != null:
		_fail("Two Listener instances shared knowledge or fixation state")
		return

	print("[smoke] Listener fixation, noise search, and interception variants OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
