extends Label

var quantity: int

func _ready() -> void:
	quantity = InventoryManager.auto_parts
	set_text(str(quantity))

func _process(_delta: float) -> void:
	quantity = InventoryManager.auto_parts
	set_text(str(quantity))

	
	
