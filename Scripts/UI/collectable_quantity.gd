extends Label

@onready var gear_parts_q: Label = $"../../GearParts/GearPartsQ"


var quantity: int

func _ready() -> void:
	quantity = InventoryManager.auto_parts
	set_text(str(quantity))

func _process(_delta: float) -> void:
	quantity = InventoryManager.auto_parts
	set_text(str(quantity))
