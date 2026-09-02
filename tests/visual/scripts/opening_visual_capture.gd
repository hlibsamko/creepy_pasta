extends Node3D

@onready var camera: Camera3D = $Camera3D

var frame_index := 0


func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	_set_route_view()


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index == 10:
		_set_entry_view()


func _set_route_view() -> void:
	camera.position = Vector3(-0.8, 1.55, -4.15)
	camera.rotation = Vector3(0.0, PI, 0.0)


func _set_entry_view() -> void:
	var listener := $Level/Monsters/OpeningListener as CorridorMonster
	listener.set_note_progress(1, 2)
	listener.set_physics_process(false)
	camera.position = Vector3(-0.8, 1.55, -3.75)
	camera.look_at(listener.global_position + Vector3(0.0, 0.55, 0.0))
