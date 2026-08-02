extends Node3D

const MONSTER_SCENE := preload("res://scenes/common/light_shy_monster_basic.tscn")
const MONSTER_SCRIPT := preload("res://scripts/light_shy_monster.gd")
const PRESSURE_PLATE_SCENE := preload("res://scenes/common/pressure_plate_basic.tscn")
const POWERED_LIGHT_SCENE := preload("res://scenes/common/pressure_powered_spotlight_basic.tscn")

class ControlledPlayer:
	extends CharacterBody3D

	func has_control() -> bool:
		return true


var observed_count := 0
var killed_count := 0


func _ready() -> void:
	var player := _create_player()
	add_child(player)
	var monster := MONSTER_SCENE.instantiate() as MONSTER_SCRIPT
	add_child(monster)
	monster.observed.connect(func() -> void: observed_count += 1)
	monster.killed_player.connect(func(_reason: String) -> void: killed_count += 1)
	await _wait_physics_frames(4)

	var frozen_position: Vector3 = monster.global_position
	if not monster.is_illuminated() or observed_count != 1:
		_fail("The Unlit did not freeze and report its first flashlight observation")
		return
	await _wait_physics_frames(8)
	if monster.global_position.distance_to(frozen_position) > 0.01:
		_fail("The Unlit moved while held inside an unobstructed flashlight cone")
		return

	player.rotation.y = PI * 0.5
	await _wait_physics_frames(16)
	if monster.is_illuminated() or monster.global_position.z <= frozen_position.z + 0.12:
		_fail("The Unlit did not advance after the flashlight turned away")
		return

	var blocker := _create_blocker()
	add_child(blocker)
	player.rotation.y = 0.0
	await _wait_physics_frames(10)
	var blocked_position: Vector3 = monster.global_position
	if monster.is_illuminated():
		_fail("A solid wall did not block the flashlight hold")
		return
	await _wait_physics_frames(6)
	if monster.global_position.distance_to(blocked_position) <= 0.05:
		_fail("The Unlit stopped despite the flashlight being occluded")
		return

	blocker.queue_free()
	await get_tree().physics_frame
	await _wait_physics_frames(5)
	if not monster.is_illuminated():
		_fail("The Unlit did not freeze after the flashlight line of sight reopened")
		return

	player.rotation.y = PI * 0.5
	var work_switch := PRESSURE_PLATE_SCENE.instantiate() as Area3D
	work_switch.name = "WorkSwitch"
	work_switch.position = Vector3(-2.0, 0.03, 4.0)
	work_switch.set("latch_once", false)
	add_child(work_switch)
	var work_light := POWERED_LIGHT_SCENE.instantiate() as SpotLight3D
	work_light.position = Vector3(0.0, 1.45, 5.0)
	work_light.set("power_source_path", NodePath("../WorkSwitch"))
	add_child(work_light)
	await _wait_physics_frames(10)
	if monster.is_illuminated():
		_fail("Inactive pressure switch powered the work light")
		return
	work_switch.call("set_synced_active", true)
	await _wait_physics_frames(5)
	if not monster.is_illuminated() or not bool(work_light.call("is_powered")):
		_fail("Pressure-powered work light did not hold The Unlit")
		return
	work_switch.call("set_synced_active", false)
	await _wait_physics_frames(12)
	if monster.is_illuminated() or bool(work_light.call("is_powered")):
		_fail("Released pressure switch left the work light or The Unlit frozen")
		return

	player.rotation.y = 0.0
	await _wait_physics_frames(5)
	var second := MONSTER_SCENE.instantiate() as MONSTER_SCRIPT
	second.position = Vector3(4.0, 0.0, 0.0)
	add_child(second)
	await _wait_physics_frames(8)
	if not monster.is_illuminated() or second.is_illuminated():
		_fail("Two Unlit instances shared their independent illumination state")
		return
	var second_position: Vector3 = second.global_position
	await _wait_physics_frames(6)
	if second.global_position.distance_to(second_position) <= 0.05:
		_fail("The unlit second instance did not pursue outside the beam")
		return
	second.observed.connect(func() -> void: observed_count += 1)
	var first_authority_position := Vector3(1.0, 0.0, 1.0)
	var second_authority_position := Vector3(3.0, 0.0, 1.0)
	monster.apply_authoritative_state({
		"position": first_authority_position,
		"illuminated": false,
	})
	second.apply_authoritative_state({
		"position": second_authority_position,
		"illuminated": true,
	})
	await _wait_physics_frames(8)
	monster.call("_on_kill_zone_body_entered", player)
	if (
		not monster.is_authoritative_state_enabled()
		or not second.is_authoritative_state_enabled()
		or monster.global_position.distance_to(first_authority_position) > 0.001
		or second.global_position.distance_to(second_authority_position) > 0.001
		or monster.is_illuminated()
		or not second.is_illuminated()
		or observed_count != 1
		or killed_count != 0
	):
		_fail("Authoritative Unlit state did not override local movement, illumination, and contact silently")
		return
	monster.clear_authoritative_state()
	second.clear_authoritative_state()
	if monster.is_authoritative_state_enabled() or second.is_authoritative_state_enabled():
		_fail("The Unlit could not return from staged authority to local preview behavior")
		return
	monster.call("_on_kill_zone_body_entered", player)
	if killed_count != 1:
		_fail("The Unlit local preview lost its physical contact death")
		return

	print("[smoke] The Unlit flashlight cone, occlusion, and multi-instance state OK")
	get_tree().quit()


func _create_player() -> ControlledPlayer:
	var player := ControlledPlayer.new()
	player.position = Vector3(0.0, 0.0, 5.0)
	player.add_to_group("players")
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	body_shape.shape = capsule
	body_shape.position.y = 0.9
	player.add_child(body_shape)
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 1.45
	player.add_child(head)
	var flashlight := SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_energy = 5.0
	flashlight.spot_range = 12.0
	flashlight.spot_angle = 28.0
	head.add_child(flashlight)
	return player


func _create_blocker() -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.position = Vector3(0.0, 1.0, 2.5)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 2.0, 0.35)
	collision.shape = shape
	blocker.add_child(collision)
	return blocker


func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
