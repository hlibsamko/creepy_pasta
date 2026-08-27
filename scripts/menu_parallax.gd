class_name MenuParallax
extends Control

@export_range(0.0, 1.0, 0.01) var pointer_influence := 0.72
@export var camera_travel := Vector2(0.72, 0.18)
@export_range(0.0, 10.0, 0.1) var idle_delay_seconds := 2.5
@export_range(0.1, 5.0, 0.05) var idle_fade_seconds := 1.25
@export_range(0.0, 0.5, 0.01) var idle_strength := 0.16

@onready var scene_camera: Camera3D = $SceneView/Viewport/World/Camera
@onready var wind_bed_player: AudioStreamPlayer = $Audio/WindBed
@onready var ghost_wind_player: AudioStreamPlayer = $Audio/GhostWind
@onready var howl_player: AudioStreamPlayer = $Audio/Howl
@onready var creak_player: AudioStreamPlayer = $Audio/Creak
@onready var event_timer: Timer = $Audio/EventTimer

var _active := false
var _audio_armed := false
var _camera_origin := Vector3.ZERO
var _last_pointer_position := Vector2.ZERO
var _pointer_idle_seconds := 0.0
var _idle_blend := 0.0
var _rng := RandomNumberGenerator.new()
var _wind_bed_streams: Array[AudioStream] = [
	preload("res://assets/audio/menu/night_wind_a_cc0.ogg"),
	preload("res://assets/audio/menu/night_wind_b_cc0.ogg"),
	preload("res://assets/audio/menu/night_wind_c_cc0.ogg"),
]
var _creak_streams: Array[AudioStream] = [
	preload("res://assets/audio/menu/floor_creak_01.mp3"),
	preload("res://assets/audio/menu/floor_creak_02.mp3"),
	preload("res://assets/audio/menu/floor_creak_03.mp3"),
	preload("res://assets/audio/menu/floor_creak_04.mp3"),
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera_origin = scene_camera.position
	_last_pointer_position = get_viewport().get_mouse_position()
	_rng.randomize()
	visibility_changed.connect(_sync_active_state)
	event_timer.timeout.connect(_on_event_timer_timeout)
	wind_bed_player.finished.connect(_on_wind_bed_finished)
	ghost_wind_player.finished.connect(_on_ghost_wind_finished)
	_sync_active_state()


func _process(delta: float) -> void:
	if not _active:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var pointer_position := get_viewport().get_mouse_position()
	if pointer_position.distance_squared_to(_last_pointer_position) > 0.25:
		_pointer_idle_seconds = 0.0
		_idle_blend = 0.0
	else:
		_pointer_idle_seconds += delta
		if _pointer_idle_seconds >= idle_delay_seconds:
			_idle_blend = move_toward(_idle_blend, 1.0, delta / idle_fade_seconds)
	_last_pointer_position = pointer_position
	var pointer := pointer_position / viewport_size
	var pointer_target := (pointer * 2.0 - Vector2.ONE).clamp(Vector2(-1.0, -1.0), Vector2.ONE)
	var idle := Vector2(sin(Time.get_ticks_msec() * 0.00013), cos(Time.get_ticks_msec() * 0.00009))
	idle *= idle_strength * _idle_blend
	var motion := pointer_target * pointer_influence + idle
	scene_camera.position = _camera_origin + Vector3(
		motion.x * camera_travel.x,
		-motion.y * camera_travel.y,
		0.0
	)


func arm_audio() -> void:
	if _audio_armed or not _audio_available():
		return
	_audio_armed = true
	wind_bed_player.stream = _wind_bed_streams[_rng.randi_range(0, _wind_bed_streams.size() - 1)]
	if _active:
		_start_audio()


func set_connection_mode(enabled: bool) -> void:
	visible = enabled
	if not enabled:
		_audio_armed = false


func _sync_active_state() -> void:
	_active = is_visible_in_tree() and not OS.has_feature("dedicated_server") and DisplayServer.get_name() != "headless"
	set_process(_active)
	if _active:
		_last_pointer_position = get_viewport().get_mouse_position()
		_pointer_idle_seconds = 0.0
		_idle_blend = 0.0
	if _active and _audio_armed:
		_start_audio()
	else:
		_stop_audio()


func _start_audio() -> void:
	if not _audio_available():
		return
	if not wind_bed_player.playing:
		wind_bed_player.stream = _wind_bed_streams[_rng.randi_range(0, _wind_bed_streams.size() - 1)]
		wind_bed_player.pitch_scale = _rng.randf_range(0.94, 1.02)
		wind_bed_player.play()
	if not ghost_wind_player.playing:
		ghost_wind_player.pitch_scale = _rng.randf_range(0.96, 1.01)
		ghost_wind_player.play()
	if event_timer.is_stopped():
		_schedule_event(4.0, 9.0)


func _stop_audio() -> void:
	event_timer.stop()
	for player in [wind_bed_player, ghost_wind_player, howl_player, creak_player]:
		if player:
			player.stop()


func _on_event_timer_timeout() -> void:
	if not _active or not _audio_armed:
		return
	if _rng.randf() < 0.74:
		creak_player.stream = _creak_streams[_rng.randi_range(0, _creak_streams.size() - 1)]
		creak_player.pitch_scale = _rng.randf_range(0.88, 1.08)
		creak_player.volume_db = _rng.randf_range(-25.0, -19.0)
		creak_player.play()
		_schedule_event(11.0, 24.0)
	else:
		howl_player.pitch_scale = _rng.randf_range(0.84, 0.96)
		howl_player.volume_db = _rng.randf_range(-33.0, -27.0)
		howl_player.play()
		_schedule_event(24.0, 48.0)


func _schedule_event(minimum: float, maximum: float) -> void:
	event_timer.start(_rng.randf_range(minimum, maximum))


func _on_wind_bed_finished() -> void:
	if not _active or not _audio_armed:
		return
	wind_bed_player.stream = _wind_bed_streams[_rng.randi_range(0, _wind_bed_streams.size() - 1)]
	wind_bed_player.pitch_scale = _rng.randf_range(0.94, 1.02)
	wind_bed_player.play()


func _on_ghost_wind_finished() -> void:
	if not _active or not _audio_armed:
		return
	ghost_wind_player.pitch_scale = _rng.randf_range(0.96, 1.01)
	ghost_wind_player.play()


func _audio_available() -> bool:
	return not OS.has_feature("dedicated_server") and DisplayServer.get_name() != "headless"
