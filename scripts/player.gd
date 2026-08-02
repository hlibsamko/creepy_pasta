extends CharacterBody3D

const WALK_SPEED := 4.6
const SPRINT_SPEED := 5.1
const JUMP_VELOCITY := 5.2
const MOUSE_SENSITIVITY := 0.0025
const FOOTSTEP_MIX_RATE := 22050
const WALK_STEP_INTERVAL := 0.48
const SPRINT_STEP_INTERVAL := 0.34
const REMOTE_SYNC_SPEED_MULTIPLIER := 1.15
const REMOTE_SYNC_HORIZONTAL_BUDGET_INITIAL := 0.8
const REMOTE_SYNC_HORIZONTAL_BUDGET_MAX := 3.2
const REMOTE_SYNC_VERTICAL_SPEED := 18.0
const REMOTE_SYNC_VERTICAL_BUDGET_INITIAL := 1.2
const REMOTE_SYNC_VERTICAL_BUDGET_MAX := 4.0
const REMOTE_SYNC_MAX_ELAPSED := 0.5

@export var player_id := 1
@export var player_color := Color(0.85, 0.82, 0.62)
@export var session_id := ""

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var controls_enabled := true
var is_sprinting := false
var step_timer := 0.0
var footstep_player: AudioStreamPlayer
var walk_step_stream: AudioStreamWAV
var sprint_step_stream: AudioStreamWAV
var footstep_rng := RandomNumberGenerator.new()
var active_session_filter := ""
var remote_sync_position := Vector3.ZERO
var remote_sync_horizontal_budget := REMOTE_SYNC_HORIZONTAL_BUDGET_INITIAL
var remote_sync_vertical_budget := REMOTE_SYNC_VERTICAL_BUDGET_INITIAL
var last_remote_sync_msec := 0


func _ready() -> void:
	add_to_group("players")
	set_multiplayer_authority(player_id)
	_apply_color()
	camera.current = has_control()
	_setup_footsteps()
	_apply_session_visibility()
	reset_remote_sync_tracking()


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

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
		elif velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (global_basis * Vector3(input.x, 0.0, input.y)).normalized()
	is_sprinting = Input.is_action_pressed("sprint") and direction.length() > 0.01
	var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	_update_footsteps(delta, direction.length())

	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
		_sync_state.rpc(global_position, rotation.y, head.rotation.x)


func has_control() -> bool:
	if not is_inside_tree() or not multiplayer:
		return false
	if multiplayer.has_multiplayer_peer():
		return is_multiplayer_authority()
	return player_id == 1


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		step_timer = 0.0


func set_active_session(session_filter: String) -> void:
	active_session_filter = session_filter
	_apply_session_visibility()


func reset_remote_sync_tracking() -> void:
	remote_sync_position = global_position
	remote_sync_horizontal_budget = REMOTE_SYNC_HORIZONTAL_BUDGET_INITIAL
	remote_sync_vertical_budget = REMOTE_SYNC_VERTICAL_BUDGET_INITIAL
	last_remote_sync_msec = Time.get_ticks_msec()


func _apply_session_visibility() -> void:
	if not is_node_ready():
		return
	var belongs_to_active_session := session_id == "" or session_id == active_session_filter
	visible = belongs_to_active_session
	collision_shape.disabled = not belongs_to_active_session


func _apply_color() -> void:
	var material := body_mesh.get_active_material(0)
	if material is StandardMaterial3D:
		var material_copy := material.duplicate() as StandardMaterial3D
		material_copy.albedo_color = player_color
		body_mesh.set_surface_override_material(0, material_copy)


func _setup_footsteps() -> void:
	if not _audio_enabled() or not has_control():
		return

	footstep_rng.randomize()
	footstep_player = AudioStreamPlayer.new()
	footstep_player.volume_db = -24.0
	add_child(footstep_player)
	walk_step_stream = _create_footstep_stream(0.11, 0.38)
	sprint_step_stream = _create_footstep_stream(0.095, 0.5)


func _update_footsteps(delta: float, movement_amount: float) -> void:
	if not footstep_player or not has_control():
		return
	if movement_amount <= 0.01 or not is_on_floor():
		step_timer = 0.0
		return

	step_timer -= delta
	if step_timer > 0.0:
		return

	footstep_player.pitch_scale = footstep_rng.randf_range(0.92, 1.08)
	footstep_player.stream = sprint_step_stream if is_sprinting else walk_step_stream
	footstep_player.play()
	step_timer = SPRINT_STEP_INTERVAL if is_sprinting else WALK_STEP_INTERVAL


func _create_footstep_stream(duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_count := int(FOOTSTEP_MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / max(float(sample_count - 1), 1.0)
		var thump: float = sin(TAU * 82.0 * progress) * (1.0 - progress)
		var grit: float = footstep_rng.randf_range(-1.0, 1.0) * (1.0 - smoothstep(0.0, 1.0, progress))
		var envelope: float = smoothstep(0.0, 0.05, progress) * (1.0 - smoothstep(0.45, 1.0, progress))
		var value: float = (thump * 0.65 + grit * 0.35) * amplitude * envelope
		data.encode_s16(sample_index * 2, int(clamp(value, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = FOOTSTEP_MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _audio_enabled() -> bool:
	return not OS.has_feature("dedicated_server") and DisplayServer.get_name() != "headless"


@rpc("any_peer", "call_remote", "unreliable")
func _sync_state(new_position: Vector3, yaw: float, pitch: float) -> void:
	if not is_inside_tree():
		return
	if has_control():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not _is_remote_sync_sender_valid(sender_id):
		return
	var now_msec := Time.get_ticks_msec()
	var elapsed := clampf(
		float(now_msec - last_remote_sync_msec) / 1000.0,
		1.0 / 120.0,
		REMOTE_SYNC_MAX_ELAPSED
	)
	last_remote_sync_msec = now_msec
	if not _try_accept_remote_sync_position(new_position, elapsed):
		return
	if not is_finite(yaw) or not is_finite(pitch):
		return

	if multiplayer.is_server():
		global_position = new_position
		rotation.y = yaw
		head.rotation.x = clampf(pitch, deg_to_rad(-82), deg_to_rad(82))
		return
	global_position = global_position.lerp(new_position, 0.35)
	rotation.y = lerp_angle(rotation.y, yaw, 0.35)
	head.rotation.x = lerp_angle(
		head.rotation.x,
		clampf(pitch, deg_to_rad(-82), deg_to_rad(82)),
		0.35
	)


func _is_remote_sync_sender_valid(sender_id: int) -> bool:
	return sender_id == player_id


func _try_accept_remote_sync_position(new_position: Vector3, elapsed: float) -> bool:
	if not new_position.is_finite():
		return false
	var safe_elapsed := clampf(elapsed, 0.0, REMOTE_SYNC_MAX_ELAPSED)
	remote_sync_horizontal_budget = minf(
		remote_sync_horizontal_budget
			+ SPRINT_SPEED * REMOTE_SYNC_SPEED_MULTIPLIER * safe_elapsed,
		REMOTE_SYNC_HORIZONTAL_BUDGET_MAX
	)
	remote_sync_vertical_budget = minf(
		remote_sync_vertical_budget + REMOTE_SYNC_VERTICAL_SPEED * safe_elapsed,
		REMOTE_SYNC_VERTICAL_BUDGET_MAX
	)
	var horizontal_distance := Vector2(
		new_position.x - remote_sync_position.x,
		new_position.z - remote_sync_position.z
	).length()
	var vertical_distance := absf(new_position.y - remote_sync_position.y)
	if (
		horizontal_distance > remote_sync_horizontal_budget
		or vertical_distance > remote_sync_vertical_budget
	):
		return false
	remote_sync_horizontal_budget = maxf(
		remote_sync_horizontal_budget - horizontal_distance,
		0.0
	)
	remote_sync_vertical_budget = maxf(
		remote_sync_vertical_budget - vertical_distance,
		0.0
	)
	remote_sync_position = new_position
	return true
