extends Node3D

@onready var camera: Camera3D = $Camera3D
var frames := 0

func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	camera.position = Vector3(0.0, 1.35, 4.2)
	camera.look_at(Vector3(0.0, 1.0, 0.0))

func _process(_delta: float) -> void:
	frames += 1
	if frames == 12:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/watcher_visual_capture.png"))
		get_tree().quit()
