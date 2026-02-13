extends Node2D


@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

@onready var car: CharacterBody2D = $Car
@onready var garage_arrow: AnimatedSprite2D = $Car/TutoArrow/GarageArrow

var game_started:bool=false

@onready var tuto_label: Label = $CanvasLayer/Training/Label
@onready var ready_go: Label = $CanvasLayer/Texts/ReadyGo
@onready var XP_bar: Control = $CanvasLayer/XP


#STEP1
@onready var accelarate_sprite: AnimatedSprite2D = $Steps/AccelerateArea/AccelarateSprite

#STEP2
@onready var back_sprite: AnimatedSprite2D = $Steps/BackArea/BackSprite
@onready var arrow_1_to_2: AnimatedSprite2D = $Steps/Arrow1To2

#STEP3
@onready var move_sprite: AnimatedSprite2D = $Steps/MoveArea/MoveSprite
@onready var arrow_2_to_3: AnimatedSprite2D = $Steps/Arrow2To3

#STEP4
@onready var drift_sprite1: AnimatedSprite2D = $Steps/DriftArea1/DriftSprite

#STEP5
@onready var drift_sprite2: AnimatedSprite2D = $Steps/DriftArea2/DriftSprite

#STEP6
@onready var drift_sprite3: AnimatedSprite2D = $Steps/DriftArea3/DriftSprite

#STEP7
@onready var drift_sprite4: AnimatedSprite2D = $Steps/DriftArea4/DriftSprite

#STEP8
@onready var resources_panel: Panel = $CanvasLayer/Training/ResourcesPanel
@onready var resources_ok: Button = $CanvasLayer/Training/ResourcesPanel/Ok

#STEP9
const WOODBOX = preload("uid://dcsapykrdl5tf")
@onready var arrow_8_to_9: AnimatedSprite2D = $Steps/Arrow8To9
@onready var wood_boxe_marker: Marker2D = $Steps/WoodBoxe
@onready var woodbox_timer: Timer = $Steps/WoodboxTimer


#STEP10
@onready var enemies_panel: Panel = $CanvasLayer/Training/EnemiesPanel
@onready var enemies_ok: Button = $CanvasLayer/Training/EnemiesPanel/Ok

#STEP11
const ENEMY = preload("uid://dgt25kdq0ormg")
@onready var marker_enemies: Marker2D = $Steps/Enemies
@onready var arrow_10_to_11: AnimatedSprite2D = $Steps/Arrow10To11
@onready var enemies_timer: Timer = $Steps/EnemiesTimer


#STEP12
@onready var end_panel: Panel = $CanvasLayer/Training/EndPanel
@onready var end_ok: Button = $CanvasLayer/Training/EndPanel/Ok

#STEP13
signal tuto_end
var skip_tuto : bool = false

var current_step: int = 0

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	car.start_time.connect(_on_game_started)
	XP_bar.hide()
	tuto_label.hide()
	accelarate_sprite.hide()
	resources_panel.hide()
	enemies_panel.hide()
	end_panel.hide()
	back_sprite.hide()
	move_sprite.hide()
	drift_sprite1.hide()
	drift_sprite2.hide()
	drift_sprite3.hide()
	drift_sprite4.hide()
	arrow_1_to_2.hide()
	arrow_2_to_3.hide()
	arrow_8_to_9.hide()
	arrow_10_to_11.hide()
	
func _process(_delta: float) -> void:
	pass


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	
func _on_game_started(game_has_started : bool) -> void:
	game_started = game_has_started
	await get_tree().create_timer(SceneManager.ready_go_timer).timeout
	steps(1)

func steps(step : int) -> void:
	current_step = step
	match current_step:
		0: 
			return
		1:
			tuto_label.text = "Press RT to accelerate"
			tuto_label.show()
			accelarate_sprite.play("zone")
			accelarate_sprite.show()

		2:
			accelarate_sprite.hide()
			accelarate_sprite.stop()
			accelarate_sprite.get_parent().set_deferred("disabled",true)
			
			tuto_label.text = "Press LT to go backward"
			arrow_1_to_2.play("moving")
			arrow_1_to_2.show()
			back_sprite.play("zone")
			back_sprite.show()

		3:
			arrow_1_to_2.hide()
			arrow_1_to_2.stop()
			back_sprite.stop()
			back_sprite.hide()
			back_sprite.get_parent().set_deferred("disabled",true)
			
			tuto_label.text = "Use the left stick to move"
			arrow_2_to_3.play("moving")
			arrow_2_to_3.show()
			move_sprite.play("zone")
			move_sprite.show()
		
		4:
			arrow_2_to_3.hide()
			arrow_2_to_3.stop()
			move_sprite.hide()
			move_sprite.stop()
			move_sprite.get_parent().set_deferred("disabled",true)
			
			tuto_label.text = "Press LT while moving to drift !"
			
			drift_sprite1.play("zone")
			drift_sprite1.show()
		
		5:
			drift_sprite1.hide()
			drift_sprite1.stop()
			drift_sprite1.get_parent().set_deferred("disabled",true)
			
			drift_sprite2.play("zone")
			drift_sprite2.show()
			
		6:
			drift_sprite2.hide()
			drift_sprite2.stop()
			drift_sprite2.get_parent().set_deferred("disabled",true)
						
			drift_sprite3.play("zone")
			drift_sprite3.show()
		
		7:
			drift_sprite3.hide()
			drift_sprite3.stop()
			drift_sprite3.get_parent().set_deferred("disabled",true)
			
			drift_sprite4.play("zone")
			drift_sprite4.show()
		
		8:
			drift_sprite4.hide()
			drift_sprite4.stop()
			tuto_label.hide()
			drift_sprite4.get_parent().set_deferred("disabled",true)
			
			resources_panel.show()
			resources_ok.grab_focus()
			#PUT GAME ON PAUSE
		
		9:
			resources_panel.hide()
			
			tuto_label.text = "Pick up the box"
			tuto_label.show()
			arrow_8_to_9.play("moving")
			arrow_8_to_9.show()
			var woodbox : Area2D = WOODBOX.instantiate()
			get_node("/root/World/Collectables").add_child(woodbox)
			woodbox.global_position = wood_boxe_marker.global_position
			woodbox_timer.start()
		
		10:
			woodbox_timer.stop()
			arrow_8_to_9.hide()
			arrow_8_to_9.stop()
			tuto_label.hide()
			
			enemies_panel.show()
			enemies_ok.grab_focus()
			#PUT ON PAUSE
		
		11:
			enemies_panel.hide()
			
			tuto_label.text = "Kill the two zombies"
			tuto_label.show()
			arrow_10_to_11.play("moving")
			arrow_10_to_11.show()
			XP_bar.show()
			var enemy0 : Enemy = ENEMY.instantiate()
			get_node("/root/World/Enemies").add_child(enemy0)
			enemy0.activate(marker_enemies.global_position)
			
			var enemy1 :Enemy = ENEMY.instantiate()
			get_node("/root/World/Enemies").add_child(enemy1)
			
			enemy1.activate(marker_enemies.global_position + Vector2(10,10))
			enemies_timer.start()
			
		12:
			enemies_timer.stop()
			arrow_10_to_11.hide()
			arrow_10_to_11.stop()
			tuto_label.hide()
			
			end_panel.show()
			end_ok.grab_focus()
			#PUT ON PAUSE
			
		13:
			end_panel.hide()
			garage_arrow.play("moving")
			garage_arrow.show()
			tuto_label.text = "Go back to your garage"
			tuto_label.show()
			emit_signal("tuto_end")


func _on_accelerate_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and Input.is_action_pressed("accelerate") and current_step == 1:
		steps(2)

func _on_back_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and Input.is_action_pressed("back") and current_step == 2:
		steps(3)

func _on_move_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and current_step == 3:
		steps(4)

func _on_drift_area_1_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and Input.is_action_pressed("drift") and current_step == 4:
		steps(5)

func _on_drift_area_2_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and Input.is_action_pressed("drift") and current_step == 5:
		steps(6)

func _on_drift_area_3_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and Input.is_action_pressed("drift") and current_step == 6:
		steps(7)

func _on_drift_area_4_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and Input.is_action_pressed("drift") and current_step == 7:
		steps(8)

func _on_ok_resources_pressed() -> void:
	steps(9)

func _on_enemies_ok_pressed() -> void:
	steps(11)

func _on_end_ok_pressed() -> void:
	steps(13)

func _on_woodbox_timer_timeout() -> void:
	if get_node("/root/World/Collectables").get_child_count() == 0 and current_step == 9:
		steps(10)


func _on_enemies_timer_timeout() -> void:
	if get_node("/root/World/Enemies").get_child_count() == 0 and current_step == 11:
		steps(12)


func _on_check_point_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and !skip_tuto:
		if SceneManager.tuto_completed:
			skip_tuto = true
			emit_signal("tuto_end")
