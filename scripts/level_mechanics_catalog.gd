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


static func pressure_requirement(scene_path: String) -> int:
	return int(PRESSURE_REQUIREMENTS.get(scene_path, 0))


static func pressure_plates(scene_path: String) -> Dictionary:
	return PRESSURE_PLATES.get(scene_path, {})
