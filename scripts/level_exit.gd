class_name LevelExit
extends Area3D

signal entered

@export var closed := true

@onready var door: Node3D = $Door
@onready var glow: Node3D = $Glow
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_state()


func open() -> void:
	closed = false
	_apply_state()


func close() -> void:
	closed = true
	_apply_state()


func _apply_state() -> void:
	if not is_node_ready():
		return

	monitoring = not closed
	collision.disabled = closed
	door.visible = closed
	glow.visible = not closed


func _on_body_entered(body: Node3D) -> void:
	if closed:
		return
	if not body.has_method("has_control") or not body.has_control():
		return

	entered.emit()
