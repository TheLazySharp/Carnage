extends HBoxContainer

@onready var gear_parts_q: Label = $GearParts/GearPartsQ
@onready var frags_q: Label = $Frags/FragsQ
@onready var dollar_q: Label = $Dollar/DollarQ




func _ready() -> void:
	gear_parts_q.text = str(InventoryManager.auto_parts)
	dollar_q.text = str(InventoryManager.fortune)
	frags_q.text = str(StatsManager.frags)


func _process(_delta: float) -> void:
	gear_parts_q.text = str(InventoryManager.auto_parts)
	dollar_q.text = str(InventoryManager.fortune)
	frags_q.text = str(StatsManager.frags)
	
