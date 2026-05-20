extends Node2D

const PORT := 24567
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SPAWNS := [
	Vector2(180, 180),
	Vector2(720, 180),
	Vector2(180, 460),
	Vector2(720, 460),
	Vector2(450, 320),
]
const PLAYER_COLORS := [
	Color(0.95, 0.92, 0.70),
	Color(0.62, 0.90, 1.00),
	Color(0.95, 0.62, 0.70),
	Color(0.68, 1.00, 0.74),
	Color(0.84, 0.70, 1.00),
]

@onready var world: Node2D = $World
@onready var notes: Node2D = $World/Notes
@onready var players: Node2D = $Players
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


func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.035, 0.042)
	background.size = Vector2(960, 640)
	background.position = Vector2.ZERO
	world.add_child(background)

	for rect in [
		Rect2(80, 70, 800, 28),
		Rect2(80, 540, 800, 28),
		Rect2(80, 70, 28, 498),
		Rect2(852, 70, 28, 498),
		Rect2(280, 205, 390, 24),
		Rect2(200, 390, 210, 24),
		Rect2(560, 390, 190, 24),
	]:
		_add_wall(rect)

	for data in [
		["note_1", Vector2(158, 142), "The door remembers every name."],
		["note_2", Vector2(796, 140), "Do not split up after midnight."],
		["note_3", Vector2(450, 486), "If the screen flickers, stay still."],
	]:
		_add_note(data[0], data[1], data[2])


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position
	world.add_child(body)

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.size * 0.5
	body.add_child(shape)

	var visual := ColorRect.new()
	visual.color = Color(0.13, 0.12, 0.13)
	visual.size = rect.size
	body.add_child(visual)


func _add_note(note_id: String, note_position: Vector2, text: String) -> void:
	var area := Area2D.new()
	area.name = note_id
	area.position = note_position
	area.set_meta("text", text)
	area.body_entered.connect(_on_note_body_entered.bind(area))
	notes.add_child(area)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	area.add_child(shape)

	var label := Label.new()
	label.text = "?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-10, -16)
	label.size = Vector2(20, 28)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.55))
	area.add_child(label)
	total_notes += 1


func _build_ui() -> void:
	menu = Control.new()
	menu.name = "Menu"
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(menu)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 230)
	panel.position = Vector2(32, 32)
	menu.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Creepy Pasta"
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
	_update_hud()


func _on_connected_to_server() -> void:
	_start_game()
	_request_spawn.rpc_id(1, multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	status_label.text = "Connection failed."


func _on_server_disconnected() -> void:
	started = false
	players.get_children().map(func(child): child.queue_free())
	menu.show()
	status_label.text = "Server disconnected."


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
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
	_spawn_player_remote.rpc(peer_id, SPAWNS[spawn_index], color)
	_spawn_player_remote(peer_id, SPAWNS[spawn_index], color)


@rpc("authority", "call_remote", "reliable")
func _spawn_player_remote(peer_id: int, spawn_position: Vector2, color: Color) -> void:
	if players.has_node(str(peer_id)):
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.player_id = peer_id
	player.player_color = color
	player.global_position = spawn_position
	players.add_child(player)


func _on_note_body_entered(body: Node2D, area: Area2D) -> void:
	if not body.has_method("is_multiplayer_authority") or not body.is_multiplayer_authority():
		return

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
	var text := "WASD to move. Notes: %s/%s" % [collected_notes, total_notes]
	if last_note != "":
		text += " | %s" % last_note
	hud_label.text = text
