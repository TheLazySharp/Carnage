extends Node2D

var current_item : ItemData
@onready var icon: TextureRect = $Icon


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var item : ItemData = current_item
		var effect : ItemEffect = item.effect_script.new()
		effect.activate()
		ItemManager.register(item, effect)
		queue_free()
