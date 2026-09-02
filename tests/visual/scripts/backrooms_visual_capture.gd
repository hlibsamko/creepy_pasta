extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var level_exit: LevelExit = $Backrooms/BackroomsBuilder/GeneratedBackrooms/Markers/LevelExit

var frame_index := 0
var capture_saved := false


func _ready() -> void:
	_set_spawn_view()
	await get_tree().create_timer(1.0).timeout
	level_exit.open()
	_set_exit_view()
	for _frame in 6:
		await RenderingServer.frame_post_draw
	_save_exit_capture()


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index == 12:
		_set_watcher_view()
	elif frame_index == 24:
		level_exit.open()
		_set_exit_view()


func _save_exit_capture() -> void:
	if capture_saved:
		return
	var image := get_viewport().get_texture().get_image()
	var samples := [image.get_pixel(8, 8).r, image.get_pixel(image.get_width() / 2, image.get_height() / 2).r, image.get_pixel(image.get_width() - 8, image.get_height() - 8).r]
	if samples.max() < 0.03:
		push_warning("Backrooms eye-level capture skipped: viewport is effectively black")
		get_tree().quit()
		return
	capture_saved = true
	var error := image.save_png("res://build/backrooms_exit_eye_level.png")
	if error != OK:
		push_error("Backrooms eye-level capture failed: %s" % error)
	else:
		print("[capture] Backrooms LevelExit eye-level saved")
	get_tree().quit()


func _set_spawn_view() -> void:
	camera.position = Vector3(4.0, 1.55, 4.0)
	camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)


func _set_watcher_view() -> void:
	camera.position = Vector3(8.0, 1.55, 28.0)
	camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)


func _set_exit_view() -> void:
	camera.position = Vector3(28.0, 1.55, 28.0)
	camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)
