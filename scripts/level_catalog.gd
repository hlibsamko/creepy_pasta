class_name LevelCatalog
extends RefCounted

const BRANCH_CATALOG := preload("res://scripts/branch_catalog.gd")

const WRONG_COPY_ROOM_SCENE := preload("res://scenes/wrong_copy_room.tscn")
const COPIED_DOOR_ROOM_SCENE := preload("res://scenes/copied_door_room.tscn")
const BACKROOMS_SCENE := preload("res://scenes/backrooms/backrooms.tscn")
const HOUSE_SURVEY_SCENE := preload("res://scenes/endless_house/house_survey.tscn")
const UNLIT_EVIDENCE_SCENE := preload("res://scenes/endless_house/unlit_evidence_chamber.tscn")
const CORRIDOR_SCENE := preload("res://scenes/corridor.tscn")
const FINAL_WATCHER_ROOM_SCENE := preload("res://scenes/final_watcher_room.tscn")

const CAMPAIGN := [
	{
		"id": "wrong_copy_room",
		"title": "Room 1",
		"qa_title": "01 • Room 1 — The Wrong Copy",
		"scene": WRONG_COPY_ROOM_SCENE,
	},
	{
		"id": "copied_door_room",
		"title": "Room 2",
		"qa_title": "02 • Room 2 — The Copied Door",
		"scene": COPIED_DOOR_ROOM_SCENE,
	},
	{
		"id": "backrooms",
		"title": "Backrooms",
		"qa_title": "03 • Backrooms — Yellow Drift",
		"scene": BACKROOMS_SCENE,
	},
	{
		"id": "house_survey",
		"title": "House Survey",
		"qa_title": "04 • House Survey — Repeated Hall",
		"scene": HOUSE_SURVEY_SCENE,
	},
	{
		"id": "unlit_evidence_chamber",
		"title": "Maintenance Test",
		"qa_title": "05 • The Unlit — Maintenance Wing",
		"scene": UNLIT_EVIDENCE_SCENE,
	},
	{
		"id": "corridor",
		"title": "Corridor",
		"qa_title": "06 • Corridor — Do Not Sprint",
		"scene": CORRIDOR_SCENE,
	},
	{
		"id": "final_watcher_room",
		"title": "Final Room",
		"qa_title": "07 • Final Room — Do Not Stare",
		"scene": FINAL_WATCHER_ROOM_SCENE,
	},
]


static func find_by_id(level_id: String) -> Dictionary:
	for entry in CAMPAIGN:
		if str(entry["id"]) == level_id:
			return entry
	return {}


static func find_by_scene_path(scene_path: String) -> Dictionary:
	for entry in CAMPAIGN:
		var scene: PackedScene = entry["scene"]
		if scene.resource_path == scene_path:
			return entry
	return {}


static func scene_by_id(level_id: String) -> PackedScene:
	var entry := find_by_id(level_id)
	return entry.get("scene") as PackedScene


static func scene_by_path(scene_path: String) -> PackedScene:
	var entry := find_by_scene_path(scene_path)
	if not entry.is_empty():
		return entry["scene"] as PackedScene
	return BRANCH_CATALOG.find_scene_by_path(scene_path)


static func id_from_path(scene_path: String) -> String:
	var entry := find_by_scene_path(scene_path)
	return str(entry.get("id", ""))


static func title_from_path(scene_path: String) -> String:
	var entry := find_by_scene_path(scene_path)
	return str(entry.get("title", "Unknown Room"))


static func next_campaign_path(current_path: String) -> String:
	for index in CAMPAIGN.size():
		var scene: PackedScene = CAMPAIGN[index]["scene"]
		if scene.resource_path != current_path:
			continue
		if index >= CAMPAIGN.size() - 1:
			return FINAL_WATCHER_ROOM_SCENE.resource_path
		var next_scene: PackedScene = CAMPAIGN[index + 1]["scene"]
		return next_scene.resource_path
	return FINAL_WATCHER_ROOM_SCENE.resource_path


static func next_campaign_scene(current_scene: PackedScene) -> PackedScene:
	if current_scene == null:
		return FINAL_WATCHER_ROOM_SCENE
	return scene_by_path(next_campaign_path(current_scene.resource_path))


static func qa_entries() -> Array:
	var entries := []
	for entry in CAMPAIGN:
		var scene: PackedScene = entry["scene"]
		entries.append({
			"id": str(entry["id"]),
			"title": str(entry["qa_title"]),
			"scene_path": scene.resource_path,
		})
	for branch in BRANCH_CATALOG.ALL:
		entries.append({
			"id": branch.branch_id,
			"title": "STUDY • %s" % branch.title,
			"scene_path": branch.scene.resource_path,
		})
	return entries
