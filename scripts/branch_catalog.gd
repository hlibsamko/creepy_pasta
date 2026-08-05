class_name BranchCatalog
extends RefCounted

const DREAMCORE := preload("res://resources/branches/dreamcore_schoolhouse.tres")
const POOLROOMS := preload("res://resources/branches/poolrooms_gallery.tres")
const EMPTY_MALL := preload("res://resources/branches/empty_mall_concourse.tres")
const ENDLESS_HOTEL := preload("res://resources/branches/endless_hotel_hall.tres")
const ALL: Array[BranchDefinition] = [DREAMCORE, POOLROOMS, EMPTY_MALL, ENDLESS_HOTEL]


static func find_by_debug_key(physical_keycode: Key) -> BranchDefinition:
	if physical_keycode == KEY_F10:
		return DREAMCORE
	if physical_keycode == KEY_F11:
		return POOLROOMS
	return null


static func find_by_scene(scene: PackedScene) -> BranchDefinition:
	if scene == null:
		return null
	for branch in ALL:
		if branch.scene == scene or branch.scene.resource_path == scene.resource_path:
			return branch
	return null


static func find_by_id(branch_id: String) -> BranchDefinition:
	for branch in ALL:
		if branch.branch_id == branch_id:
			return branch
	return null


static func find_scene_by_path(scene_path: String) -> PackedScene:
	for branch in ALL:
		if branch.scene.resource_path == scene_path:
			return branch.scene
	return null
