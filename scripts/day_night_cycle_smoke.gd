extends Node


func _ready() -> void:
	var cycle := DayNightCycle.new()
	cycle.enabled = false
	add_child(cycle)

	var first_level := _create_test_level("FirstLightingLevel", 1.0)
	add_child(first_level)
	cycle.set_target_level(first_level)
	cycle.set_cycle_length(1.0)
	if not is_equal_approx(cycle.get_cycle_length(), 10.0):
		_fail("Day/night cycle length did not clamp to minimum")
		return

	var first_light := first_level.get_node("TestLight") as Light3D
	var first_energy := first_light.light_energy
	cycle.time_of_day = 0.0
	cycle.call("_apply_cycle")
	if is_equal_approx(first_light.light_energy, first_energy):
		_fail("Day/night cycle did not change light energy")
		return
	var first_energy_after_cycle := first_light.light_energy

	var second_level := _create_test_level("SecondLightingLevel", 2.0)
	add_child(second_level)
	cycle.set_target_level(second_level)
	var second_light := second_level.get_node("TestLight") as Light3D
	cycle.time_of_day = 0.0
	cycle.call("_apply_cycle")
	if is_equal_approx(second_light.light_energy, 2.0):
		_fail("Day/night cycle did not apply to rebound level")
		return
	if not is_equal_approx(first_light.light_energy, first_energy_after_cycle):
		_fail("Day/night cycle unexpectedly rewrote old level after rebinding")
		return

	second_light.queue_free()
	await get_tree().process_frame
	cycle.call("_apply_cycle")
	if not cycle.light_defaults.is_empty():
		_fail("Day/night cycle kept a freed dynamic light")
		return

	print("[smoke] Day/night cycle OK")
	get_tree().quit()


func _create_test_level(level_name: String, light_energy: float) -> Node3D:
	var level := Node3D.new()
	level.name = level_name

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.08, 0.09, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.42, 0.45, 1.0)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	level.add_child(world_environment)

	var light := OmniLight3D.new()
	light.name = "TestLight"
	light.light_energy = light_energy
	light.light_color = Color(1.0, 0.92, 0.75, 1.0)
	level.add_child(light)
	return level


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
