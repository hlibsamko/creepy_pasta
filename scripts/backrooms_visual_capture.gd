extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var level_exit: LevelExit = $Backrooms/BackroomsBuilder/GeneratedBackrooms/Markers/LevelExit

var frame_index := 0


func _ready() -> void:
	_set_spawn_view()


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index == 12:
		_set_watcher_view()
	elif frame_index == 24:
		level_exit.open()
		_set_exit_view()


func _set_spawn_view() -> void:
	camera.position = Vector3(4.0, 1.55, 4.0)
	camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)


func _set_watcher_view() -> void:
	camera.position = Vector3(8.0, 1.55, 28.0)
	camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)


func _set_exit_view() -> void:
	camera.position = Vector3(28.0, 1.55, 28.0)
	camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)
