extends Node3D

@onready var camera: Camera3D = $Camera3D

var frame_index := 0


func _ready() -> void:
	_set_survey_view()


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index == 12:
		_set_recorder_view()


func _set_survey_view() -> void:
	camera.position = Vector3(-3.9, 1.4, 4.35)
	camera.look_at(Vector3(-5.6, 0.25, 3.8))


func _set_recorder_view() -> void:
	camera.position = Vector3(1.7, 1.4, 4.15)
	camera.look_at(Vector3(0.0, 0.25, 3.4))
