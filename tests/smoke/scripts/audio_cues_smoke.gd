extends Node

const AUDIO_CUES_SCRIPT := preload("res://scripts/audio_cues.gd")


func _ready() -> void:
	var cues := AUDIO_CUES_SCRIPT.new()
	add_child(cues)
	if not cues.has_method("play_power_outage") or not cues.has_method("play_power_restore"):
		_fail("Maintenance power-change cues are missing")
		return

	var default_profile: Vector2 = cues.call("_get_ambience_profile", "res://scenes/level.tscn")
	var house_profile: Vector2 = cues.call(
		"_get_ambience_profile",
		"res://scenes/endless_house/endless_house_builder_demo.tscn"
	)
	var unlit_profile: Vector2 = cues.call(
		"_get_ambience_profile",
		"res://scenes/endless_house/unlit_evidence_demo.tscn"
	)
	if default_profile == house_profile or house_profile == unlit_profile:
		_fail("Endless House ambience profiles are no longer distinct")
		return
	if unlit_profile != Vector2(50.0, 150.0):
		_fail("The Unlit ambience lost its electrical-hum profile")
		return

	var stream: AudioStreamWAV = cues.call(
		"_create_ambience_stream",
		unlit_profile.x,
		unlit_profile.y
	)
	var expected_samples := int(AUDIO_CUES_SCRIPT.MIX_RATE * 24.0)
	if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		_fail("Ambient stream is not configured as a forward loop")
		return
	if stream.loop_begin != 0 or stream.loop_end != expected_samples:
		_fail("Ambient loop boundaries do not cover the generated stream")
		return
	if stream.data.size() != expected_samples * 2:
		_fail("Ambient stream sample length changed unexpectedly")
		return

	var first_sample := stream.data.decode_s16(0)
	var last_sample := stream.data.decode_s16(stream.data.size() - 2)
	if absi(first_sample - last_sample) > 256:
		_fail("Ambient stream endpoints are no longer safe to loop")
		return

	print("[smoke] Looping room ambience profiles OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
