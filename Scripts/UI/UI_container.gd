extends HBoxContainer

@onready var wood_boxes_q: Label = $Woodboxes/WoodBoxesQ
@onready var gear_parts_q: Label = $GearParts/GearPartsQ
@onready var collectables: Node2D = $"../../../../Collectables"
@onready var zombies_q: Label = $Zombies/ZombiesQ
@onready var ennemy_spawner: Node2D = $"../../../../Spawners/ennemy_spawner"
@onready var frags_q: Label = $Frags/FragsQ



func _ready() -> void:
	wood_boxes_q.text = str(collectables.get_child_count())
	gear_parts_q.text = str(InventoryManager.auto_parts)
	#zombies_q.text = str(ennemy_spawner.actived_enemies())
	frags_q.text = str(StatsManager.frags)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	wood_boxes_q.text = str(collectables.get_child_count())
	gear_parts_q.text = str(InventoryManager.auto_parts)
	#zombies_q.text = str(ennemy_spawner.actived_enemies())
	frags_q.text = str(StatsManager.frags)
	
