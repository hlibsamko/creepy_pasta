class_name BranchDefinition
extends Resource

@export var branch_id := ""
@export var title := ""
@export_multiline var objective := ""
@export_multiline var arrival_status := ""
@export var scene: PackedScene
func is_valid() -> bool:
	return branch_id != "" and title != "" and scene != null
