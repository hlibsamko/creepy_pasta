extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var mimic: MimicDoor = $House/EndlessHouseBuilder/GeneratedBackrooms/Monsters/GeneratedMimicDoor1
@onready var level_exit: LevelExit = $House/EndlessHouseBuilder/GeneratedBackrooms/Markers/LevelExit

var frame_index := 0
var warmup_frames := 0


func _ready() -> void:
	_set_spawn_view()


func _process(_delta: float) -> void:
	warmup_frames += 1
	if warmup_frames < 20:
		return
	frame_index += 1
	if frame_index > 90:
		push_warning("Capture timed out before the requested frame; exiting cleanly.")
		get_tree().quit()
		return
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
		_set_sideboard_view()
	elif frame_index == 45:
		_capture_frame("res://build/endless_house_dressing_capture.png")
	elif frame_index == 55:
		_set_sideboard_alternate_view()
	elif frame_index == 70:
		_capture_frame("res://build/endless_house_dressing_alt_capture.png")
		get_tree().quit()


func _capture_frame(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("Capture skipped in headless mode: no rendered viewport is available: " + path)
		return
	var texture := get_viewport().get_texture()
	if texture == null:
		push_warning("Capture skipped: viewport texture is unavailable in this renderer: " + path)
		return
	var image := texture.get_image()
	if image == null:
		push_warning("Capture skipped: viewport image is unavailable in this renderer: " + path)
		return
	var sample_points := [Vector2i(image.get_width() / 2, image.get_height() / 2), Vector2i(image.get_width() / 4, image.get_height() / 2), Vector2i(image.get_width() * 3 / 4, image.get_height() / 2)]
	var luminance_sum := 0.0
	for sample_point in sample_points:
		luminance_sum += image.get_pixelv(sample_point).get_luminance()
	if luminance_sum < 0.03:
		push_warning("Capture skipped: viewport sample is effectively black: " + path)
		return
	image.save_png(ProjectSettings.globalize_path(path))


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


func _set_sideboard_view() -> void:
	# The production B cell is at grid x=4, z=7; keep the camera at eye level
	# and look down the corridor so the visual child is checked in context.
	camera.position = Vector3(16.0, 1.55, 32.0)
	camera.rotation = Vector3.ZERO


func _set_sideboard_alternate_view() -> void:
	# A second eye-level angle checks depth, overlap, and silhouette readability
	# without changing the generated route or gameplay kit.
	camera.position = Vector3(17.5, 1.55, 31.2)
	camera.rotation = Vector3(0.0, -0.12, 0.0)
