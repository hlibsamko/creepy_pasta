extends Node3D

@export_enum("Dreamcore", "Poolrooms", "Empty Mall", "Endless Hotel") var branch_type := 0

@onready var camera: Camera3D = $Camera3D

var frame_index := 0


func _ready() -> void:
	_apply_view(0)


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index == 10:
		_apply_view(1)
	elif frame_index == 20:
		_apply_view(2)


func _apply_view(view_index: int) -> void:
	if branch_type == 0:
		_apply_dreamcore_view(view_index)
	elif branch_type == 1:
		_apply_poolrooms_view(view_index)
	elif branch_type == 2:
		_apply_empty_mall_view(view_index)
	else:
		_apply_endless_hotel_view(view_index)


func _apply_dreamcore_view(view_index: int) -> void:
	match view_index:
		0:
			camera.position = Vector3(4.0, 1.55, 4.0)
			camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		1:
			camera.position = Vector3(15.0, 1.55, 17.0)
			camera.rotation = Vector3(0.0, -0.72, 0.0)
		_:
			camera.position = Vector3(28.0, 1.55, 22.0)
			camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)


func _apply_poolrooms_view(view_index: int) -> void:
	match view_index:
		0:
			camera.position = Vector3(4.0, 1.55, 4.0)
			camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)


func _apply_empty_mall_view(view_index: int) -> void:
	match view_index:
		0:
			camera.position = Vector3(4.0, 1.55, 4.0)
			camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)


func _apply_endless_hotel_view(view_index: int) -> void:
	match view_index:
		0:
			camera.position = Vector3(4.0, 1.55, 4.0)
			camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		1:
			camera.position = Vector3(4.0, 1.55, 12.0)
			camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		_:
			camera.position = Vector3(8.0, 1.55, 24.0)
			camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		1:
			camera.position = Vector3(8.0, 1.55, 8.0)
			camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		_:
			camera.position = Vector3(8.0, 1.55, 24.0)
			camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		1:
			camera.position = Vector3(16.0, 1.35, 14.0)
			camera.rotation = Vector3(-0.08, -0.9, 0.0)
		_:
			camera.position = Vector3(34.0, 1.55, 22.0)
			camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)
