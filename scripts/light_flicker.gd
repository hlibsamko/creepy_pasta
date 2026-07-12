extends Light3D

@export var enabled := true
@export_range(0.0, 1.0, 0.01) var intensity := 0.18
@export_range(0.1, 12.0, 0.1) var speed := 4.0
@export_range(0.0, 1.0, 0.01) var pulse_chance := 0.04
@export_range(0.04, 0.8, 0.01) var pulse_duration := 0.12

var base_energy := 1.0
var phase := 0.0
var pulse_time := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	base_energy = light_energy
	rng.randomize()
	phase = rng.randf_range(0.0, TAU)


func _process(delta: float) -> void:
	if not enabled:
		light_energy = base_energy
		return

	phase += delta * speed
	var wave: float = sin(phase) * 0.55 + sin(phase * 2.37) * 0.3 + sin(phase * 5.11) * 0.15
	var flicker := 1.0 + wave * intensity

	if pulse_time > 0.0:
		pulse_time = max(pulse_time - delta, 0.0)
		flicker *= lerp(0.55, 1.0, pulse_time / pulse_duration)
	elif rng.randf() < pulse_chance * delta:
		pulse_time = pulse_duration

	light_energy = max(base_energy * flicker, 0.0)
