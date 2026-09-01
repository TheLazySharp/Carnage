extends Node2D

@export var mine_data : WeaponData
@export var explosion_scene : PackedScene
var damages : int
var damages_upgrade : int

var current_lvl : int
var max_lvl : int
var expl_limitor : int = 0

var targets: Array[Node2D]
var player_trigger_count : int = 0

@onready var animation_mine: AnimatedSprite2D = $AnimationMine
@onready var explosion_sfx: AudioStreamPlayer2D = $ExplosionSFX
@onready var explosion_area: Area2D = $ExplosionArea
@onready var camera_2d: Camera2D = $/root/World/Car/Camera2D

var game_paused:=false


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)

	max_lvl = mine_data.max_level
	explosion_sfx.stream = mine_data.weapon_sfx
	damages = int(mine_data.dmg.get_value())
	


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func explosion()-> void:
	if expl_limitor >= 1:
		return
	expl_limitor = 1
	
	var new_explosion : Node2D = explosion_scene.instantiate()
	new_explosion.global_position = self.global_position
	get_node("/root/World/VFX/Explosions").add_child(new_explosion)
	
	
	animation_mine.stop()
	animation_mine.hide()
	explosion_sfx.play()
	camera_2d.screen_shake(8,0.5)
	

	for i in range(targets.size() -1, -1, -1):

		if is_instance_valid(targets[i]):				
			if targets[i].is_in_group("ennemies") and "get_damages" in targets[i]:
				targets[i].get_damages(mine_data.dmg.get_value())
				mine_data.total_damages_dealt += int(mine_data.dmg.get_value())

			elif targets[i].is_in_group("explosives") and "chain_explosion" in targets[i]:
				targets[i].chain_explosion(self)


func chain_explosion(from_mine : Node2D) -> void:
	for i in range(targets.size()-1,-1,-1):
		if targets[i] == from_mine:
			targets.remove_at(i)
			break
	#print("explosion from chain")
	await get_tree().create_timer(0.2).timeout
	explosion()


func _on_explosion_animation_finished() -> void:
	targets.clear()
	expl_limitor = 0
	self.queue_free()


func _on_explosion_area_shape_entered(_area_rid: RID, area: Area2D, _area_shape_index: int, _local_shape_index: int) -> void:
	if area.is_in_group("explosives"):
		targets.append(area.get_parent())


func _on_trigger_area_entered(area: Area2D) -> void:
	if area.is_in_group("ennemies") :
		if targets.has(area):
			explosion()


func _on_explosion_area_entered(area: Area2D) -> void:
	if area.is_in_group("ennemies"):
		targets.append(area)
