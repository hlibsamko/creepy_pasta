extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var player: CharacterBody3D = $Player
@onready var flashlight: SpotLight3D = $Player/Head/Flashlight
@onready var monster: Node = $LightShyMonster

var frame_index := 0


func _ready() -> void:
	$Player/Head/Camera3D.current = false
	player.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	camera.look_at(Vector3(0.0, 1.05, 0.0))
	player.set("controls_enabled", true)


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index == 10:
		print("[capture] The Unlit illuminated=%s" % monster.call("is_illuminated"))
	if frame_index == 14:
		flashlight.rotation.y = PI * 0.5
	if frame_index == 20:
		print("[capture] The Unlit after turn illuminated=%s" % monster.call("is_illuminated"))
