extends Node

@onready var ui: GameUi = $GameUi

var frame_index := 0

const FIRST_CAPTURE_FRAME := 60
const LAST_CAPTURE_FRAME := 900
const RETRY_INTERVAL_FRAMES := 15


func _ready() -> void:
	ui.show_menu()
	ui.set_status("The house remembers every connection. Choose how you enter.")


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index < FIRST_CAPTURE_FRAME or frame_index % RETRY_INTERVAL_FRAMES != 0:
		return
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		_finish_if_capture_timed_out()
		return
	var image := viewport_texture.get_image()
	if image == null or not _menu_render_is_ready(image):
		_finish_if_capture_timed_out()
		return
	var error := image.save_png(ProjectSettings.globalize_path("res://build/menu_visual_capture.png"))
	if error != OK:
		push_error("Could not save menu visual capture: %s" % error_string(error))
		get_tree().quit(1)
		return
	get_tree().quit()


func _menu_render_is_ready(image: Image) -> bool:
	if image.get_width() < 492 or image.get_height() < 342:
		return false
	var panel_samples := 0
	for y in range(40, 330, 24):
		for x in range(40, 480, 24):
			var color := image.get_pixel(x, y)
			if color.r + color.g + color.b > 0.11:
				panel_samples += 1
	return panel_samples > 100


func _finish_if_capture_timed_out() -> void:
	if frame_index < LAST_CAPTURE_FRAME:
		return
	push_error("Menu visual capture never received a complete rendered frame")
	get_tree().quit(1)
