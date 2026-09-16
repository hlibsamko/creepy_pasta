class_name LevelMechanicsCatalog
extends RefCounted

const PRESSURE_REQUIREMENTS := {
	"res://scenes/copied_door_room.tscn": 1,
	"res://scenes/backrooms/backrooms.tscn": 1,
}

const PRESSURE_PLATES := {
	"res://scenes/copied_door_room.tscn": {
		"PressurePlate": {
			"position": Vector3(0.0, 0.03, -2.55),
			"activation_radius": 1.5,
		},
	},
	"res://scenes/backrooms/backrooms.tscn": {
		"BackroomsBuilder/GeneratedBackrooms/Mechanics/PressurePlate": {
			"position": Vector3(32.0, 0.03, 24.0),
			"activation_radius": 1.5,
		},
	},
	"res://scenes/endless_house/unlit_evidence_chamber.tscn": {
		"EndlessHouseBuilder/GeneratedBackrooms/Mechanics/PressurePlate": {
			"position": Vector3(4.0, 0.03, 20.0),
			"activation_radius": 1.5,
		},
	},
}

const BREAKER_REQUIREMENTS := {
	"res://scenes/endless_house/unlit_evidence_chamber.tscn": 1,
}

const BREAKERS := {
	"res://scenes/endless_house/unlit_evidence_chamber.tscn": {
		"EndlessHouseBuilder/GeneratedBackrooms/Mechanics/GeneratedBreakerTrigger1": {
			"position": Vector3(36.0, 0.0, 20.0),
			"activation_radius": 2.0,
			"work_light_id": "EndlessHouseBuilder/GeneratedBackrooms/Mechanics/GeneratedWorkLight1",
			"outage_duration": 3.2,
			"entry_id": "unlit",
			"fact_index": 3,
			"message": "The work light died. Keep your own beam on the silhouette.",
		},
	},
}

const MONSTERS := {
	"res://scenes/endless_house/unlit_evidence_chamber.tscn": {
		"EndlessHouseBuilder/GeneratedBackrooms/Monsters/GeneratedLightShyMonster1": {
			"spawn_position": Vector3(24.0, 0.0, 20.0),
			"move_speed": 2.2,
			"kill_radius": 1.0,
			"death_reason": "Something from the unlit hall reached you",
			"cell_size": 4.0,
			"layout": "############\n#S.D.L..#E.#\n#.#.###.#..#\n#.#...#.#..#\n#.###.#.##.#\n#R.L.LU.LT.#\n############",
			"flashlight_range": 18.0,
			"flashlight_angle": 34.0,
			"beam_edge_margin_degrees": 2.0,
			"journal_entry_id": "unlit",
			"journal_fact_index_on_observation": 2,
			"work_lights": [
				{
					"source_id": "EndlessHouseBuilder/GeneratedBackrooms/Mechanics/GeneratedWorkLight1",
					"power_source_id": "EndlessHouseBuilder/GeneratedBackrooms/Mechanics/PressurePlate",
					"position": Vector3(4.0, 2.65, 20.0),
					"aim_position": Vector3(24.0, 0.55, 20.0),
					"range": 24.0,
					"angle": 32.0,
				},
			],
		},
	},
}


const NOTE_GATED_MONSTERS := {
	"res://scenes/wrong_copy_room.tscn": [
		{
			"source_id": "Monsters/OpeningListener",
			"notes_required": 1,
			"entry_id": "listener",
			"fact_index": 2,
		},
	],
	"res://scenes/copied_door_room.tscn": [],
	"res://scenes/backrooms/backrooms.tscn": [
		{
			"source_id": "BackroomsBuilder/GeneratedBackrooms/Monsters/GeneratedChaser1",
			"notes_required": 1,
			"entry_id": "listener",
			"fact_index": 2,
		},
		{
			"source_id": "BackroomsBuilder/GeneratedBackrooms/Monsters/GeneratedAmbushChaser2",
			"notes_required": 2,
			"entry_id": "listener",
			"fact_index": 2,
		},
	],
	"res://scenes/endless_house/house_survey.tscn": [],
	"res://scenes/endless_house/unlit_evidence_chamber.tscn": [],
	"res://scenes/corridor.tscn": [],
	"res://scenes/final_watcher_room.tscn": [],
}


static func pressure_requirement(scene_path: String) -> int:
	return int(PRESSURE_REQUIREMENTS.get(scene_path, 0))


static func pressure_plates(scene_path: String) -> Dictionary:
	return PRESSURE_PLATES.get(scene_path, {})


static func breaker_requirement(scene_path: String) -> int:
	return int(BREAKER_REQUIREMENTS.get(scene_path, 0))


static func breakers(scene_path: String) -> Dictionary:
	return BREAKERS.get(scene_path, {})


static func monsters(scene_path: String) -> Dictionary:
	return MONSTERS.get(scene_path, {})


static func note_gated_monsters(scene_path: String) -> Array:
	return NOTE_GATED_MONSTERS.get(scene_path, [])
