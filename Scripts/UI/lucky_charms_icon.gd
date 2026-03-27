extends TextureRect

var i : int
@onready var panel: Panel = $".."


func _ready() -> void:
	i = int(panel.name)
	if LuckyCharmsManager.holder.is_empty():
		return
	if LuckyCharmsManager.holder.size() > i:
		if LuckyCharmsManager.holder[i] != null :
			self.texture = LuckyCharmsManager.holder[i].icon


#func _process(_delta: float) -> void:
	#if self.texture != null : 
		#return
	#else : 
		#update_icon()
#
#func update_icon() -> void :
	#if LuckyCharmsHolder.holder.size() > i :
		#self.texture = LuckyCharmsHolder.holder[i].icon
		#
