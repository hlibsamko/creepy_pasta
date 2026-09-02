extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var preview_flashlight: SpotLight3D = $Camera3D/PreviewFlashlight
@onready var demo: Node3D = $UnlitEvidenceDemo
@onready var plate: Node = demo.get_node(
	"EndlessHouseBuilder/GeneratedBackrooms/Mechanics/PressurePlate"
)
@onready var monster: Node3D = demo.get_node(
	"EndlessHouseBuilder/GeneratedBackrooms/Monsters/GeneratedLightShyMonster1"
)
@onready var breaker: Node3D = demo.get_node(
	"EndlessHouseBuilder/GeneratedBackrooms/Mechanics/GeneratedBreakerTrigger1"
)

var frame_index := 0


func _ready() -> void:
	_set_record_view()


func _process(_delta: float) -> void:
	frame_index += 1
	if frame_index == 8:
		plate.call("set_synced_active", true)
		_set_crossing_view()
	elif frame_index == 14:
		print("[capture] work light holds The Unlit=%s" % monster.call("is_illuminated"))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/unlit_visual_cyan.png"))
	elif frame_index == 18:
		breaker.call("trigger_outage")
	elif frame_index == 24:
		print("[capture] outage releases The Unlit=%s" % (not monster.call("is_illuminated")))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/unlit_visual_red.png"))
	elif frame_index == 27:
		_set_breaker_view()


func _set_record_view() -> void:
	camera.position = Vector3(4.0, 1.55, 4.0)
	camera.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	preview_flashlight.light_energy = 4.0


func _set_crossing_view() -> void:
	camera.position = Vector3(14.0, 1.55, 20.0)
	camera.look_at(Vector3(26.0, 1.0, 20.0))
	preview_flashlight.light_energy = 0.0


func _set_breaker_view() -> void:
	camera.position = Vector3(31.0, 1.55, 20.0)
	camera.look_at(breaker.global_position + Vector3(0.0, 1.2, -1.82))
	preview_flashlight.light_energy = 3.0
