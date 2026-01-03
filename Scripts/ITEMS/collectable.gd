extends Area2D

@export var collectable_data : CollectableData
var nb_piston

func _ready() -> void:
	nb_piston = collectable_data.nb_collectable


func _process(_delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		InventoryManager.auto_parts +=nb_piston
		print(InventoryManager.auto_parts)
		queue_free()
