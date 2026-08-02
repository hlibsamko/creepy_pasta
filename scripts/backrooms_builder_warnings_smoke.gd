extends Node

var builder: BackroomsBuilder


func _ready() -> void:
	builder = BackroomsBuilder.new()

	builder.layout = "#####\n#SRE#\n#.UT#\n#####"
	var warnings: PackedStringArray = builder.call("_get_configuration_warnings")
	if not warnings.is_empty():
		_fail("Valid R/U/T builder layout reported warnings: %s" % " | ".join(warnings))
		return

	builder.layout = "#####\n#STX#\n####"
	warnings = builder.call("_get_configuration_warnings")
	if (
		not _has_warning(warnings, "row 3")
		or not _has_warning(warnings, "unsupported symbols")
		or not _has_warning(warnings, "no E exit")
		or not _has_warning(warnings, "require at least one R")
	):
		_fail("Builder warnings did not explain malformed rows, symbols, exit, and breaker wiring")
		return

	builder.layout = "#########\n#SURU.E.#\n#########"
	warnings = builder.call("_get_configuration_warnings")
	if not _has_warning(warnings, "equally close to multiple U"):
		_fail("Builder did not warn about an ambiguous R-to-U nearest binding")
		return

	builder.layout = "#########\n#S.RTR.E#\n#...U...#\n#########"
	warnings = builder.call("_get_configuration_warnings")
	if not _has_warning(warnings, "equally close to multiple R"):
		_fail("Builder did not warn about an ambiguous T-to-R nearest binding")
		return

	builder.free()
	builder = null
	print("[smoke] Backrooms builder Inspector warnings OK")
	get_tree().quit()


func _has_warning(warnings: PackedStringArray, fragment: String) -> bool:
	for warning in warnings:
		if warning.contains(fragment):
			return true
	return false


func _fail(message: String) -> void:
	if is_instance_valid(builder):
		builder.free()
		builder = null
	push_error(message)
	get_tree().quit(1)
