extends VBoxContainer

@onready var button: Button = $Button
@onready var icon: TextureRect = $Button/MarginContainer/Icon
@onready var label: Label = $Label

var i : int
var charms : Array[CharmData]

func _ready() -> void:
	i = int(self.name)
	if i >= LuckyCharmsManager.holder.size():
		self.hide()
		return
	
	charms = LuckyCharmsManager.holder

	if charms[i] != null:
		icon.texture = charms[i].icon
		label.text = charms[i].description
	
	elif LuckyCharmsManager.add_lucky_charm_ok : 
		if (i != 0 and charms[i-1] != null) or (i == 0 and  charms[i] == null) : 
			icon.texture = null
			label.text = "ADD"

		if i != 0 and charms[i] == null and charms[i-1] == null:
			self.hide()
	
	else : 
		self.hide()
