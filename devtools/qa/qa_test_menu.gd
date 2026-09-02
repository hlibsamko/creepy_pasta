class_name QaTestMenu
extends PanelContainer

signal panel_open_changed(is_open: bool)
signal level_requested(scene_path: String)
signal invulnerable_changed(enabled: bool)
signal noclip_changed(enabled: bool)
signal speed_changed(multiplier: float)
signal monsters_paused_changed(paused: bool)
signal reload_requested
signal teleport_spawn_requested
signal teleport_exit_requested
signal open_exit_requested
signal complete_objectives_requested

var expanded := false
var level_select: OptionButton
var body: VBoxContainer
var collapse_button: Button
var invulnerable_toggle: CheckButton
var noclip_toggle: CheckButton
var pause_monsters_toggle: CheckButton
var speed_select: OptionButton
var diagnostics_label: Label
var notice_label: Label


func _ready() -> void:
	_build_interface()
	_apply_expanded_state(false)


func toggle_panel() -> void:
	expanded = not expanded
	_apply_expanded_state(true)


func set_panel_open(is_open: bool) -> void:
	if expanded == is_open:
		return
	expanded = is_open
	_apply_expanded_state(true)


func is_panel_open() -> bool:
	return expanded


func set_levels(entries: Array, current_scene_path: String) -> void:
	level_select.clear()
	var selected_index := 0
	for entry in entries:
		var title := str(entry.get("title", "Unknown level"))
		var scene_path := str(entry.get("scene_path", ""))
		level_select.add_item(title)
		var item_index := level_select.item_count - 1
		level_select.set_item_metadata(item_index, scene_path)
		if scene_path == current_scene_path:
			selected_index = item_index
	level_select.select(selected_index)


func select_current_scene(scene_path: String) -> void:
	for index in level_select.item_count:
		if str(level_select.get_item_metadata(index)) == scene_path:
			level_select.select(index)
			return


func set_diagnostics(text: String) -> void:
	diagnostics_label.text = text


func set_notice(text: String, is_warning := false) -> void:
	notice_label.text = text
	notice_label.modulate = Color(1.0, 0.62, 0.42) if is_warning else Color(0.62, 0.86, 0.72)


func set_invulnerable(enabled: bool) -> void:
	invulnerable_toggle.set_pressed_no_signal(enabled)


func set_noclip(enabled: bool) -> void:
	noclip_toggle.set_pressed_no_signal(enabled)


func set_monsters_paused(paused: bool) -> void:
	pause_monsters_toggle.set_pressed_no_signal(paused)


func set_speed(multiplier: float) -> void:
	for index in speed_select.item_count:
		if is_equal_approx(float(speed_select.get_item_metadata(index)), multiplier):
			speed_select.select(index)
			return


func _build_interface() -> void:
	custom_minimum_size = Vector2(350.0, 0.0)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.045, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.16, 0.72, 0.82, 0.9)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.shadow_size = 8
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_box.add_child(header)

	var title := Label.new()
	title.text = "QA TEST MODE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.42, 0.92, 1.0))
	title.add_theme_font_size_override("font_size", 17)
	header.add_child(title)

	var hotkey := Label.new()
	hotkey.text = "F1"
	hotkey.modulate = Color(0.66, 0.72, 0.76)
	header.add_child(hotkey)

	collapse_button = Button.new()
	collapse_button.text = "−"
	collapse_button.custom_minimum_size = Vector2(34, 30)
	collapse_button.tooltip_text = "Collapse the QA menu"
	collapse_button.pressed.connect(toggle_panel)
	header.add_child(collapse_button)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	root_box.add_child(body)

	var mode_note := Label.new()
	mode_note.text = "Enabled by default • gameplay commands are offline-only"
	mode_note.modulate = Color(0.72, 0.76, 0.78)
	mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(mode_note)

	level_select = OptionButton.new()
	level_select.tooltip_text = "Choose any campaign room or environment study"
	body.add_child(level_select)

	var load_button := Button.new()
	load_button.text = "LOAD SELECTED LEVEL"
	load_button.pressed.connect(_emit_selected_level)
	body.add_child(load_button)

	var toggles := GridContainer.new()
	toggles.columns = 2
	toggles.add_theme_constant_override("h_separation", 10)
	toggles.add_theme_constant_override("v_separation", 4)
	body.add_child(toggles)

	invulnerable_toggle = CheckButton.new()
	invulnerable_toggle.text = "Invulnerable"
	invulnerable_toggle.button_pressed = true
	invulnerable_toggle.toggled.connect(invulnerable_changed.emit)
	toggles.add_child(invulnerable_toggle)

	noclip_toggle = CheckButton.new()
	noclip_toggle.text = "Fly / No-clip"
	noclip_toggle.tooltip_text = "WASD move, Space up, Ctrl down"
	noclip_toggle.toggled.connect(noclip_changed.emit)
	toggles.add_child(noclip_toggle)

	pause_monsters_toggle = CheckButton.new()
	pause_monsters_toggle.text = "Pause monsters"
	pause_monsters_toggle.toggled.connect(monsters_paused_changed.emit)
	toggles.add_child(pause_monsters_toggle)

	var speed_row := HBoxContainer.new()
	var speed_label := Label.new()
	speed_label.text = "Speed"
	speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_row.add_child(speed_label)
	speed_select = OptionButton.new()
	for multiplier in [1.0, 2.0, 5.0]:
		speed_select.add_item("×%s" % int(multiplier))
		speed_select.set_item_metadata(speed_select.item_count - 1, multiplier)
	speed_select.item_selected.connect(_on_speed_selected)
	speed_row.add_child(speed_select)
	toggles.add_child(speed_row)

	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	body.add_child(actions)
	_add_action_button(actions, "Reload level", reload_requested.emit)
	_add_action_button(actions, "Teleport: spawn", teleport_spawn_requested.emit)
	_add_action_button(actions, "Teleport: exit", teleport_exit_requested.emit)
	_add_action_button(actions, "Open exit", open_exit_requested.emit)
	_add_action_button(actions, "Complete objectives", complete_objectives_requested.emit, 2)

	var separator := HSeparator.new()
	body.add_child(separator)

	diagnostics_label = Label.new()
	diagnostics_label.text = "Scene: waiting\nPlayer: not spawned"
	diagnostics_label.modulate = Color(0.78, 0.84, 0.86)
	diagnostics_label.add_theme_font_size_override("font_size", 12)
	diagnostics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(diagnostics_label)

	notice_label = Label.new()
	notice_label.text = "Close with F1 to return camera control."
	notice_label.modulate = Color(0.62, 0.86, 0.72)
	notice_label.add_theme_font_size_override("font_size", 12)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(notice_label)


func _add_action_button(parent: GridContainer, text: String, callback: Callable, column_span := 1) -> void:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	if column_span > 1:
		button.set_meta("qa_column_span", column_span)
	parent.add_child(button)
	if column_span > 1:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2.ZERO
		parent.add_child(spacer)


func _emit_selected_level() -> void:
	if level_select.item_count <= 0:
		return
	level_requested.emit(str(level_select.get_item_metadata(level_select.selected)))


func _on_speed_selected(index: int) -> void:
	speed_changed.emit(float(speed_select.get_item_metadata(index)))


func _apply_expanded_state(emit_change: bool) -> void:
	body.visible = expanded
	collapse_button.text = "−" if expanded else "+"
	collapse_button.tooltip_text = "Collapse the QA menu" if expanded else "Expand the QA menu"
	custom_minimum_size.x = 350.0 if expanded else 220.0
	reset_size()
	if emit_change:
		panel_open_changed.emit(expanded)
