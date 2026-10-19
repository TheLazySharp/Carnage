extends Node

var unlocked_cars : Array[CarData] = []
var locked_cars : Array[CarData] = []
var all_cars : Array[CarData] = []
var selected_car : CarData

@warning_ignore("unused_signal")
signal car_selected

const SPORT = preload("uid://ol2ay5qpng31")
const PICKUP = preload("uid://b7vsscuy32osn")
#const POLICE = preload("uid://n4403c5fwly0")
#const TAXI = preload("uid://qitk5u1sisvn")
const SEDAN = preload("uid://dubbw5mialr30")



func _ready() -> void:
	cars_administration()

func cars_administration() -> void : 
	unlocked_cars.append(SEDAN)
	locked_cars.append(SPORT)
	locked_cars.append(PICKUP)
	
	if !unlocked_cars.is_empty():
		for i in unlocked_cars.size():
			all_cars.append(unlocked_cars[i])
	if !locked_cars.is_empty():
		for i in locked_cars.size():
			all_cars.append(locked_cars[i])
