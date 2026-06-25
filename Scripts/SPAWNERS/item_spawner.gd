extends Spawner

var item : ItemData
var game_paused : bool = false
@onready var spawn_timer: Timer = $SpawnTimer


func setup_trigger() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	spawn_timer.wait_time = spawn_rate
	spawn_timer.start()

func configure_instance(instance : Node, _world_pos : Vector2) -> void:
	item = ItemManager.pick_item()
	var inst_item : Node2D = instance
	inst_item.current_item = item


func on_spawned(instance : Node) -> void:
	var inst_item : Node2D = instance
	inst_item.icon.texture = item.icon
	print("item spawned at : ",inst_item.global_position)



func _on_spawn_timer_timeout() -> void:
	spawn()

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	if game_on_pause:
		spawn_timer.paused = true
	else : 
		spawn_timer.paused = false
