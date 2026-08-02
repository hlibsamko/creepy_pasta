extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var mimic: MimicDoor = $House/EndlessHouseBuilder/GeneratedBackrooms/Monsters/GeneratedMimicDoor1
@onready var level_exit: LevelExit = $House/EndlessHouseBuilder/GeneratedBackrooms/Markers/LevelExit

var frame_index := 0


func _ready() -> void:
	_set_spawn_view()


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index == 12:
		_set_false_door_view()
		mimic.set_knowledge_profile(0.4, 1.0 / 3.0)
		mimic.pulse_elapsed = mimic.pulse_cycle_seconds * 0.3
		mimic.call("_apply_double_pulse")
	elif frame_index == 18:
		mimic.pulse_elapsed = mimic.pulse_cycle_seconds * 0.02
		mimic.call("_apply_double_pulse")
	elif frame_index == 24:
		level_exit.open()
		_set_real_exit_view()
	elif frame_index == 30:
		_set_ceiling_view()


func _set_spawn_view() -> void:
	camera.position = Vector3(4.0, 1.55, 4.0)
	camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)


func _set_false_door_view() -> void:
	camera.position = Vector3(30.0, 1.55, 20.0)
	camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)


func _set_real_exit_view() -> void:
	camera.position = Vector3(40.0, 1.55, 10.0)
	camera.rotation = Vector3.ZERO


func _set_ceiling_view() -> void:
	camera.position = Vector3(4.0, 1.55, 4.0)
	camera.rotation = Vector3(0.65, -PI * 0.5, 0.0)
