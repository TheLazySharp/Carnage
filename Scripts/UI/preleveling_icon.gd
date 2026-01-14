extends TextureRect


func _process(_delta: float) -> void:
	texture = CarManager.selected_car.car_sprite
