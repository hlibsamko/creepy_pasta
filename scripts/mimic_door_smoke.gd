extends Node

const MIMIC_SCENE := preload("res://scenes/common/mimic_door_basic.tscn")

class ControlledProbe extends CharacterBody3D:
	var controlled := true

	func _ready() -> void:
		add_to_group("players")

	func has_control() -> bool:
		return controlled


var observed_count := 0
var killed_count := 0


func _ready() -> void:
	var mimic := MIMIC_SCENE.instantiate()
	add_child(mimic)
	mimic.observed.connect(func() -> void: observed_count += 1)
	mimic.killed_player.connect(func(_reason: String) -> void: killed_count += 1)

	var probe := ControlledProbe.new()
	probe.position = Vector3(0.0, 0.0, 2.0)
	add_child(probe)
	mimic.call("_process", 0.0)
	if observed_count != 1:
		_fail("False Door did not report a nearby controlled observer")
		return

	mimic.pulse_elapsed = 0.3
	mimic.call("_apply_double_pulse")
	var low_intensity := float(mimic.get_tell_intensity())
	mimic.pulse_elapsed = 0.48
	mimic.call("_apply_double_pulse")
	var pulse_intensity := float(mimic.get_tell_intensity())
	if pulse_intensity <= low_intensity:
		_fail("False Door tell did not produce a readable double pulse")
		return
	if mimic.get_knowledge_behavior_tier() != 0:
		_fail("False Door did not begin with its baseline tell")
		return

	mimic.set_knowledge_profile(0.4, 1.0 / 3.0)
	mimic.pulse_elapsed = mimic.pulse_cycle_seconds * 0.3
	mimic.call("_apply_double_pulse")
	var disguised_color: Color = mimic.get_tell_color()
	mimic.pulse_elapsed = mimic.pulse_cycle_seconds * 0.02
	mimic.call("_apply_double_pulse")
	var revealed_color: Color = mimic.get_tell_color()
	if disguised_color.is_equal_approx(revealed_color):
		_fail("Learned False Door did not alternate disguise and identifying colors")
		return

	mimic.set_knowledge_profile(0.7, 2.0 / 3.0)
	probe.position = Vector3(0.0, 0.0, 8.0)
	mimic.pulse_elapsed = mimic.pulse_cycle_seconds * 0.02
	mimic.call("_apply_double_pulse")
	var far_intensity := float(mimic.get_tell_intensity())
	var far_color: Color = mimic.get_tell_color()
	probe.position = Vector3(0.0, 0.0, 2.0)
	mimic.call("_apply_double_pulse")
	if mimic.get_tell_intensity() <= far_intensity or mimic.get_tell_color().is_equal_approx(far_color):
		_fail("Advanced False Door did not reveal its known tell at a safe observation range")
		return
	if mimic.learned_reveal_distance <= mimic.observation_distance:
		_fail("False Door tell only appeared inside its observation safety margin")
		return

	probe.controlled = false
	mimic.call("_on_body_entered", probe)
	if killed_count != 0:
		_fail("False Door affected a non-controlled multiplayer body")
		return
	probe.controlled = true
	mimic.call("_on_body_entered", probe)
	if killed_count != 1 or bool(mimic.active):
		_fail("False Door did not consume one locally controlled entrant")
		return

	print("[smoke] False Door observation and trap behavior OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
