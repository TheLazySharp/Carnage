extends Label

var weapon_level : int

@onready var anim_upgrade: AnimationPlayer = $AnimUpgrade

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if visible:
	
		weapon_level = int(self.text)

		if weapon_level >= 0 and weapon_level != 100 :
			anim_upgrade.stop()
			anim_upgrade.reset_section()
			set_text("Lvl " + str(weapon_level) + " -> Lvl " + str(weapon_level+1))
		
		if weapon_level == 35 :
			set_text("Max Lvl")
		if weapon_level == 100 : 
			set_text("New !")
			anim_upgrade.play("IfNew")
