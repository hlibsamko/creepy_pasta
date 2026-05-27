class_name GameUi
extends CanvasLayer

signal host_requested
signal join_requested(ip_address: String)
signal offline_requested

@onready var menu: Control = $Menu
@onready var status_label: Label = $Menu/Panel/Margin/Box/StatusLabel
@onready var ip_edit: LineEdit = $Menu/Panel/Margin/Box/IpEdit
@onready var host_button: Button = $Menu/Panel/Margin/Box/Buttons/HostButton
@onready var join_button: Button = $Menu/Panel/Margin/Box/Buttons/JoinButton
@onready var offline_button: Button = $Menu/Panel/Margin/Box/Buttons/OfflineButton
@onready var hud_label: Label = $HudLabel


func _ready() -> void:
	host_button.pressed.connect(host_requested.emit)
	join_button.pressed.connect(_emit_join_requested)
	offline_button.pressed.connect(offline_requested.emit)


func show_menu() -> void:
	menu.show()


func hide_menu() -> void:
	menu.hide()


func set_status(text: String) -> void:
	status_label.text = text


func update_hud(collected_notes: int, total_notes: int, last_note := "") -> void:
	var text := "WASD + mouse. Esc frees cursor. Notes: %s/%s" % [collected_notes, total_notes]
	if last_note != "":
		text += " | %s" % last_note
	hud_label.text = text


func _emit_join_requested() -> void:
	join_requested.emit(ip_edit.text)
