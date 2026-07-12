extends CharacterBody3D

const WALK_SPEED := 4.6
const SPRINT_SPEED := 5.1
const MOUSE_SENSITIVITY := 0.0025
const FOOTSTEP_MIX_RATE := 22050
const WALK_STEP_INTERVAL := 0.48
const SPRINT_STEP_INTERVAL := 0.34

@export var player_id := 1
@export var player_color := Color(0.85, 0.82, 0.62)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $BodyMesh

var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var controls_enabled := true
var is_sprinting := false
var step_timer := 0.0
var footstep_player: AudioStreamPlayer
var walk_step_stream: AudioStreamWAV
var sprint_step_stream: AudioStreamWAV
var footstep_rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("players")
	set_multiplayer_authority(player_id)
	_apply_color()
	camera.current = has_control()
	_setup_footsteps()


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
	is_sprinting = Input.is_action_pressed("sprint") and direction.length() > 0.01
	var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	_update_footsteps(delta, direction.length())

	if multiplayer.has_multiplayer_peer():
		_sync_state.rpc(global_position, rotation.y, head.rotation.x)


func has_control() -> bool:
	if multiplayer.has_multiplayer_peer():
		return is_multiplayer_authority()
	return player_id == 1


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		step_timer = 0.0


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
	if has_control():
		return

	global_position = global_position.lerp(new_position, 0.35)
	rotation.y = lerp_angle(rotation.y, yaw, 0.35)
	head.rotation.x = lerp_angle(head.rotation.x, pitch, 0.35)
