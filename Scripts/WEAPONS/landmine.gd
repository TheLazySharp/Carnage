extends Node2D

@export var mine_data : WeaponData
var dmg : int

var current_lvl : int
var max_lvl : int

var targets: Array[Node2D]

@onready var animation_mine: AnimatedSprite2D = $AnimationMine
@onready var animation_explosion: AnimatedSprite2D = $AnimationExplosion

@onready var explosion_area: Area2D = $ExplosionArea

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false


func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	max_lvl = mine_data.max_level
	animation_explosion.hide()

	

func _process(_delta: float) -> void:
	current_lvl = clampi(mine_data.current_level,0,max_lvl)
	dmg = roundi(mine_data.dmg + (current_lvl * .1 * 28)) #améliorer la formule d'augmentation des dégats
	
	
	
func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	if game_paused and animation_explosion.is_playing():
		animation_explosion.pause()
	if !game_paused and !animation_explosion.is_playing():
		animation_explosion.play()


func explosion()-> void:
	#if targets.is_empty():
		#print("explosion triggered without targets")
		#return
	animation_mine.stop()
	animation_mine.hide()
	animation_explosion.show()
	animation_explosion.play("explosion")
	
	
	for i in range(targets.size() -1, -1, -1):
		#var target : Node2D = targets[i]
		if is_instance_valid(targets[i]):
			if (targets[i].is_in_group("player") or targets[i].is_in_group("ennemies")) and "get_damages" in targets[i]:
				targets[i].get_damages(dmg)
				#print(targets[i]," gets ",dmg," dmg")
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


func _on_explosion_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("ennemies") or body.is_in_group("player"):
		targets.append(body)
		#print(body.name," add to targets")


func _on_explosion_area_body_exited(body: Node2D) -> void:
	targets.erase(body)
	

func _on_trigger_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("ennemies") or body.is_in_group("player"):
		if targets.has(body):
			explosion()


func _on_explosion_animation_finished() -> void:
	targets.clear()
	self.queue_free()


func _on_explosion_area_shape_entered(_area_rid: RID, area: Area2D, _area_shape_index: int, _local_shape_index: int) -> void:
	if area.is_in_group("explosives"):
		targets.append(area.get_parent())
		#print(area.get_parent().name," add to targets")
