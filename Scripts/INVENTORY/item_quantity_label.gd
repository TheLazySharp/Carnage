extends Label

#@export var item_manager: Node
var items: Array

var item: ItemData

var label_name:=""
var i: int

func _ready() -> void:
	label_name = get_parent().name
	i = label_name.to_int()
	items = InventoryManager.copy_items()
	if i <= items.size() -1:
		item = items[i]

func _process(_delta: float) -> void:
	if item:
		set_text(str(item.quantity))
	else: set_text(str(0))
