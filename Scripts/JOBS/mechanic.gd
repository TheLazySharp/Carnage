extends JobEffect



func activate() -> void:
	jobs_manager.mechanic_job.connect(_job_done)
	
func deactivate() -> void:
	pass

func _job_done() -> void : 
	var car : CarData = CarManager.selected_car
	var car_repair : int = min(car.max_life.get_value() * 0.25, car.max_life.get_value() - car.current_life)
	car.current_life += car_repair
	print("mechanic job done ! : ",car_repair)
