extends Node


enum TYPES {
	KILL,
	WEAPONS_DAMAGES,
	DRIFT,
	DISTANCE,
	SPEED,
	LAPS,
	SACRIFICE,
	CAR_DAMAGES,
	CAR_BLOOD_ABSORBED,
	CAR_BLOOD_LOSS
}


var implant_progress: PackedInt32Array = PackedInt32Array()


func start_race(race_data: RaceData) -> void:
	implant_progress.resize(race_data.implants.size())
	implant_progress.fill(0)
