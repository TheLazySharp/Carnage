extends TextureRect


func _process(_delta: float) -> void:
	if self.visible:
		texture = CarManager.selected_car.car_sprite
