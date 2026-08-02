extends Node

const UNLIT_EVIDENCE_DEMO := preload("res://scenes/endless_house/unlit_evidence_demo.tscn")

class ControlledPlayer:
	extends CharacterBody3D

	func has_control() -> bool:
		return true


var breaker_evidence_count := 0
var breaker_request_count := 0
var record_puzzle_request_count := 0


func _ready() -> void:
	var demo := UNLIT_EVIDENCE_DEMO.instantiate()
	add_child(demo)
	await get_tree().process_frame
	await get_tree().physics_frame

	var builder := demo.get_node_or_null("EndlessHouseBuilder") as BackroomsBuilder
	if not builder:
		_fail("The Unlit evidence demo has no reusable builder")
		return

	var notes := builder.find_children("GeneratedNote*", "Area3D", true, false)
	var plates := builder.find_children("PressurePlate*", "Area3D", true, false)
	var monsters := builder.find_children("GeneratedLightShyMonster*", "CharacterBody3D", true, false)
	var work_lights := builder.find_children("GeneratedWorkLight*", "SpotLight3D", true, false)
	var breaker_triggers := builder.find_children("GeneratedBreakerTrigger*", "Area3D", true, false)
	if notes.size() != 1 or plates.size() != 1 or monsters.size() != 1:
		_fail("The Unlit evidence demo must contain one record, hold switch, and creature")
		return
	if work_lights.size() != 1 or breaker_triggers.size() != 1:
		_fail("The Unlit evidence demo must contain one generated work light and breaker")
		return
	if builder.find_children("SpawnMarker*", "Marker3D", true, false).size() != 1:
		_fail("The Unlit evidence demo must contain exactly one spawn")
		return
	if builder.find_children("LevelExit*", "Area3D", true, false).size() != 1:
		_fail("The Unlit evidence demo must contain exactly one exit")
		return

	var record: Node = notes[0]
	if (
		not bool(record.get("requires_puzzle"))
		or int(record.get("puzzle_type")) != 0
		or not str(record.get("note_text")).contains("chalk mark")
		or not str(record.get("note_text")).contains("work lamp")
		or str(record.get("journal_entry_id")) != "unlit"
		or int(record.get("journal_fact_index")) != 1
	):
		_fail("The Unlit record no longer teaches its light rule through Match Dots")
		return

	var plate: Node = plates[0]
	var monster: Node = monsters[0]
	var work_light: Node = work_lights[0]
	var breaker_trigger: Node = breaker_triggers[0]
	if (
		not plate
		or bool(plate.get("latch_once"))
		or int(plate.get("required_players")) != 1
	):
		_fail("The Unlit chamber must use a one-player non-latching hold switch")
		return
	if not work_light or work_light.get("power_source") != plate:
		_fail("The Unlit chamber work light did not resolve its generated pressure plate")
		return
	if not breaker_trigger or breaker_trigger.get("powered_light") != work_light:
		_fail("The Unlit chamber breaker did not resolve its powered work light")
		return
	if (
		not breaker_trigger.has_signal("evidence_observed")
		or str(breaker_trigger.get("journal_entry_id")) != "unlit"
		or int(breaker_trigger.get("journal_fact_index_on_observation")) != 3
	):
		_fail("The breaker outage no longer provides optional Unlit survival evidence")
		return
	breaker_trigger.evidence_observed.connect(_on_breaker_evidence_observed)
	breaker_trigger.outage_requested.connect(_on_breaker_outage_requested)
	if (
		str(monster.get("journal_entry_id")) != "unlit"
		or int(monster.get("journal_fact_index_on_observation")) != 2
	):
		_fail("The Unlit direct observation no longer maps to its optional journal fact")
		return
	if bool(work_light.call("is_powered")) or bool(monster.call("is_illuminated")):
		_fail("The Unlit chamber must begin with its work light off")
		return

	var breaker_local_position := builder.to_local((breaker_trigger as Node3D).global_position)
	var outage_cell := Vector2i(
		roundi(breaker_local_position.x / builder.cell_size),
		roundi(breaker_local_position.z / builder.cell_size)
	)
	var route_steps := _get_route_steps(builder.layout, outage_cell)
	if route_steps.is_empty():
		return
	if not (
		route_steps["record"] < route_steps["hold"]
		and route_steps["hold"] < route_steps["creature"]
		and route_steps["creature"] < route_steps["outage"]
		and route_steps["outage"] < route_steps["exit"]
	):
		_fail("The Unlit chamber no longer teaches record, power, crossing, outage, and exit in order")
		return

	record.connect("puzzle_requested", _on_record_puzzle_requested)
	var holder := _create_player_probe(
		demo,
		Vector3((record as Node3D).global_position.x, 0.05, (record as Node3D).global_position.z)
	)
	await _wait_physics_frames(4)
	if record_puzzle_request_count != 1:
		_fail("A controlled player body did not request the chamber record puzzle")
		return

	holder.global_position = Vector3(
		(plate as Node3D).global_position.x,
		0.05,
		(plate as Node3D).global_position.z
	)
	await _wait_physics_frames(6)
	if not bool(plate.call("is_active")):
		_fail("A controlled player body did not hold the non-latching floor switch")
		return
	if not bool(work_light.call("is_powered")) or not bool(monster.call("is_illuminated")):
		var light_position := (work_light as Node3D).global_position
		var creature_position := (monster as Node3D).global_position
		var light_query := PhysicsRayQueryParameters3D.create(
			light_position,
			creature_position + Vector3.UP * 0.55
		)
		light_query.collide_with_areas = false
		var light_hit := (monster as Node3D).get_world_3d().direct_space_state.intersect_ray(light_query)
		var collider_name := "<clear>"
		if not light_hit.is_empty():
			var collider := light_hit.get("collider") as Node
			collider_name = collider.name if collider else str(light_hit.get("collider"))
		_fail(
			(
				"The powered work light did not hold The Unlit "
				+ "(powered=%s, energy=%.2f, illuminated=%s, light=%s, forward=%s, "
				+ "creature=%s, ray_hit=%s, range=%.2f, cone=%s, group_count=%d)"
			)
			% [
				bool(work_light.call("is_powered")),
				float(work_light.get("light_energy")),
				bool(monster.call("is_illuminated")),
				str(light_position),
				str(-(work_light as Node3D).global_basis.z.normalized()),
				str(creature_position),
				collider_name,
				float(work_light.get("spot_range")),
				bool(monster.call("_is_inside_spotlight", work_light)),
				get_tree().get_nodes_in_group("unlit_stopping_lights").size(),
			]
		)
		return

	breaker_trigger.set("outage_duration", 0.45)
	var runner := _create_player_probe(
		demo,
		Vector3(
			(breaker_trigger as Node3D).global_position.x,
			0.05,
			(breaker_trigger as Node3D).global_position.z
		)
	)
	await _wait_physics_frames(4)
	if not bool(breaker_trigger.call("is_triggered")):
		_fail("A controlled player body did not start the in-world breaker outage")
		return
	if breaker_evidence_count != 1:
		_fail("The first breaker outage did not emit exactly one survival observation")
		return
	await get_tree().create_timer(float(monster.get("illumination_hold_seconds")) + 0.08).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	if (
		not bool(plate.call("is_active"))
		or bool(work_light.call("is_powered"))
		or bool(monster.call("is_illuminated"))
		or not bool(work_light.call("is_in_outage"))
	):
		_fail("The breaker outage did not release The Unlit while the hold switch stayed active")
		return

	var outage_state: Dictionary = work_light.call("get_outage_state")
	var trigger_state: Dictionary = breaker_trigger.call("get_trigger_state")
	if float(outage_state.get("outage_remaining", 0.0)) <= 0.0:
		_fail("The work light did not expose a restorable active outage")
		return
	work_light.call("clear_outage")
	breaker_trigger.call("reset_trigger")
	await get_tree().process_frame
	if not bool(work_light.call("is_powered")) or bool(breaker_trigger.call("is_triggered")):
		_fail("Resetting breaker state did not restore its ready powered state")
		return
	breaker_trigger.call("apply_trigger_state", trigger_state)
	work_light.call("apply_outage_state", outage_state)
	await get_tree().process_frame
	if (
		bool(work_light.call("is_powered"))
		or not bool(work_light.call("is_in_outage"))
		or not bool(breaker_trigger.call("is_triggered"))
		or bool(breaker_trigger.call("trigger_outage"))
		or breaker_evidence_count != 1
	):
		_fail("Synchronized breaker snapshots did not restore the spent one-shot outage")
		return

	await get_tree().create_timer(float(outage_state["outage_remaining"]) + 0.08).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	if (
		bool(work_light.call("is_in_outage"))
		or not bool(work_light.call("is_powered"))
		or not bool(monster.call("is_illuminated"))
	):
		_fail("The work light did not resume holding The Unlit after the restored outage elapsed")
		return

	holder.global_position = Vector3(4.0, 0.05, 4.0)
	await get_tree().create_timer(float(monster.get("illumination_hold_seconds")) + 0.08).timeout
	await _wait_physics_frames(3)
	if (
		bool(plate.call("is_active"))
		or bool(work_light.call("is_powered"))
		or bool(monster.call("is_illuminated"))
	):
		_fail("The Unlit stayed held after the non-latching switch was released")
		return
	breaker_trigger.call("reset_trigger")
	work_light.call("clear_outage")
	breaker_trigger.call("set_authoritative_mode", true)
	runner.global_position = Vector3(4.0, 0.05, 4.0)
	await _wait_physics_frames(3)
	runner.global_position = Vector3(
		(breaker_trigger as Node3D).global_position.x,
		0.05,
		(breaker_trigger as Node3D).global_position.z
	)
	await _wait_physics_frames(4)
	if (
		breaker_request_count != 1
		or bool(breaker_trigger.call("is_triggered"))
		or bool(work_light.call("is_in_outage"))
		or breaker_evidence_count != 1
	):
		_fail("Authoritative breaker mode mutated local state before server approval")
		return
	breaker_trigger.call("set_authoritative_mode", false)
	runner.queue_free()
	holder.queue_free()

	print("[smoke] The Unlit evidence chamber loop OK")
	get_tree().quit()


func _get_route_steps(layout: String, outage_position: Vector2i) -> Dictionary:
	var rows := PackedStringArray()
	for raw_row in layout.split("\n"):
		var row := raw_row.strip_edges()
		if not row.is_empty():
			rows.append(row)

	var targets := {}
	for z in rows.size():
		for x in rows[z].length():
			var marker := rows[z].substr(x, 1)
			if marker == "S":
				targets["spawn"] = Vector2i(x, z)
			elif marker == "D":
				targets["record_position"] = Vector2i(x, z)
			elif marker in ["H", "R"]:
				targets["hold_position"] = Vector2i(x, z)
			elif marker == "U":
				targets["creature_position"] = Vector2i(x, z)
			elif marker == "E":
				targets["exit_position"] = Vector2i(x, z)
	targets["outage_position"] = outage_position
	for required_key in [
		"spawn",
		"record_position",
		"hold_position",
		"creature_position",
		"outage_position",
		"exit_position",
	]:
		if not targets.has(required_key):
			_fail("The Unlit chamber layout is missing %s" % required_key)
			return {}

	var distances := _get_layout_distances(rows, targets["spawn"])
	var result := {}
	for target_name in ["record", "hold", "creature", "outage", "exit"]:
		var target: Vector2i = targets["%s_position" % target_name]
		if not distances.has(target):
			_fail("The Unlit chamber %s is unreachable from spawn" % target_name)
			return {}
		result[target_name] = int(distances[target])
	return result


func _get_layout_distances(rows: PackedStringArray, start: Vector2i) -> Dictionary:
	var distances := {start: 0}
	var queue: Array[Vector2i] = [start]
	var index := 0
	var directions: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]
	while index < queue.size():
		var position := queue[index]
		index += 1
		for direction in directions:
			var next_position := position + direction
			if distances.has(next_position):
				continue
			if next_position.y < 0 or next_position.y >= rows.size():
				continue
			if next_position.x < 0 or next_position.x >= rows[next_position.y].length():
				continue
			if rows[next_position.y].substr(next_position.x, 1) == "#":
				continue
			distances[next_position] = int(distances[position]) + 1
			queue.append(next_position)
	return distances


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)


func _on_breaker_evidence_observed() -> void:
	breaker_evidence_count += 1


func _on_breaker_outage_requested() -> void:
	breaker_request_count += 1


func _on_record_puzzle_requested(_note_id: String, _note_text: String, puzzle_type: int) -> void:
	if puzzle_type == 0:
		record_puzzle_request_count += 1


func _create_player_probe(parent: Node, world_position: Vector3) -> ControlledPlayer:
	var player := ControlledPlayer.new()
	player.name = "ControlledPlayerProbe"
	player.position = world_position
	player.add_to_group("players")
	var collision := CollisionShape3D.new()
	collision.position = Vector3.UP * 0.9
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	collision.shape = shape
	player.add_child(collision)
	parent.add_child(player)
	return player


func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame
