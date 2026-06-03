class_name CorridorMonster
extends CharacterBody3D

signal killed_player(reason: String)

const SPEED := 4.8
const DEATH_REASON := "You've been killed by corridor monster"

@export var kill_distance := 0.9
@export var start_delay := 2.5

@onready var kill_zone: Area3D = $KillZone

var active := true
var chase_started := false
var target: Node3D


func _ready() -> void:
	kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	_start_chase_after_delay()


func _physics_process(_delta: float) -> void:
	if not active or not chase_started:
		velocity = Vector3.ZERO
		return

	target = _find_target()
	if not target:
		return

	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length() <= kill_distance:
		_kill_player()
		return

	velocity = offset.normalized() * SPEED
	move_and_slide()


func stop_chase() -> void:
	active = false
	velocity = Vector3.ZERO


func _find_target() -> Node3D:
	for player in get_tree().get_nodes_in_group("players"):
		if player.has_method("has_control") and player.has_control():
			return player
	return null


func _on_kill_zone_body_entered(body: Node3D) -> void:
	if not active or not chase_started:
		return
	if body.has_method("has_control") and body.has_control():
		_kill_player()


func _kill_player() -> void:
	active = false
	killed_player.emit(DEATH_REASON)


func _start_chase_after_delay() -> void:
	await get_tree().create_timer(start_delay).timeout
	if active:
		chase_started = true
