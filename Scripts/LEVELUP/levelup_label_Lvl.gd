extends Label

var weapon_level : int

@onready var anim_upgrade: AnimationPlayer = $AnimUpgrade
@onready var leveling: Control = $"../.."


var game_paused: bool = false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)


func _process(_delta: float) -> void:
	if visible and game_paused and leveling.visible :
	
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

func _on_game_paused(game_on_pause :bool) -> void:
	game_paused = game_on_pause
