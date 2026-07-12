extends Node

const BUILD_VERSION := "0.2.0-local"


func get_display_version() -> String:
	return "v%s" % BUILD_VERSION
