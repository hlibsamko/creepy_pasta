extends Node

const MIX_RATE := 22050
const VOLUME_DB := -14.0
const AMBIENCE_VOLUME_DB := -31.0

var ambience_player: AudioStreamPlayer
var tone_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	if not _audio_enabled():
		return

	ambience_player = AudioStreamPlayer.new()
	ambience_player.volume_db = AMBIENCE_VOLUME_DB
	add_child(ambience_player)


func _exit_tree() -> void:
	if ambience_player:
		ambience_player.stop()
		ambience_player.stream = null
	for player in tone_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.queue_free()
	tone_players.clear()


func play_ambience(level_path: String) -> void:
	if not _audio_enabled() or not ambience_player:
		return

	var profile := _get_ambience_profile(level_path)

	ambience_player.stop()
	ambience_player.stream = _create_ambience_stream(profile.x, profile.y)
	ambience_player.play()


func _get_ambience_profile(level_path: String) -> Vector2:
	if "unlit_evidence_demo" in level_path:
		return Vector2(50.0, 150.0)
	if "endless_house_builder_demo" in level_path:
		return Vector2(54.0, 83.0)
	if "next_place" in level_path:
		return Vector2(66.0, 123.0)
	if "backrooms" in level_path:
		return Vector2(49.0, 97.0)
	if "corridor" in level_path:
		return Vector2(42.0, 75.0)
	if "fourth_room" in level_path:
		return Vector2(72.0, 144.0)
	return Vector2(58.0, 91.0)


func play_note_pickup() -> void:
	_play_tone(740.0, 0.09, 0.45)
	_play_tone(990.0, 0.12, 0.32, 0.055)


func play_exit_open() -> void:
	_play_tone(220.0, 0.2, 0.5)
	_play_tone(440.0, 0.35, 0.36, 0.09)


func play_exit_close() -> void:
	_play_tone(180.0, 0.18, 0.42)
	_play_tone(95.0, 0.32, 0.34, 0.07)


func play_victory() -> void:
	_play_tone(330.0, 0.16, 0.42)
	_play_tone(495.0, 0.22, 0.38, 0.08)
	_play_tone(660.0, 0.28, 0.34, 0.18)


func play_threat() -> void:
	_play_tone(92.0, 0.28, 0.5)
	_play_tone(61.0, 0.42, 0.38, 0.08)


func play_power_outage() -> void:
	_play_tone(118.0, 0.16, 0.38)
	_play_tone(52.0, 0.34, 0.46, 0.07)


func play_power_restore() -> void:
	_play_tone(74.0, 0.12, 0.28)
	_play_tone(148.0, 0.2, 0.32, 0.06)


func _play_tone(frequency: float, duration: float, amplitude: float, delay := 0.0) -> void:
	if not _audio_enabled():
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	var stream := _create_tone_stream(frequency, duration, amplitude)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = VOLUME_DB
	tone_players.append(player)
	player.finished.connect(_on_tone_finished.bind(player))
	add_child(player)
	player.play()


func _on_tone_finished(player: AudioStreamPlayer) -> void:
	tone_players.erase(player)
	player.stream = null
	player.queue_free()


func _create_tone_stream(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for sample_index in range(sample_count):
		var time := float(sample_index) / float(MIX_RATE)
		var envelope := _get_envelope(float(sample_index) / max(float(sample_count - 1), 1.0))
		var value := sin(TAU * frequency * time) * amplitude * envelope
		data.encode_s16(sample_index * 2, int(clamp(value, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _create_ambience_stream(base_frequency: float, color_frequency: float) -> AudioStreamWAV:
	var duration := 24.0
	var sample_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for sample_index in range(sample_count):
		var time: float = float(sample_index) / float(MIX_RATE)
		var low: float = sin(TAU * base_frequency * time) * 0.48
		var modulation: float = sin(TAU * 0.125 * time) * 0.6
		var color: float = sin(TAU * color_frequency * time + modulation) * 0.22
		var tremble: float = sin(TAU * 0.25 * time) * 0.12
		var value: float = (low + color + tremble) * 0.18
		data.encode_s16(sample_index * 2, int(clamp(value, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


func _get_envelope(progress: float) -> float:
	var attack: float = smoothstep(0.0, 0.08, progress)
	var release: float = 1.0 - smoothstep(0.62, 1.0, progress)
	return attack * release


func _audio_enabled() -> bool:
	return not OS.has_feature("dedicated_server") and DisplayServer.get_name() != "headless"
