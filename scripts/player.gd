extends CharacterBody2D

const SPEED := 180.0

@export var player_id := 1
@export var player_color := Color(0.95, 0.95, 0.82)

var player_name := "wanderer"

func _ready() -> void:
	set_multiplayer_authority(player_id)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = direction * SPEED
		move_and_slide()
		_sync_position.rpc(global_position)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 70.0, Color(player_color.r, player_color.g, player_color.b, 0.08))
	draw_circle(Vector2.ZERO, 20.0, Color(player_color.r, player_color.g, player_color.b, 0.18))
	draw_circle(Vector2.ZERO, 10.0, player_color)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, Color.BLACK, 2.0)


@rpc("any_peer", "call_remote", "unreliable")
func _sync_position(new_position: Vector2) -> void:
	if not is_multiplayer_authority():
		global_position = global_position.lerp(new_position, 0.35)
