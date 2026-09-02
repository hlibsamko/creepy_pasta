extends Node3D

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	for _frame in 12:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://build/monster_model_gallery.png")
	if error != OK:
		push_error("Monster model gallery capture failed: %s" % error)
	else:
		print("[capture] Monster model gallery saved")
	get_tree().quit()
