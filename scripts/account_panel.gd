class_name AccountPanel
extends Control

const ACCOUNT_SERVICE_SCRIPT := preload("res://scripts/account_service.gd")

@export var refresh_on_open := true

@onready var loading_label: Label = $AccountCard/Margin/Box/Header/LoadingLabel
@onready var signed_out_row: HBoxContainer = $AccountCard/Margin/Box/SignedOutRow
@onready var sign_in_button: Button = $AccountCard/Margin/Box/SignedOutRow/SignInButton
@onready var signed_in_box: VBoxContainer = $AccountCard/Margin/Box/SignedInBox
@onready var display_name_label: Label = $AccountCard/Margin/Box/SignedInBox/IdentityRow/DisplayName
@onready var profile_button: Button = $AccountCard/Margin/Box/SignedInBox/IdentityRow/ProfileButton
@onready var friends_button: Button = $AccountCard/Margin/Box/SignedInBox/IdentityRow/FriendsButton
@onready var sign_out_button: Button = $AccountCard/Margin/Box/SignedInBox/IdentityRow/SignOutButton
@onready var privacy_button: LinkButton = $AccountCard/Margin/Box/LegalRow/PrivacyButton
@onready var terms_button: LinkButton = $AccountCard/Margin/Box/LegalRow/TermsButton
@onready var card_feedback: Label = $AccountCard/Margin/Box/CardFeedback

@onready var modal_dim: ColorRect = $ModalDim
@onready var details_modal: PanelContainer = $DetailsModal
@onready var details_title: Label = $DetailsModal/Margin/Box/Header/Title
@onready var close_button: Button = $DetailsModal/Margin/Box/Header/CloseButton
@onready var feedback_label: Label = $DetailsModal/Margin/Box/FeedbackLabel
@onready var tabs: TabContainer = $DetailsModal/Margin/Box/Tabs

@onready var profile_name: Label = $DetailsModal/Margin/Box/Tabs/Profile/ProfileName
@onready var friend_code_label: Label = $DetailsModal/Margin/Box/Tabs/Profile/FriendCode
@onready var playtime_label: Label = $DetailsModal/Margin/Box/Tabs/Profile/Playtime
@onready var deaths_label: Label = $DetailsModal/Margin/Box/Tabs/Profile/Deaths
@onready var achievements_list: VBoxContainer = $DetailsModal/Margin/Box/Tabs/Profile/AchievementsScroll/AchievementsList
@onready var achievements_empty: Label = $DetailsModal/Margin/Box/Tabs/Profile/AchievementsEmpty

@onready var friend_code_edit: LineEdit = $DetailsModal/Margin/Box/Tabs/Friends/AddRow/FriendCodeEdit
@onready var add_friend_button: Button = $DetailsModal/Margin/Box/Tabs/Friends/AddRow/AddButton
@onready var requests_list: VBoxContainer = $DetailsModal/Margin/Box/Tabs/Friends/RequestsScroll/RequestsList
@onready var requests_empty: Label = $DetailsModal/Margin/Box/Tabs/Friends/RequestsEmpty
@onready var friends_list: VBoxContainer = $DetailsModal/Margin/Box/Tabs/Friends/FriendsScroll/FriendsList
@onready var friends_empty: Label = $DetailsModal/Margin/Box/Tabs/Friends/FriendsEmpty
@onready var refresh_friends_button: Button = $DetailsModal/Margin/Box/Tabs/Friends/RefreshButton

var _account_service: ACCOUNT_SERVICE_SCRIPT


func _ready() -> void:
	sign_in_button.pressed.connect(_on_sign_in_pressed)
	profile_button.pressed.connect(_on_profile_pressed)
	friends_button.pressed.connect(_on_friends_pressed)
	sign_out_button.pressed.connect(_on_sign_out_pressed)
	privacy_button.pressed.connect(_open_public_page.bind("/privacy"))
	terms_button.pressed.connect(_open_public_page.bind("/terms"))
	close_button.pressed.connect(hide_details)
	add_friend_button.pressed.connect(_on_add_friend_pressed)
	friend_code_edit.text_submitted.connect(func(_text: String) -> void: _on_add_friend_pressed())
	refresh_friends_button.pressed.connect(_refresh_friend_data)
	details_modal.hide()
	modal_dim.hide()
	if _account_service == null:
		_account_service = get_node_or_null("/root/AccountService") as ACCOUNT_SERVICE_SCRIPT
	_connect_account_service()
	_render_all()


func set_account_service(service: ACCOUNT_SERVICE_SCRIPT) -> void:
	_account_service = service
	if is_node_ready():
		_connect_account_service()
		_render_all()


func is_modal_visible() -> bool:
	return details_modal.visible


func show_profile() -> void:
	if not _has_authenticated_service():
		return
	details_title.text = "Account Profile"
	tabs.current_tab = 0
	modal_dim.show()
	details_modal.show()
	if refresh_on_open:
		_account_service.refresh_me()
		_account_service.refresh_progress()


func show_friends() -> void:
	if not _has_authenticated_service():
		return
	details_title.text = "Friends"
	tabs.current_tab = 1
	modal_dim.show()
	details_modal.show()
	if refresh_on_open:
		_refresh_friend_data()


func hide_details() -> void:
	details_modal.hide()
	modal_dim.hide()


func _connect_account_service() -> void:
	if _account_service == null:
		return
	_connect_once(_account_service.auth_state_changed, _on_auth_state_changed)
	_connect_once(_account_service.profile_changed, _on_profile_changed)
	_connect_once(_account_service.progress_changed, _on_progress_changed)
	_connect_once(_account_service.friends_changed, _on_friends_changed)
	_connect_once(_account_service.friend_requests_changed, _on_friend_requests_changed)
	_connect_once(_account_service.loading_changed, _on_loading_changed)
	_connect_once(_account_service.error_changed, _on_feedback_changed)
	_connect_once(_account_service.message_changed, _on_feedback_changed)


func _connect_once(source_signal: Signal, callable: Callable) -> void:
	if not source_signal.is_connected(callable):
		source_signal.connect(callable)


func _render_all() -> void:
	var authenticated: bool = _account_service != null and _account_service.is_authenticated()
	var loading: bool = _account_service != null and _account_service.is_loading()
	signed_out_row.visible = not authenticated
	signed_in_box.visible = authenticated
	loading_label.visible = loading
	sign_in_button.disabled = loading
	profile_button.disabled = loading
	friends_button.disabled = loading
	sign_out_button.disabled = loading
	add_friend_button.disabled = loading
	refresh_friends_button.disabled = loading
	if not authenticated and is_modal_visible():
		hide_details()
	_render_profile()
	_render_friends()
	_render_friend_requests()
	_render_feedback()


func _render_profile() -> void:
	var profile: Dictionary = _account_service.get_profile() if _account_service else {}
	var progress: Dictionary = _account_service.get_progress() if _account_service else {}
	var name := _display_name(profile)
	display_name_label.text = name
	profile_name.text = "Player: %s" % name
	var friend_code := _friend_code(profile)
	friend_code_label.text = "Friend code: %s" % (friend_code if not friend_code.is_empty() else "Not assigned")

	var stats: Dictionary = progress.get("stats", progress) if progress is Dictionary else {}
	var verified_hours := _verified_hours(stats)
	playtime_label.text = "Verified playtime: %.1f hours" % verified_hours
	var deaths := int(stats.get("deaths", stats.get("death_count", progress.get("deaths", 0))))
	deaths_label.text = "Deaths: %s" % deaths

	_clear_rows(achievements_list)
	var raw_achievements: Variant = progress.get(
		"achievements",
		progress.get("unlocked_achievements", stats.get("achievements", []))
	)
	var achievements: Array = raw_achievements if raw_achievements is Array else []
	achievements_empty.visible = achievements.is_empty()
	for achievement in achievements:
		achievements_list.add_child(_create_achievement_row(achievement))


func _render_friends() -> void:
	_clear_rows(friends_list)
	var entries: Array = _account_service.get_friends() if _account_service else []
	friends_empty.visible = entries.is_empty()
	for entry in entries:
		if not entry is Dictionary:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var identity := Label.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.text = _identity_text(entry)
		row.add_child(identity)
		var remove_button := Button.new()
		var code := _friend_code(entry)
		remove_button.text = "Remove"
		remove_button.disabled = code.is_empty()
		remove_button.pressed.connect(_on_remove_friend.bind(code))
		row.add_child(remove_button)
		friends_list.add_child(row)


func _render_friend_requests() -> void:
	_clear_rows(requests_list)
	var entries: Array = _account_service.get_friend_requests() if _account_service else []
	requests_empty.visible = entries.is_empty()
	for entry in entries:
		if not entry is Dictionary:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var identity := Label.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.text = _identity_text(entry)
		row.add_child(identity)
		var code := _friend_code(entry)
		var accept_button := Button.new()
		accept_button.text = "Accept"
		accept_button.disabled = code.is_empty()
		accept_button.pressed.connect(_on_accept_request.bind(code))
		row.add_child(accept_button)
		var decline_button := Button.new()
		decline_button.text = "Decline"
		decline_button.disabled = code.is_empty()
		decline_button.pressed.connect(_on_decline_request.bind(code))
		row.add_child(decline_button)
		requests_list.add_child(row)


func _render_feedback() -> void:
	var error: String = _account_service.get_last_error() if _account_service else "Account service unavailable."
	var message: String = _account_service.get_last_message() if _account_service else ""
	var text: String = error if not error.is_empty() else message
	card_feedback.text = text
	feedback_label.text = text
	var color := Color(0.96, 0.42, 0.36) if not error.is_empty() else Color(0.72, 0.78, 0.68)
	card_feedback.add_theme_color_override("font_color", color)
	feedback_label.add_theme_color_override("font_color", color)


func _create_achievement_row(value: Variant) -> Control:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if value is Dictionary:
		var entry: Dictionary = value
		var unlocked := bool(entry.get("unlocked", true))
		var title := str(entry.get("title", entry.get("name", entry.get("achievement_id", entry.get("id", "Achievement")))))
		var description := str(entry.get("description", ""))
		label.text = "%s %s%s" % [
			"[Unlocked]" if unlocked else "[Locked]",
			title,
			" - %s" % description if not description.is_empty() else "",
		]
	else:
		label.text = "[Unlocked] %s" % str(value)
	return label


func _verified_hours(stats: Dictionary) -> float:
	if stats.has("verified_hours"):
		return maxf(float(stats["verified_hours"]), 0.0)
	var seconds := float(stats.get(
		"verified_playtime_seconds",
		stats.get(
			"verified_play_seconds",
			stats.get("play_seconds", stats.get("total_play_seconds", 0.0))
		)
	))
	return maxf(seconds, 0.0) / 3600.0


func _display_name(value: Dictionary) -> String:
	for key in ["display_name", "name", "username"]:
		var candidate := str(value.get(key, "")).strip_edges()
		if not candidate.is_empty():
			return candidate
	for nested_key in ["profile", "user", "account", "sender", "requester"]:
		if value.get(nested_key) is Dictionary:
			var nested_name := _display_name(value[nested_key])
			if nested_name != "Player":
				return nested_name
	return "Player"


func _friend_code(value: Dictionary) -> String:
	for key in ["friend_code", "sender_friend_code", "requester_friend_code"]:
		var candidate := str(value.get(key, "")).strip_edges()
		if not candidate.is_empty():
			return candidate
	for nested_key in ["profile", "user", "account", "sender", "requester", "friend"]:
		if value.get(nested_key) is Dictionary:
			var nested_code := _friend_code(value[nested_key])
			if not nested_code.is_empty():
				return nested_code
	return ""


func _identity_text(value: Dictionary) -> String:
	var name := _display_name(value)
	var code := _friend_code(value)
	return name if code.is_empty() else "%s  |  %s" % [name, code]


func _clear_rows(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _has_authenticated_service() -> bool:
	if _account_service != null and _account_service.is_authenticated():
		return true
	if _account_service:
		card_feedback.text = "Sign in with Google to use account features."
		feedback_label.text = card_feedback.text
	return false


func _refresh_friend_data() -> void:
	if not _has_authenticated_service():
		return
	_account_service.refresh_friends()
	_account_service.refresh_friend_requests()


func _on_sign_in_pressed() -> void:
	if _account_service:
		_account_service.start_google_sign_in()


func _on_sign_out_pressed() -> void:
	if _account_service:
		_account_service.sign_out()


func _on_profile_pressed() -> void:
	show_profile()


func _on_friends_pressed() -> void:
	show_friends()


func _on_add_friend_pressed() -> void:
	if not _has_authenticated_service():
		return
	var code := friend_code_edit.text.strip_edges()
	if code.is_empty():
		friend_code_edit.grab_focus()
		return
	friend_code_edit.clear()
	_account_service.send_friend_request(code)


func _on_accept_request(friend_code: String) -> void:
	if _account_service:
		_account_service.accept_friend_request(friend_code)


func _on_decline_request(friend_code: String) -> void:
	if _account_service:
		_account_service.decline_friend_request(friend_code)


func _on_remove_friend(friend_code: String) -> void:
	if _account_service:
		_account_service.remove_friend(friend_code)


func _open_public_page(path: String) -> void:
	var public_base_url := "https://creepy-pasta.duckdns.org"
	if _account_service:
		public_base_url = _account_service.get_api_base_url().trim_suffix("/api/v1")
	OS.shell_open("%s%s" % [public_base_url.trim_suffix("/"), path])


func _on_auth_state_changed(_authenticated: bool) -> void:
	_render_all()


func _on_profile_changed(_profile: Dictionary) -> void:
	_render_profile()


func _on_progress_changed(_progress: Dictionary) -> void:
	_render_profile()


func _on_friends_changed(_friends: Array) -> void:
	_render_friends()


func _on_friend_requests_changed(_requests: Array) -> void:
	_render_friend_requests()


func _on_loading_changed(_loading: bool) -> void:
	_render_all()


func _on_feedback_changed(_message: String) -> void:
	_render_feedback()
