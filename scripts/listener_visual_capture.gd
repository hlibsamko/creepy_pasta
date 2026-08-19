extends Node3D

@onready var camera: Camera3D = $Camera3D
var frames := 0

func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	$Listener.set_note_progress(1, 2)
	camera.position = Vector3(0.0, 1.35, 3.8)
	camera.look_at(Vector3(0.0, 1.0, 0.0))

func _process(_delta: float) -> void:
	frames += 1
	if frames == 12:
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("res://build/listener_visual_capture.png"))
		get_tree().quit()
