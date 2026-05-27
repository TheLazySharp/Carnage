extends TextureRect

var i : int
@onready var panel: Panel = $".."


func _ready() -> void:
	i = int(panel.name)
	if CharmsManager.holder.is_empty():
		return
	if CharmsManager.holder.size() > i:
		if CharmsManager.holder[i] != null :
			self.texture = CharmsManager.holder[i].icon
