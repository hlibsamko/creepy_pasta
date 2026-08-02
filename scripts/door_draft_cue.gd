extends Node3D

@export_range(0.5, 4.0, 0.1) var cycle_seconds := 1.8
@export_range(0.01, 0.4, 0.01) var lateral_sway := 0.12
@export_range(0.01, 0.5, 0.01) var depth_sway := 0.16

var elapsed := 0.0
var streams: Array[Node3D] = []
var rest_positions: Array[Vector3] = []


func _ready() -> void:
	for child in get_children():
		if child is Node3D:
			streams.append(child)
			rest_positions.append((child as Node3D).position)
	set_process(visible)


func set_active(active: bool) -> void:
	visible = active
	set_process(active)


func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, maxf(cycle_seconds, 0.5))
	var cycle := elapsed * TAU / maxf(cycle_seconds, 0.5)
	for index in streams.size():
		var phase := cycle + float(index) * 2.05
		var stream := streams[index]
		var rest_position := rest_positions[index]
		stream.position = rest_position + Vector3(
			sin(phase) * lateral_sway,
			sin(phase * 1.7) * 0.018,
			(0.5 + 0.5 * sin(phase - 0.65)) * depth_sway
		)
		stream.rotation.y = sin(phase + 0.4) * 0.14
