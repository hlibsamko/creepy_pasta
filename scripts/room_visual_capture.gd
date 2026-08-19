extends Node3D

const LAST_CAPTURE_FRAME := 900
const RETRY_INTERVAL_FRAMES := 15

@export var output_path := "res://build/room_visual_capture.png"
@export var camera_position := Vector3(0.0, 1.55, 3.65)
@export var camera_target := Vector3(0.0, 1.2, -3.0)
@export_range(1, 240, 1) var first_capture_frame := 60
@export_range(1, 1000, 1) var minimum_lit_samples := 40

@onready var camera: Camera3D = $Camera3D

var frame_index := 0


func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	camera.position = camera_position
	camera.look_at(camera_target)


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index < first_capture_frame or frame_index % RETRY_INTERVAL_FRAMES != 0:
		return
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		_finish_if_capture_timed_out()
		return
	var image := viewport_texture.get_image()
	if image == null or not _frame_has_content(image):
		_finish_if_capture_timed_out()
		return
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Could not save room visual capture: %s" % error_string(error))
		get_tree().quit(1)
		return
	get_tree().quit()


func _frame_has_content(image: Image) -> bool:
	if image.get_width() < 640 or image.get_height() < 360:
		return false
	var lit_samples := 0
	for y in range(24, image.get_height(), 32):
		for x in range(24, image.get_width(), 32):
			var color := image.get_pixel(x, y)
			if color.r + color.g + color.b > 0.06:
				lit_samples += 1
	return lit_samples > minimum_lit_samples


func _finish_if_capture_timed_out() -> void:
	if frame_index < LAST_CAPTURE_FRAME:
		return
	push_error("Room capture never received a complete rendered frame")
	get_tree().quit(1)
