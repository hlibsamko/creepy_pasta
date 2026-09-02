extends Node

const PHYSICAL_ACTIONS: Array[String] = [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"sprint",
	"jump",
	"interact",
	"dialogue_next",
	"journal",
]


func _ready() -> void:
	for action in PHYSICAL_ACTIONS:
		if not InputMap.has_action(action):
			_fail("Missing input action: %s" % action)
			return

		var has_physical_key := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key_event := event as InputEventKey
				if key_event.physical_keycode == 0:
					_fail("Input action %s has a layout-dependent key event" % action)
					return
				if key_event.keycode != 0:
					_fail("Input action %s keeps a keycode alongside physical_keycode" % action)
					return
				has_physical_key = true

		if not has_physical_key:
			_fail("Input action %s has no physical key event" % action)
			return

	print("[smoke] Physical input bindings OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
