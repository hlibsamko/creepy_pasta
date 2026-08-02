class_name LevelExit
extends Area3D

signal entered

const ROOM_TONE_MIX_RATE := 16000
const ROOM_TONE_DURATION := 8.0

@export var closed := true
@export var room_tone_enabled := true
@export_range(20.0, 300.0, 1.0) var room_tone_frequency := 55.0

@onready var door: Node3D = $Door
@onready var glow: Node3D = $Glow
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var draft_cue: Node3D = get_node_or_null("DraftCue") as Node3D

var room_tone_player: AudioStreamPlayer3D


func _ready() -> void:
	_setup_room_tone()
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
	if draft_cue and draft_cue.has_method("set_active"):
		draft_cue.call("set_active", not closed)
	if room_tone_player:
		if closed:
			room_tone_player.stop()
		elif not room_tone_player.playing:
			room_tone_player.play()


func has_room_tone_cue() -> bool:
	return room_tone_enabled


func _setup_room_tone() -> void:
	if (
		not room_tone_enabled
		or OS.has_feature("dedicated_server")
		or DisplayServer.get_name() == "headless"
	):
		return
	room_tone_player = AudioStreamPlayer3D.new()
	room_tone_player.name = "RoomTone"
	room_tone_player.stream = _create_room_tone_stream()
	room_tone_player.volume_db = -27.0
	room_tone_player.unit_size = 2.5
	room_tone_player.max_distance = 10.0
	add_child(room_tone_player)


func _create_room_tone_stream() -> AudioStreamWAV:
	var sample_count := int(ROOM_TONE_MIX_RATE * ROOM_TONE_DURATION)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(ROOM_TONE_MIX_RATE)
		var fundamental := sin(TAU * room_tone_frequency * time) * 0.38
		var harmonic := sin(TAU * room_tone_frequency * 2.0 * time) * 0.12
		var breathing := 0.72 + sin(TAU * 0.25 * time) * 0.08
		var value := (fundamental + harmonic) * breathing * 0.16
		data.encode_s16(sample_index * 2, int(clamp(value, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = ROOM_TONE_MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


func _on_body_entered(body: Node3D) -> void:
	if closed:
		return
	if not body.has_method("has_control") or not body.has_control():
		return

	entered.emit()
