extends Node

var cars : Array[CarData]
var selected_car : CarData

#const VIPER_BLK = preload("uid://ol2ay5qpng31")
const PICKUP_WHITE = preload("uid://b7vsscuy32osn")
#const POLICE = preload("uid://n4403c5fwly0")
#const TAXI = preload("uid://qitk5u1sisvn")
const SEDAN = preload("uid://dubbw5mialr30")



func _ready() -> void:
	cars.append(SEDAN)
	cars.append(PICKUP_WHITE)
	#cars.append(VIPER_BLK)
	#cars.append(POLICE)
	#cars.append(TAXI)
	
	#selected_car = cars[0]
