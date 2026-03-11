extends Area2D


@onready var car: CharacterBody2D = get_parent()


func _ready() -> void:
	pass 



func _process(_delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ennemies") and car.is_invincible:
		var speed_ratio : float = abs(car.velocity.length()) / car.max_speed
		var car_forward : Vector2 = -car.transform.y
		var car_right : Vector2 = car.transform.x
		
		body.get_impact(car_forward, car_right, speed_ratio)
		#car.get_damages(1)
		#var resistance :float = 10
		#var forward_speed : float = car.velocity.dot(car_forward)
		#car.velocity -= car_forward * resistance * speed_ratio * sign(forward_speed)
		
