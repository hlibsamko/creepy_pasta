class_name AccountServiceClient
extends Node

signal auth_state_changed(is_authenticated: bool)
signal profile_changed(profile: Dictionary)
signal progress_changed(progress: Dictionary)
signal friends_changed(friends: Array)
signal friend_requests_changed(requests: Array)
signal loading_changed(is_loading: bool)
signal error_changed(message: String)
signal message_changed(message: String)
signal game_ticket_received(ticket: String)
signal token_refresh_completed(ok: bool)

const DEFAULT_API_BASE_URL := "https://creepy-pasta.duckdns.org/api/v1"
const API_BASE_URL_ENV := "CREEPY_PASTA_API_BASE_URL"
const REQUEST_TIMEOUT_SECONDS := 15.0
const AUTH_POLL_INTERVAL_SECONDS := 1.0
const AUTH_POLL_TIMEOUT_SECONDS := 180.0
const MAX_TRANSIENT_POLL_ERRORS := 3

var _api_base_url := ""
var _access_token := ""
var _refresh_token := ""
var _access_expires_at_msec := 0
var _refresh_in_progress := false
var _credential_generation := 0
var _profile := {}
var _progress := {}
var _friends: Array = []
var _friend_requests: Array = []
var _active_request_count := 0
var _auth_polling := false
var _auth_generation := 0
var _auth_login_id := ""
var _auth_poll_token := ""
var _auth_expires_at_msec := 0
var _browser_auth_window
var _last_error := ""
var _last_message := ""
var _last_loading_state := false


func _ready() -> void:
	_api_base_url = _resolve_api_base_url()


func is_authenticated() -> bool:
	return not _access_token.is_empty()


func is_loading() -> bool:
	return _active_request_count > 0 or _auth_polling


func get_profile() -> Dictionary:
	return _profile.duplicate(true)


func get_progress() -> Dictionary:
	return _progress.duplicate(true)


func get_friends() -> Array:
	return _friends.duplicate(true)


func get_friend_requests() -> Array:
	return _friend_requests.duplicate(true)


func get_last_error() -> String:
	return _last_error


func get_last_message() -> String:
	return _last_message


func get_api_base_url() -> String:
	return _api_base_url


func set_api_base_url_for_tests(value: String) -> void:
	_api_base_url = value.strip_edges().trim_suffix("/")


func start_google_sign_in() -> void:
	if is_authenticated():
		_set_message("You are already signed in.")
		return
	if _auth_polling:
		_set_message("Google sign-in is already waiting for approval.")
		return

	_set_error("")
	_set_message("Starting Google sign-in...")
	if not _prepare_browser_auth_window():
		_set_error("The browser blocked the Google sign-in window. Allow popups and try again.")
		return
	_auth_generation += 1
	var generation := _auth_generation
	_set_auth_polling(true)
	var response := await _request_json("/auth/google/start", HTTPClient.METHOD_POST, {})
	if generation != _auth_generation:
		return
	if not bool(response.get("ok", false)):
		_fail_auth_attempt(_response_error(response, "Could not start Google sign-in."))
		return

	var payload := _response_payload(response)
	_auth_login_id = str(payload.get("login_id", ""))
	_auth_poll_token = str(payload.get("poll_token", ""))
	var authorization_url := str(payload.get("authorization_url", ""))
	var expires_in := clampf(float(payload.get("expires_in", AUTH_POLL_TIMEOUT_SECONDS)), 10.0, 600.0)
	_auth_expires_at_msec = Time.get_ticks_msec() + roundi(expires_in * 1000.0)
	if _auth_login_id.is_empty() or _auth_poll_token.is_empty() or authorization_url.is_empty():
		_fail_auth_attempt("The authentication server returned an incomplete sign-in attempt.")
		return
	if not authorization_url.begins_with("https://") and not authorization_url.begins_with("http://"):
		_fail_auth_attempt("The authentication server returned an invalid authorization URL.")
		return

	if not _open_authorization_url(authorization_url):
		_fail_auth_attempt("The Google sign-in window was closed before it could open Google.")
		return
	_set_message("Finish signing in with Google in the browser window.")
	await _poll_google_sign_in(generation)


func cancel_google_sign_in() -> void:
	if not _auth_polling:
		return
	_cancel_auth_attempt()
	_set_message("Google sign-in cancelled.")


func sign_out() -> void:
	_cancel_auth_attempt()
	var logout_response := {}
	if is_authenticated():
		if await _ensure_valid_access_token():
			logout_response = await _request_json("/auth/logout", HTTPClient.METHOD_POST, {})
	_clear_authenticated_state()
	if not logout_response.is_empty() and not bool(logout_response.get("ok", false)):
		_set_error(_response_error(logout_response, "Signed out locally, but the server could not be reached."))
		return
	_set_error("")
	_set_message("Signed out.")


func refresh_account_data() -> void:
	if not _require_authentication():
		return
	_set_error("")
	if not await refresh_me():
		return
	await refresh_progress()
	if not is_authenticated():
		return
	await refresh_friends()
	if not is_authenticated():
		return
	await refresh_friend_requests()


func refresh_me() -> bool:
	if not _require_authentication():
		return false
	if not await _ensure_valid_access_token():
		return false
	var response := await _request_json("/me")
	if not bool(response.get("ok", false)):
		_handle_authenticated_failure(response, "Could not load the account profile.")
		return false
	var payload := _response_payload(response)
	var raw_profile: Variant = payload.get("profile", payload.get("user", payload))
	_profile = _safe_profile(raw_profile)
	profile_changed.emit(get_profile())
	return true


func refresh_progress() -> bool:
	if not _require_authentication():
		return false
	if not await _ensure_valid_access_token():
		return false
	var response := await _request_json("/me/progress")
	if not bool(response.get("ok", false)):
		_handle_authenticated_failure(response, "Could not load account progress.")
		return false
	var payload := _response_payload(response)
	var raw_progress: Variant = payload.get("progress", payload)
	_progress = raw_progress.duplicate(true) if raw_progress is Dictionary else {}
	progress_changed.emit(get_progress())
	return true


func refresh_friends() -> bool:
	if not _require_authentication():
		return false
	if not await _ensure_valid_access_token():
		return false
	var response := await _request_json("/friends")
	if not bool(response.get("ok", false)):
		_handle_authenticated_failure(response, "Could not load the friends list.")
		return false
	var payload := _response_payload(response)
	var raw_friends: Variant = payload.get("friends", [])
	_friends = raw_friends.duplicate(true) if raw_friends is Array else []
	friends_changed.emit(get_friends())
	return true


func refresh_friend_requests() -> bool:
	if not _require_authentication():
		return false
	if not await _ensure_valid_access_token():
		return false
	var response := await _request_json("/friend-requests")
	if not bool(response.get("ok", false)):
		_handle_authenticated_failure(response, "Could not load friend requests.")
		return false
	var payload := _response_payload(response)
	var raw_requests: Variant = payload.get(
		"incoming",
		payload.get("friend_requests", payload.get("requests", []))
	)
	_friend_requests = raw_requests.duplicate(true) if raw_requests is Array else []
	friend_requests_changed.emit(get_friend_requests())
	return true


func send_friend_request(friend_code: String) -> bool:
	if not _require_authentication():
		return false
	if not await _ensure_valid_access_token():
		return false
	var clean_code := friend_code.strip_edges()
	if clean_code.is_empty():
		_set_error("Enter a friend code first.")
		return false
	_set_error("")
	var response := await _request_json(
		"/friend-requests",
		HTTPClient.METHOD_POST,
		{"friend_code": clean_code}
	)
	if not bool(response.get("ok", false)):
		_handle_authenticated_failure(response, "Could not send the friend request.")
		return false
	_set_message("Friend request sent.")
	await refresh_friend_requests()
	return true


func accept_friend_request(friend_code: String) -> bool:
	return await _resolve_friend_request(friend_code, "accept", "Friend request accepted.")


func decline_friend_request(friend_code: String) -> bool:
	return await _resolve_friend_request(friend_code, "decline", "Friend request declined.")


func remove_friend(friend_code: String) -> bool:
	if not _require_authentication():
		return false
	if not await _ensure_valid_access_token():
		return false
	if friend_code.strip_edges().is_empty():
		_set_error("That friend entry has no friend code.")
		return false
	_set_error("")
	var response := await _request_json(
		"/friends/%s" % friend_code.uri_encode(),
		HTTPClient.METHOD_DELETE
	)
	if not bool(response.get("ok", false)):
		_handle_authenticated_failure(response, "Could not remove the friend.")
		return false
	_set_message("Friend removed.")
	await refresh_friends()
	return true


func create_game_ticket() -> Dictionary:
	if not _require_authentication():
		return _failed_ticket_result(get_last_error())
	if not await _ensure_valid_access_token():
		return _failed_ticket_result(get_last_error())
	_set_error("")
	var response := await _request_json("/game-tickets", HTTPClient.METHOD_POST, {})
	if not bool(response.get("ok", false)):
		_handle_authenticated_failure(response, "Could not create a game ticket.")
		return _failed_ticket_result(get_last_error())
	var payload := _response_payload(response)
	var ticket := str(payload.get("ticket", payload.get("game_ticket", "")))
	if ticket.is_empty():
		_set_error("The account server returned an empty game ticket.")
		return _failed_ticket_result(get_last_error())
	game_ticket_received.emit(ticket)
	return {
		"ok": true,
		"ticket": ticket,
		"expires_at": payload.get("expires_at"),
		"expires_in": payload.get("expires_in"),
		"error": "",
	}


func _resolve_friend_request(friend_code: String, action: String, success_message: String) -> bool:
	if not _require_authentication():
		return false
	if not await _ensure_valid_access_token():
		return false
	if friend_code.strip_edges().is_empty():
		_set_error("That friend request has no friend code.")
		return false
	_set_error("")
	var response := await _request_json(
		"/friend-requests/%s" % action,
		HTTPClient.METHOD_POST,
		{"friend_code": friend_code}
	)
	if not bool(response.get("ok", false)):
		_handle_authenticated_failure(response, "Could not update the friend request.")
		return false
	_set_message(success_message)
	await refresh_friend_requests()
	if is_authenticated():
		await refresh_friends()
	return true


func _poll_google_sign_in(generation: int) -> void:
	var transient_errors := 0
	while generation == _auth_generation and _auth_polling:
		if Time.get_ticks_msec() >= _auth_expires_at_msec:
			_fail_auth_attempt("Google sign-in timed out. Please try again.")
			return
		await get_tree().create_timer(AUTH_POLL_INTERVAL_SECONDS).timeout
		if generation != _auth_generation or not _auth_polling:
			return
		var response := await _request_json(
			"/auth/google/poll",
			HTTPClient.METHOD_POST,
			{
				"login_id": _auth_login_id,
				"poll_token": _auth_poll_token,
			},
			false
		)
		if generation != _auth_generation or not _auth_polling:
			return
		if not bool(response.get("ok", false)):
			transient_errors += 1
			if transient_errors <= MAX_TRANSIENT_POLL_ERRORS and int(response.get("status_code", 0)) >= 500:
				continue
			_fail_auth_attempt(_response_error(response, "Google sign-in could not be completed."))
			return

		transient_errors = 0
		var payload := _response_payload(response)
		var status := str(payload.get("status", "")).to_lower()
		if status in ["pending", "waiting", "created"]:
			if _is_browser_auth_window_closed():
				_fail_auth_attempt("The Google sign-in window was closed before sign-in completed.")
				return
			continue
		if status in ["denied", "declined", "cancelled", "canceled", "expired", "failed", "error"]:
			_fail_auth_attempt(str(payload.get("message", "Google sign-in was not approved.")))
			return
		var token := str(payload.get("access_token", ""))
		if token.is_empty():
			_fail_auth_attempt("The authentication server completed without an access token.")
			return

		_apply_auth_tokens(payload)
		var raw_profile: Variant = payload.get("profile", payload.get("user", {}))
		_profile = _safe_profile(raw_profile)
		_finish_auth_attempt()
		auth_state_changed.emit(true)
		profile_changed.emit(get_profile())
		_set_error("")
		_set_message("Signed in with Google.")
		await refresh_account_data()
		return


func _request_json(
	path: String,
	method := HTTPClient.METHOD_GET,
	payload: Variant = null,
	include_auth := true
) -> Dictionary:
	_begin_request()
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var headers := PackedStringArray(["Accept: application/json"])
	var body := ""
	if payload != null:
		headers.append("Content-Type: application/json")
		body = JSON.stringify(payload)
	if include_auth and not _access_token.is_empty():
		headers.append("Authorization: Bearer %s" % _access_token)
	var request_error := request.request(_build_url(path), headers, method, body)
	if request_error != OK:
		request.queue_free()
		_end_request()
		return {
			"ok": false,
			"status_code": 0,
			"error": "Could not start the account request (%s)." % error_string(request_error),
			"data": {},
		}

	var response: Array = await request.request_completed
	request.queue_free()
	_end_request()
	if response.size() < 4:
		return {"ok": false, "status_code": 0, "error": "The account server returned no response.", "data": {}}
	var result_code := int(response[0])
	var status_code := int(response[1])
	var response_body: PackedByteArray = response[3]
	var response_text := response_body.get_string_from_utf8()
	var parsed: Variant = {}
	if not response_text.is_empty():
		parsed = JSON.parse_string(response_text)
		if parsed == null:
			return {
				"ok": false,
				"status_code": status_code,
				"error": "The account server returned invalid JSON.",
				"data": {},
			}
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"status_code": status_code,
			"error": "The account request failed (%s)." % result_code,
			"data": parsed,
		}
	var ok := status_code >= 200 and status_code < 300
	return {
		"ok": ok,
		"status_code": status_code,
		"error": "" if ok else _extract_error(parsed, "Account request failed (HTTP %s)." % status_code),
		"data": parsed,
	}


func _resolve_api_base_url() -> String:
	var environment_override := OS.get_environment(API_BASE_URL_ENV).strip_edges()
	if not environment_override.is_empty():
		return environment_override.trim_suffix("/")
	if OS.has_feature("web"):
		var window := JavaScriptBridge.get_interface("window")
		if window:
			var origin := str(window.location.origin).strip_edges()
			if not origin.is_empty() and origin != "null":
				return "%s/api/v1" % origin.trim_suffix("/")
	return DEFAULT_API_BASE_URL


func _build_url(path: String) -> String:
	if path.begins_with("http://") or path.begins_with("https://"):
		return path
	return "%s/%s" % [_api_base_url.trim_suffix("/"), path.trim_prefix("/")]


func _prepare_browser_auth_window() -> bool:
	_browser_auth_window = null
	if not OS.has_feature("web"):
		return true
	var window := JavaScriptBridge.get_interface("window")
	if window:
		_browser_auth_window = window.open(
			"about:blank",
			"creepy_pasta_google_auth",
			"popup=yes,width=520,height=720"
		)
	return _browser_auth_window != null


func _open_authorization_url(authorization_url: String) -> bool:
	if _browser_auth_window and not _is_browser_auth_window_closed():
		_browser_auth_window.location.replace(authorization_url)
		_browser_auth_window.focus()
		return true
	if OS.has_feature("web"):
		return false
	var open_error := OS.shell_open(authorization_url)
	if open_error != OK:
		_set_error("Open this sign-in URL in a browser: %s" % authorization_url)
		return false
	return true


func _close_browser_auth_window() -> void:
	if _browser_auth_window:
		_browser_auth_window.close()
	_browser_auth_window = null


func _finish_auth_attempt() -> void:
	_auth_login_id = ""
	_auth_poll_token = ""
	_auth_expires_at_msec = 0
	_set_auth_polling(false)
	_close_browser_auth_window()


func _fail_auth_attempt(message: String) -> void:
	_auth_generation += 1
	_auth_login_id = ""
	_auth_poll_token = ""
	_auth_expires_at_msec = 0
	_set_auth_polling(false)
	_close_browser_auth_window()
	_set_error(message)


func _cancel_auth_attempt() -> void:
	_auth_generation += 1
	_auth_login_id = ""
	_auth_poll_token = ""
	_auth_expires_at_msec = 0
	_set_auth_polling(false)
	_close_browser_auth_window()


func _safe_profile(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var safe: Dictionary = value.duplicate(true)
	for sensitive_key in ["email", "google_email", "access_token", "refresh_token"]:
		safe.erase(sensitive_key)
	return safe


func _apply_auth_tokens(payload: Dictionary) -> void:
	_access_token = str(payload.get("access_token", ""))
	_refresh_token = str(payload.get("refresh_token", ""))
	var access_expires_in := maxi(int(payload.get("access_expires_in", 0)), 0)
	_access_expires_at_msec = (
		Time.get_ticks_msec() + access_expires_in * 1000
		if access_expires_in > 0
		else 0
	)


func _ensure_valid_access_token() -> bool:
	if _access_token.is_empty():
		return false
	if _access_expires_at_msec <= 0 or Time.get_ticks_msec() < _access_expires_at_msec - 15_000:
		return true
	if _refresh_token.is_empty():
		_clear_authenticated_state()
		_set_error("Your account session expired. Sign in again.")
		return false
	if _refresh_in_progress:
		return bool(await token_refresh_completed)

	_refresh_in_progress = true
	var credential_generation := _credential_generation
	var response := await _request_json(
		"/auth/refresh",
		HTTPClient.METHOD_POST,
		{"refresh_token": _refresh_token},
		false
	)
	if credential_generation != _credential_generation:
		_refresh_in_progress = false
		token_refresh_completed.emit(false)
		return false
	var refreshed := bool(response.get("ok", false))
	if refreshed:
		var payload := _response_payload(response)
		_apply_auth_tokens(payload)
		var raw_profile: Variant = payload.get("profile", payload.get("user", {}))
		if raw_profile is Dictionary:
			_profile = _safe_profile(raw_profile)
			profile_changed.emit(get_profile())
	else:
		_clear_authenticated_state()
		_set_error("Your account session expired. Sign in again.")
	_refresh_in_progress = false
	token_refresh_completed.emit(refreshed)
	return refreshed


func _failed_ticket_result(message: String) -> Dictionary:
	return {
		"ok": false,
		"ticket": "",
		"expires_at": null,
		"expires_in": null,
		"error": message,
	}


func _is_browser_auth_window_closed() -> bool:
	return bool(_browser_auth_window.closed) if _browser_auth_window else false


func _response_payload(response: Dictionary) -> Dictionary:
	var data: Variant = response.get("data", {})
	if not data is Dictionary:
		return {}
	var payload: Dictionary = data
	if payload.get("data") is Dictionary:
		return (payload["data"] as Dictionary).duplicate(true)
	return payload.duplicate(true)


func _response_error(response: Dictionary, fallback: String) -> String:
	var explicit := str(response.get("error", ""))
	if not explicit.is_empty():
		return explicit
	return _extract_error(response.get("data", {}), fallback)


func _extract_error(value: Variant, fallback: String) -> String:
	if value is Dictionary:
		var data: Dictionary = value
		for key in ["message", "detail", "error"]:
			if data.has(key) and not str(data[key]).is_empty():
				return str(data[key])
	return fallback


func _handle_authenticated_failure(response: Dictionary, fallback: String) -> void:
	var status_code := int(response.get("status_code", 0))
	var message := _response_error(response, fallback)
	if status_code == 401 or status_code == 403:
		_clear_authenticated_state()
		message = "Your account session expired. Sign in again."
	_set_error(message)


func _require_authentication() -> bool:
	if is_authenticated():
		return true
	_set_error("Sign in with Google to use account features.")
	return false


func _clear_authenticated_state() -> void:
	var was_authenticated := is_authenticated()
	_credential_generation += 1
	_access_token = ""
	_refresh_token = ""
	_access_expires_at_msec = 0
	_profile.clear()
	_progress.clear()
	_friends.clear()
	_friend_requests.clear()
	if was_authenticated:
		auth_state_changed.emit(false)
	profile_changed.emit({})
	progress_changed.emit({})
	friends_changed.emit([])
	friend_requests_changed.emit([])


func _begin_request() -> void:
	_active_request_count += 1
	_emit_loading_if_changed()


func _end_request() -> void:
	_active_request_count = maxi(_active_request_count - 1, 0)
	_emit_loading_if_changed()


func _set_auth_polling(value: bool) -> void:
	_auth_polling = value
	_emit_loading_if_changed()


func _emit_loading_if_changed() -> void:
	var next_state := is_loading()
	if next_state == _last_loading_state:
		return
	_last_loading_state = next_state
	loading_changed.emit(next_state)


func _set_error(message: String) -> void:
	if message == _last_error:
		return
	_last_error = message
	error_changed.emit(message)


func _set_message(message: String) -> void:
	if message == _last_message:
		return
	_last_message = message
	message_changed.emit(message)
