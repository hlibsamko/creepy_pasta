class_name PressurePlate
extends Area3D

signal active_changed(is_active: bool)

@export var required_players := 1
@export var latch_once := true
@export var inactive_color := Color(0.34, 0.22, 0.48, 1.0)
@export var active_color := Color(0.58, 0.9, 0.42, 1.0)

@onready var plate_mesh: MeshInstance3D = $Plate

var active := false
var latched := false
var bodies_on_plate: Array[Node3D] = []
var plate_material: StandardMaterial3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_material()
	_update_active_state()


func is_active() -> bool:
	return active


func set_latched_active(is_latched_active: bool) -> void:
	latched = is_latched_active
	active = is_latched_active
	_apply_visual_state()


func refresh_state() -> void:
	_update_active_state()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	if not bodies_on_plate.has(body):
		bodies_on_plate.append(body)
	_update_active_state()


func _on_body_exited(body: Node3D) -> void:
	bodies_on_plate.erase(body)
	_update_active_state()


func _update_active_state() -> void:
	if latched:
		return

	var valid_count := 0
	var valid_bodies: Array[Node3D] = []
	for body in bodies_on_plate:
		if is_instance_valid(body):
			valid_count += 1
			valid_bodies.append(body)
	bodies_on_plate = valid_bodies

	var next_active := valid_count >= required_players
	if next_active and latch_once:
		latched = true
	if active == next_active:
		return

	active = next_active
	_apply_visual_state()
	active_changed.emit(active)


func _setup_material() -> void:
	var material := plate_mesh.get_active_material(0)
	if material is StandardMaterial3D:
		plate_material = material.duplicate() as StandardMaterial3D
		plate_mesh.set_surface_override_material(0, plate_material)
	_apply_visual_state()


func _apply_visual_state() -> void:
	plate_mesh.position.y = -0.025 if active else 0.02
	if not plate_material:
		return

	var color := active_color if active else inactive_color
	plate_material.albedo_color = color.darkened(0.35)
	plate_material.emission = color
	plate_material.emission_energy_multiplier = 0.95 if active else 0.45
