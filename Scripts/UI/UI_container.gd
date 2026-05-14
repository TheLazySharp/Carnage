extends HBoxContainer

@onready var wood_boxes_q: Label = $Woodboxes/WoodBoxesQ
@onready var gear_parts_q: Label = $GearParts/GearPartsQ
@onready var collectables: Node2D = $"../../../../../Collectables"
@onready var zombies_q: Label = $Zombies/ZombiesQ
@onready var frags_q: Label = $Frags/FragsQ
@onready var enemies_manager: EnemiesManager = $"../../../../../EnemiesManager"



func _ready() -> void:
	wood_boxes_q.text = str(collectables.get_child_count())
	gear_parts_q.text = str(InventoryManager.auto_parts)
	if enemies_manager:
		zombies_q.text = str(enemies_manager.total_enemies)
	frags_q.text = str(StatsManager.frags)


func _process(_delta: float) -> void:
	wood_boxes_q.text = str(collectables.get_child_count())
	gear_parts_q.text = str(InventoryManager.auto_parts)
	if enemies_manager:
		zombies_q.text = str(enemies_manager.total_enemies)
	frags_q.text = str(StatsManager.frags)
