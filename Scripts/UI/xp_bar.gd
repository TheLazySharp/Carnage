extends ProgressBar

#@onready var xp_manager: Node = $"/root/XPManager"

func _ready() -> void:
	XPManager.update_xp.connect(_update_xp)
	XPManager.update_max_xp_target.connect(_update_max_xp)
	value = XPManager.current_xp
	max_value = XPManager.current_level_target_xp

func _process(_delta: float) -> void:
	#value = player_xp_manager.current_xp
	#max_value = player_xp_manager.current_level_target_xp
	pass

func _update_xp(current_xp)-> void:
	value = current_xp
	#print("current xp received = ",value)

func _update_max_xp(max_xp) -> void:
	max_value = max_xp
	#print("current max xp received = ",max_value)
