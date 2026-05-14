extends Area2D

@onready var collect_zone: CollisionShape2D = $CollectZone
var car : CarData

func _ready() -> void:
	car = CarManager.selected_car
	StatsManager.stats_updated.connect(_on_stats_updated)
	collect_zone.shape.radius = car.collect_radius.get_value()

	
func _on_stats_updated() -> void : 
	collect_zone.shape.radius = car.collect_radius
