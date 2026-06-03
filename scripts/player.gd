extends CharacterBody3D

const WALK_SPEED := 4.6
const SPRINT_SPEED := 5.1
const MOUSE_SENSITIVITY := 0.0025

@export var player_id := 1
@export var player_color := Color(0.85, 0.82, 0.62)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $BodyMesh

var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var controls_enabled := true


func _ready() -> void:
	add_to_group("players")
	set_multiplayer_authority(player_id)
	_apply_color()
	camera.current = has_control()


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or not has_control():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-82), deg_to_rad(82))


func _physics_process(delta: float) -> void:
	if not controls_enabled or not has_control():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (global_basis * Vector3(input.x, 0.0, input.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

	if multiplayer.has_multiplayer_peer():
		_sync_state.rpc(global_position, rotation.y, head.rotation.x)


func has_control() -> bool:
	if multiplayer.has_multiplayer_peer():
		return is_multiplayer_authority()
	return player_id == 1


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled


func _apply_color() -> void:
	var material := body_mesh.get_active_material(0)
	if material is StandardMaterial3D:
		var material_copy := material.duplicate() as StandardMaterial3D
		material_copy.albedo_color = player_color
		body_mesh.set_surface_override_material(0, material_copy)


@rpc("any_peer", "call_remote", "unreliable")
func _sync_state(new_position: Vector3, yaw: float, pitch: float) -> void:
	if has_control():
		return

	global_position = global_position.lerp(new_position, 0.35)
	rotation.y = lerp_angle(rotation.y, yaw, 0.35)
	head.rotation.x = lerp_angle(head.rotation.x, pitch, 0.35)
