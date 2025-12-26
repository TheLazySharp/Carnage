extends Node2D

@onready var beaver_sr: CharacterBody2D = $"../.."
@onready var healing_shape: CollisionShape2D = $"../HealingShape"
@export var color: Color
@export var width: float


func _process(_delta: float) -> void:
	queue_redraw()

func _draw()-> void:
	var center: Vector2 = Vector2.ZERO
	var radius: float = healing_shape.shape.radius
	var start_angle: float = 0
	var end_angle: float = 360
	var point_count: int = 50	
	color = Color.WHITE
	width = 0.2
	var antialiased: bool = true
	draw_arc(center, radius, start_angle, end_angle, point_count, color, width, antialiased)
