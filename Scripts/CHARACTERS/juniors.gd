extends Node

var juniors_spawn_points:Array

@export var junior_scene : PackedScene

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

func _ready() -> void:
	juniors_spawn_points = [ false, false, false, false ]
	gm_scene.game_paused.connect(_on_game_paused)
	
func _process(_delta: float) -> void:
	#update_markers_pos()
	instantiate_junior()

func _physics_process(_delta: float) -> void:
	pass

func instantiate_junior() -> void:
	if not game_paused:
		if Input.is_action_just_released("add_junior"):
			for i in juniors_spawn_points.size():
				var marker_status = juniors_spawn_points[i]
				if marker_status == false:
					var starting_position = find_child(str("Junior",i)).global_position
					var junior := junior_scene.instantiate()
					get_node("/root/World/Juniors").add_child(junior)
					junior.spawn(starting_position)
					juniors_spawn_points[i] = true
					#print("junior created")
					break

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
