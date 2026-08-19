class_name AccountGameBridge
extends Node

const DEFAULT_INTERNAL_BASE_URL := "http://127.0.0.1:8080"
const REQUEST_TIMEOUT_SECONDS := 8.0
const MAX_IN_FLIGHT_REQUESTS := 16
const MAX_SESSION_QUEUE_SIZE := 256
const RETRY_WINDOW_MSEC := 5 * 60 * 1000
const RETRY_MAX_DELAY_SECONDS := 8.0

var internal_base_url := DEFAULT_INTERNAL_BASE_URL
var internal_secret := ""
var _in_flight_requests := 0
var _session_queues := {}
var _session_draining := {}
var _session_terminal_queued := {}
var _disable_queue_drain_for_tests := false


func _ready() -> void:
	var configured_url := OS.get_environment("CREEPY_ACCOUNT_INTERNAL_BASE_URL").strip_edges()
	if configured_url != "":
		internal_base_url = configured_url.trim_suffix("/")
	internal_secret = OS.get_environment("CREEPY_ACCOUNT_INTERNAL_SECRET")
	if internal_secret == "":
		# Compatibility with the first deployment draft. New installs use the
		# CREEPY_ACCOUNT_* name above.
		internal_secret = OS.get_environment("CREEPY_PASTA_INTERNAL_SECRET")


func is_configured() -> bool:
	return internal_secret.length() >= 32


func queued_operation_snapshot(play_session_id: String) -> Array:
	return (_session_queues.get(play_session_id, []) as Array).duplicate(true)


func clear_queued_operations_for_tests() -> void:
	_session_queues.clear()
	_session_draining.clear()
	_session_terminal_queued.clear()


func disable_queue_drain_for_tests() -> void:
	_disable_queue_drain_for_tests = true


func redeem_game_ticket(ticket: String) -> Dictionary:
	return await _request_json(
		"/internal/v1/game-tickets/redeem",
		HTTPClient.METHOD_POST,
		{"ticket": ticket}
	)


func heartbeat_play_session(play_session_id: String, active: bool) -> Dictionary:
	return await _request_json(
		"/internal/v1/play-sessions/%s/heartbeat" % play_session_id.uri_encode(),
		HTTPClient.METHOD_POST,
		{"active": active}
	)


func record_play_event(
	play_session_id: String,
	event_id: String,
	event_type: String,
	achievement_code := ""
) -> Dictionary:
	var payload := {
		"event_id": event_id,
		"type": event_type,
	}
	if achievement_code != "":
		payload["achievement_code"] = achievement_code
	return await _request_json(
		"/internal/v1/play-sessions/%s/events" % play_session_id.uri_encode(),
		HTTPClient.METHOD_POST,
		payload
	)


func end_play_session(play_session_id: String) -> Dictionary:
	return await _request_json(
		"/internal/v1/play-sessions/%s/end" % play_session_id.uri_encode(),
		HTTPClient.METHOD_POST,
		{}
	)


func enqueue_heartbeat(play_session_id: String, active: bool) -> void:
	if play_session_id == "" or _session_terminal_queued.has(play_session_id):
		return
	var queue: Array = _session_queues.get(play_session_id, [])
	if not queue.is_empty():
		var operation: Dictionary = queue.back()
		if (
			str(operation.get("kind", "")) == "heartbeat"
			and bool(operation.get("active", false)) == active
		):
			return
	_enqueue_session_operation(play_session_id, {
		"kind": "heartbeat",
		"active": active,
		"first_attempt_msec": 0,
	})


func enqueue_event(
	play_session_id: String,
	event_id: String,
	event_type: String,
	achievement_code := ""
) -> void:
	if play_session_id == "" or event_id == "" or _session_terminal_queued.has(play_session_id):
		return
	_enqueue_session_operation(play_session_id, {
		"kind": "event",
		"event_id": event_id,
		"event_type": event_type,
		"achievement_code": achievement_code,
		"first_attempt_msec": 0,
	})


func enqueue_end(play_session_id: String) -> void:
	if play_session_id == "" or _session_terminal_queued.has(play_session_id):
		return
	_session_terminal_queued[play_session_id] = true
	_enqueue_session_operation(play_session_id, {
		"kind": "end",
		"first_attempt_msec": 0,
	})


func _enqueue_session_operation(play_session_id: String, operation: Dictionary) -> void:
	var queue: Array = _session_queues.get(play_session_id, [])
	if queue.size() >= MAX_SESSION_QUEUE_SIZE and str(operation.get("kind", "")) != "end":
		push_error("Account bridge queue is full for a play session.")
		return
	queue.append(operation)
	_session_queues[play_session_id] = queue
	if _disable_queue_drain_for_tests:
		return
	if _session_draining.has(play_session_id):
		return
	_session_draining[play_session_id] = true
	_drain_session_queue(play_session_id)


func _drain_session_queue(play_session_id: String) -> void:
	while true:
		var queue: Array = _session_queues.get(play_session_id, [])
		if queue.is_empty():
			_session_queues.erase(play_session_id)
			_session_draining.erase(play_session_id)
			_session_terminal_queued.erase(play_session_id)
			return
		var operation: Dictionary = queue[0]
		if int(operation.get("first_attempt_msec", 0)) <= 0:
			operation["first_attempt_msec"] = Time.get_ticks_msec()
		var result := await _send_session_operation(play_session_id, operation)
		if bool(result.get("ok", false)):
			queue.pop_front()
			_session_queues[play_session_id] = queue
			continue
		var status := int(result.get("status", 0))
		var retryable := status == 0 or status == 408 or status == 429 or status >= 500
		var retry_age_msec := Time.get_ticks_msec() - int(operation["first_attempt_msec"])
		if retryable and retry_age_msec < RETRY_WINDOW_MSEC:
			var attempts := int(operation.get("attempts", 0)) + 1
			operation["attempts"] = attempts
			var delay := minf(pow(2.0, minf(float(attempts - 1), 4.0)) * 0.5, RETRY_MAX_DELAY_SECONDS)
			delay += randf_range(0.0, 0.25)
			await get_tree().create_timer(delay).timeout
			continue
		push_warning(
			"Account bridge dropped %s for a play session after status %s."
			% [str(operation.get("kind", "operation")), status]
		)
		queue.pop_front()
		_session_queues[play_session_id] = queue


func _send_session_operation(play_session_id: String, operation: Dictionary) -> Dictionary:
	match str(operation.get("kind", "")):
		"heartbeat":
			return await heartbeat_play_session(
				play_session_id,
				bool(operation.get("active", false))
			)
		"event":
			return await record_play_event(
				play_session_id,
				str(operation.get("event_id", "")),
				str(operation.get("event_type", "")),
				str(operation.get("achievement_code", ""))
			)
		"end":
			return await end_play_session(play_session_id)
	return {"ok": false, "status": 400, "error": "Unknown account bridge operation."}


func _request_json(path: String, method: HTTPClient.Method, payload: Dictionary) -> Dictionary:
	if not is_configured():
		return {"ok": false, "status": 0, "error": "Account bridge is not configured."}
	if _in_flight_requests >= MAX_IN_FLIGHT_REQUESTS:
		return {"ok": false, "status": 0, "error": "Account bridge is busy."}

	var http_request := HTTPRequest.new()
	http_request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(http_request)
	_in_flight_requests += 1
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"X-Internal-Secret: %s" % internal_secret,
	])
	var request_error := http_request.request(
		"%s%s" % [internal_base_url, path],
		headers,
		method,
		JSON.stringify(payload)
	)
	if request_error != OK:
		_in_flight_requests = maxi(_in_flight_requests - 1, 0)
		http_request.queue_free()
		return {
			"ok": false,
			"status": 0,
			"error": "Account API request could not start (%s)." % request_error,
		}

	var response: Array = await http_request.request_completed
	_in_flight_requests = maxi(_in_flight_requests - 1, 0)
	http_request.queue_free()
	if response.size() < 4:
		return {"ok": false, "status": 0, "error": "Account API returned an invalid response."}
	var transport_result := int(response[0])
	var status := int(response[1])
	var body: PackedByteArray = response[3]
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"status": status,
			"error": "Account API transport failed (%s)." % transport_result,
		}

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	data["ok"] = status >= 200 and status < 300
	data["status"] = status
	if not bool(data["ok"]) and not data.has("error"):
		data["error"] = "Account API rejected the request (%s)." % status
	return data
