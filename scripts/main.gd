extends Node3D

const PORT := 24567
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SPAWNS := [
	Vector3(-5.5, 0.2, -4.5),
	Vector3(5.5, 0.2, -4.5),
	Vector3(-5.5, 0.2, 4.5),
	Vector3(5.5, 0.2, 4.5),
	Vector3(0.0, 0.2, 0.0),
]
const PLAYER_COLORS := [
	Color(0.95, 0.88, 0.55),
	Color(0.45, 0.85, 1.00),
	Color(0.95, 0.45, 0.58),
	Color(0.55, 1.00, 0.62),
	Color(0.72, 0.58, 1.00),
]

@onready var world: Node3D = $World
@onready var notes: Node3D = $World/Notes
@onready var players: Node3D = $Players
@onready var ui_layer: CanvasLayer = $Ui

var menu: Control
var status_label: Label
var hud_label: Label
var ip_edit: LineEdit
var collected_notes := 0
var total_notes := 0
var started := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_build_world()
	_build_ui()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if started:
			menu.show()


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.035, 0.035, 0.045)
	env.ambient_light_energy = 0.4
	environment.environment = env
	world.add_child(environment)

	_add_box("Floor", Vector3(0, -0.1, 0), Vector3(16, 0.2, 12), Color(0.08, 0.075, 0.07), true)
	_add_box("Ceiling", Vector3(0, 3.2, 0), Vector3(16, 0.25, 12), Color(0.05, 0.048, 0.052), true)
	_add_box("NorthWall", Vector3(0, 1.55, -6), Vector3(16, 3.1, 0.25), Color(0.12, 0.11, 0.105), true)
	_add_box("SouthWall", Vector3(0, 1.55, 6), Vector3(16, 3.1, 0.25), Color(0.12, 0.11, 0.105), true)
	_add_box("WestWall", Vector3(-8, 1.55, 0), Vector3(0.25, 3.1, 12), Color(0.11, 0.105, 0.12), true)
	_add_box("EastWall", Vector3(8, 1.55, 0), Vector3(0.25, 3.1, 12), Color(0.11, 0.105, 0.12), true)

	_add_box("BrokenShelf", Vector3(-2.8, 0.65, -1.2), Vector3(3.4, 1.3, 0.35), Color(0.16, 0.10, 0.07), true)
	_add_box("LongTable", Vector3(2.8, 0.45, 1.6), Vector3(3.0, 0.9, 1.0), Color(0.12, 0.08, 0.055), true)
	_add_box("RitualMark", Vector3(0, 0.01, 0), Vector3(1.8, 0.02, 1.8), Color(0.25, 0.02, 0.025), false)

	var moon := DirectionalLight3D.new()
	moon.name = "ColdMoonLeak"
	moon.light_energy = 0.45
	moon.rotation_degrees = Vector3(-55, 28, 0)
	world.add_child(moon)

	for data in [
		["note_1", Vector3(-6.5, 0.55, -5.0), "The walls are listening."],
		["note_2", Vector3(6.4, 0.55, -5.0), "Do not look behind the shelf."],
		["note_3", Vector3(0.0, 0.55, 4.9), "Three notes open the way."],
	]:
		_add_note(data[0], data[1], data[2])


func _add_box(box_name: String, box_position: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var parent: Node3D = world
	if solid:
		var body := StaticBody3D.new()
		body.name = box_name
		body.position = box_position
		world.add_child(body)
		parent = body

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.name = "%sMesh" % box_name
	if not solid:
		mesh_instance.position = box_position

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)


func _add_note(note_id: String, note_position: Vector3, text: String) -> void:
	var area := Area3D.new()
	area.name = note_id
	area.position = note_position
	area.set_meta("text", text)
	area.body_entered.connect(_on_note_body_entered.bind(area))
	notes.add_child(area)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	collision.shape = shape
	area.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.82, 0.35)
	material.emission_enabled = true
	material.emission = Color(0.95, 0.75, 0.20)
	material.emission_energy_multiplier = 1.6
	mesh_instance.set_surface_override_material(0, material)
	area.add_child(mesh_instance)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.74, 0.30)
	light.light_energy = 0.45
	light.omni_range = 2.0
	area.add_child(light)
	total_notes += 1


func _build_ui() -> void:
	menu = Control.new()
	menu.name = "Menu"
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(menu)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 238)
	panel.position = Vector2(32, 32)
	menu.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Creepy Pasta 3D"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	status_label = Label.new()
	status_label.text = "Host a game or join a friend's IP."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "127.0.0.1"
	ip_edit.text = "127.0.0.1"
	box.add_child(ip_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)

	var host_button := Button.new()
	host_button.text = "Host"
	host_button.pressed.connect(_host_game)
	buttons.add_child(host_button)

	var join_button := Button.new()
	join_button.text = "Join"
	join_button.pressed.connect(_join_game)
	buttons.add_child(join_button)

	var offline_button := Button.new()
	offline_button.text = "Offline"
	offline_button.pressed.connect(_start_offline)
	buttons.add_child(offline_button)

	hud_label = Label.new()
	hud_label.position = Vector2(24, 590)
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.82))
	ui_layer.add_child(hud_label)


func _host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, 8)
	if error != OK:
		status_label.text = "Host failed: %s" % error
		return

	multiplayer.multiplayer_peer = peer
	_start_game()
	_spawn_player(multiplayer.get_unique_id())
	status_label.text = "Hosting on port %s. Share your IP with friends." % PORT


func _join_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip_edit.text.strip_edges(), PORT)
	if error != OK:
		status_label.text = "Join failed: %s" % error
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Connecting..."


func _start_offline() -> void:
	_start_game()
	_spawn_player(1)


func _start_game() -> void:
	if started:
		return

	started = true
	menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()


func _on_connected_to_server() -> void:
	_start_game()
	_request_spawn.rpc_id(1, multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	status_label.text = "Connection failed."


func _on_server_disconnected() -> void:
	started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in players.get_children():
		child.queue_free()
	menu.show()
	status_label.text = "Server disconnected."


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		for player in players.get_children():
			var existing_id := int(player.name)
			_spawn_player_remote.rpc_id(peer_id, existing_id, player.global_position, player.player_color)
		_spawn_player(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var node := players.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()


@rpc("any_peer", "call_remote", "reliable")
func _request_spawn(peer_id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(peer_id)


func _spawn_player(peer_id: int) -> void:
	if players.has_node(str(peer_id)):
		return

	var spawn_index := players.get_child_count() % SPAWNS.size()
	var color: Color = PLAYER_COLORS[spawn_index % PLAYER_COLORS.size()]
	if multiplayer.has_multiplayer_peer():
		_spawn_player_remote.rpc(peer_id, SPAWNS[spawn_index], color)
	_spawn_player_remote(peer_id, SPAWNS[spawn_index], color)


@rpc("authority", "call_remote", "reliable")
func _spawn_player_remote(peer_id: int, spawn_position: Vector3, color: Color) -> void:
	if players.has_node(str(peer_id)):
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.player_id = peer_id
	player.player_color = color
	player.global_position = spawn_position
	players.add_child(player)


func _on_note_body_entered(body: Node3D, area: Area3D) -> void:
	if not body.has_method("is_multiplayer_authority") or not body.is_multiplayer_authority():
		return

	if multiplayer.has_multiplayer_peer():
		_collect_note.rpc(area.name, str(area.get_meta("text")))
	_collect_note(area.name, str(area.get_meta("text")))


@rpc("any_peer", "call_remote", "reliable")
func _collect_note(note_id: String, note_text: String) -> void:
	var note := notes.get_node_or_null(note_id)
	if not note:
		return

	note.queue_free()
	collected_notes += 1
	_update_hud(note_text)


func _update_hud(last_note := "") -> void:
	var text := "WASD + mouse. Esc frees cursor. Notes: %s/%s" % [collected_notes, total_notes]
	if last_note != "":
		text += " | %s" % last_note
	hud_label.text = text
