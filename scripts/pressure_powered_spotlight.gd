class_name PressurePoweredSpotlight
extends SpotLight3D

signal outage_changed(is_in_outage: bool)

@export var power_source_path: NodePath
@export var powered_energy := 5.0
@export var unpowered_energy := 0.0
@export var stopping_light_group := "unlit_stopping_lights"

var powered := false
var power_source: Node
var outage_remaining := 0.0


func _ready() -> void:
	add_to_group(stopping_light_group)
	set_power_source(get_node_or_null(power_source_path))


func _process(delta: float) -> void:
	if outage_remaining > 0.0:
		var was_in_outage := is_in_outage()
		outage_remaining = maxf(outage_remaining - delta, 0.0)
		if was_in_outage and not is_in_outage():
			outage_changed.emit(false)
	_refresh_powered_state()


func set_powered(value: bool) -> void:
	if powered == value:
		return
	powered = value
	light_energy = powered_energy if powered else unpowered_energy


func is_powered() -> bool:
	return powered


func trigger_outage(duration_seconds: float) -> void:
	var was_in_outage := is_in_outage()
	outage_remaining = maxf(outage_remaining, maxf(duration_seconds, 0.0))
	if not was_in_outage and is_in_outage():
		outage_changed.emit(true)
	_refresh_powered_state()


func clear_outage() -> void:
	var was_in_outage := is_in_outage()
	outage_remaining = 0.0
	if was_in_outage:
		outage_changed.emit(false)
	_refresh_powered_state()


func is_in_outage() -> bool:
	return outage_remaining > 0.0


func get_outage_state() -> Dictionary:
	return {"outage_remaining": outage_remaining}


func apply_outage_state(state: Dictionary) -> void:
	var was_in_outage := is_in_outage()
	outage_remaining = maxf(float(state.get("outage_remaining", 0.0)), 0.0)
	if was_in_outage != is_in_outage():
		outage_changed.emit(is_in_outage())
	_refresh_powered_state()


func get_sync_state() -> Dictionary:
	return get_outage_state()


func apply_sync_state(state: Dictionary) -> void:
	apply_outage_state(state)


func set_power_source(source: Node) -> void:
	if (
		is_instance_valid(power_source)
		and power_source.has_signal("active_changed")
		and power_source.active_changed.is_connected(_on_power_source_active_changed)
	):
		power_source.active_changed.disconnect(_on_power_source_active_changed)
	power_source = source
	if is_inside_tree() and is_instance_valid(power_source):
		power_source_path = get_path_to(power_source)
	if (
		is_instance_valid(power_source)
		and power_source.has_signal("active_changed")
		and not power_source.active_changed.is_connected(_on_power_source_active_changed)
	):
		power_source.active_changed.connect(_on_power_source_active_changed)
	_refresh_powered_state()


func _on_power_source_active_changed(_is_active: bool) -> void:
	_refresh_powered_state()


func _refresh_powered_state() -> void:
	var source_active := false
	if is_instance_valid(power_source) and power_source.has_method("is_active"):
		source_active = bool(power_source.call("is_active"))
	set_powered(source_active and not is_in_outage())
