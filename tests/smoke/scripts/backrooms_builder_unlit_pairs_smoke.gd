extends Node


func _ready() -> void:
	var builder := BackroomsBuilder.new()
	builder.layout = "##################\n#R..U..T#T..U..R.#\n##################"
	builder.work_light_range = 16.0
	add_child(builder)
	await get_tree().process_frame
	await get_tree().physics_frame

	var plates: Array[Node] = []
	for area in builder.find_children("*", "Area3D", true, false):
		if area.has_method("set_synced_active") and area.has_method("is_active"):
			plates.append(area)
	var work_lights := builder.find_children("GeneratedWorkLight*", "SpotLight3D", true, false)
	var triggers := builder.find_children("GeneratedBreakerTrigger*", "Area3D", true, false)
	var monsters := builder.find_children(
		"GeneratedLightShyMonster*",
		"CharacterBody3D",
		true,
		false
	)
	if (
		plates.size() != 2
		or work_lights.size() != 2
		or triggers.size() != 2
		or monsters.size() != 2
	):
		_fail("Two R/U/T encounter clusters did not generate matching gameplay pairs")
		return

	plates.sort_custom(_sort_nodes_by_x)
	work_lights.sort_custom(_sort_nodes_by_x)
	triggers.sort_custom(_sort_nodes_by_x)
	monsters.sort_custom(_sort_nodes_by_x)

	var left_plate: Node = plates[0]
	var right_plate: Node = plates[1]
	var left_light: Node3D = work_lights[0]
	var right_light: Node3D = work_lights[1]
	var left_trigger: Node = triggers[0]
	var right_trigger: Node = triggers[1]
	var left_monster: Node3D = monsters[0]
	var right_monster: Node3D = monsters[1]

	if left_light.get("power_source") != left_plate or right_light.get("power_source") != right_plate:
		_fail("Generated work lights crossed their local R pressure-plate bindings")
		return
	if (
		left_trigger.get("powered_light") != left_light
		or right_trigger.get("powered_light") != right_light
	):
		_fail("Generated breaker triggers crossed their nearest work-light bindings")
		return
	if (
		not _is_aimed_at(left_light, left_monster)
		or not _is_aimed_at(right_light, right_monster)
	):
		_fail("Generated work lights crossed their nearest The Unlit targets")
		return

	left_plate.call("set_synced_active", true)
	right_plate.call("set_synced_active", true)
	await _wait_physics_frames(4)
	if (
		not bool(left_light.call("is_powered"))
		or not bool(right_light.call("is_powered"))
		or not bool(left_monster.call("is_illuminated"))
		or not bool(right_monster.call("is_illuminated"))
	):
		_fail("Both generated R stations did not independently hold their local creature")
		return

	left_trigger.set("outage_duration", 0.45)
	if not bool(left_trigger.call("trigger_outage")):
		_fail("Left generated breaker refused its first outage")
		return
	await get_tree().create_timer(
		float(left_monster.get("illumination_hold_seconds")) + 0.08
	).timeout
	await _wait_physics_frames(2)
	if (
		bool(left_light.call("is_powered"))
		or bool(left_monster.call("is_illuminated"))
		or not bool(right_light.call("is_powered"))
		or not bool(right_monster.call("is_illuminated"))
		or bool(right_trigger.call("is_triggered"))
	):
		_fail("Left generated outage leaked into the right R/U/T encounter")
		return

	await get_tree().create_timer(0.35).timeout
	await _wait_physics_frames(2)
	if (
		not bool(left_light.call("is_powered"))
		or not bool(left_monster.call("is_illuminated"))
		or not bool(right_light.call("is_powered"))
	):
		_fail("Left generated work light did not recover without disturbing the right pair")
		return

	right_trigger.set("outage_duration", 0.45)
	if not bool(right_trigger.call("trigger_outage")):
		_fail("Right generated breaker refused its independent outage")
		return
	await get_tree().create_timer(
		float(right_monster.get("illumination_hold_seconds")) + 0.08
	).timeout
	await _wait_physics_frames(2)
	if (
		not bool(left_light.call("is_powered"))
		or not bool(left_monster.call("is_illuminated"))
		or bool(right_light.call("is_powered"))
		or bool(right_monster.call("is_illuminated"))
		or not bool(left_trigger.call("is_triggered"))
	):
		_fail("Right generated outage leaked into the recovered left R/U/T encounter")
		return

	print("[smoke] Multiple generated R/U/T encounters stay independent")
	get_tree().quit()


func _is_aimed_at(light: Node3D, target: Node3D) -> bool:
	var light_forward := -light.global_basis.z.normalized()
	var target_direction := (
		target.global_position + Vector3.UP * 0.55 - light.global_position
	).normalized()
	return light_forward.dot(target_direction) >= 0.995


func _sort_nodes_by_x(a: Node, b: Node) -> bool:
	return (a as Node3D).global_position.x < (b as Node3D).global_position.x


func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
