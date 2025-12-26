extends Node

@export var items : Array[ItemData]


const STONE = preload("uid://budr5sdv8v70c")
const WOOD = preload("uid://bdcx24kagdrwh")



func _ready() -> void:
	items.append(STONE)
	items.append(WOOD)
	print(items)
	
	
func copy_items() -> Array:
	return items
