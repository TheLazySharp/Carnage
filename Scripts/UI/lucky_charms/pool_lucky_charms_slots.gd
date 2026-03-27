extends VBoxContainer

@onready var button: Button = $Button
@onready var icon: TextureRect = $Button/MarginContainer/Icon
@onready var label: Label = $Label


var i : int

func _ready() -> void:
	if LuckyCharmsManager.pool.is_empty() :
		return
		
	i = int(self.name)
	
	if LuckyCharmsManager.shuffle_lucky_charms_ok:
		self.hide()
		await get_tree().create_timer(0.1).timeout ##GERER UNE ERREUR
		assert(!LuckyCharmsManager.shuffle_lucky_charms_ok,"from pool slots : lucky charm pool shuffle is undone")
		self.show()
		if i == 0:
			button.grab_focus()
		
	
	if LuckyCharmsManager.add_lucky_charm_ok :
		icon.texture = LuckyCharmsManager.shuffled_pool_copy[i].icon
		label.text = LuckyCharmsManager.shuffled_pool_copy[i].description
	
	else : 

		if i == LuckyCharmsManager.selected_new_lucky_charms_index:
			self.hide()
		else :
			icon.texture = LuckyCharmsManager.shuffled_pool_copy[i].icon
			label.text = LuckyCharmsManager.shuffled_pool_copy[i].description
		
