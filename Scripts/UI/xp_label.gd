extends Label

@onready var xp_manager: Node = $"/root/XPManager"

func _ready() -> void:
	xp_manager.update_level.connect(_update_level)
	text = "Lvl " + str(XPManager.current_level)

func _process(_delta: float) -> void:
	#text = "Lvl " + str(player_xp_manager.current_level)
	pass

func _update_level(current_level):
	text = "Lvl " + str(current_level)
	print("new level received : ",current_level)
