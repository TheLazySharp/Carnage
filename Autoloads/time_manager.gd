extends Node

var current_day: int = 0
var total_day: int = 3
var current_night: int
var total_night:int = 3
var day_lenght: int = 1 * 60 #time in seconds

func unload() -> void : 
	current_day = 0
