extends Spawner

var survivor : SurvivorData
signal beacon_activated(beacon_pos : Vector2)


func setup_trigger() -> void:
	if !SurvivorsManager.unknown_survivors.is_empty():
		survivor = SurvivorsManager.unknown_survivors[0] #---------FOR NOW. WILL BE MODIFY TO ALLOW SEVERAL SURVIVOR TO SPAWN
		
		if GameMaster.game_mode != GameMaster.GAME_MODES.GOD:
			spawn()

func configure_instance(instance : Node, _world_pos : Vector2) -> void:
	var inst_survivor : Node2D = instance
	inst_survivor.survivor = survivor

func on_spawned(instance : Node) -> void:
	var inst_survivor : Node2D = instance
	inst_survivor.texture_rect.texture = survivor.icon
	print("survivor spawned at : ",inst_survivor.global_position)
	emit_signal("beacon_activated", inst_survivor.global_position)
