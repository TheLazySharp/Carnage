extends Area2D

@onready var car: CharacterBody2D = $".."
var damage_timer : float = 0
var damage_timer_steps : float = 0.5
@onready var camera_2d: Camera2D = $"../Camera2D"
@onready var player : CarData = CarManager.selected_car



func _process(delta: float) -> void:
	damage_timer += delta


func _on_area_entered(area: Area2D) -> void: 
	if !area.is_in_group("ennemies"):
		return
	if !"get_impact" in area:
		return
		
	var speed_ratio: float = car.velocity.length() / player.max_speed.get_value()
	var car_forward: Vector2 = Vector2.RIGHT.rotated(car.rotation)
	var car_right: Vector2 = car_forward.rotated(PI / 2)
 
	area.get_impact(car_forward, car_right, speed_ratio,car.global_position)
	car.velocity *= 0.95
	camera_2d.screen_shake(5,0.5)

	if damage_timer < damage_timer_steps :
		return
	damage_timer = 0
	car.get_damages(1)
