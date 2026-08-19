extends Node3D

@onready var camera: Camera3D = $Camera3D
var frames := 0


func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	var mara := $Level/DialogueNpcs/Mara as Node3D
	camera.position = mara.global_position + Vector3(0.0, 1.35, 2.8)
	camera.look_at(mara.global_position + Vector3(0.0, 1.0, 0.0))


func _process(_delta: float) -> void:
	frames += 1
	if frames == 12:
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("res://build/mara_visual_capture.png"))
		get_tree().quit()
