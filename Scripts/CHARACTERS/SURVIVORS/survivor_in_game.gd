extends Area2D

var survivor : SurvivorData
@onready var texture_rect: TextureRect = $ColorRect/TextureRect
@onready var new_survivor: Control = $/root/World/CanvasLayer/NewSurvivor

@onready var pick_up: Button = $/root/World/CanvasLayer/NewSurvivor/YesNo/PickUp


var game_on_pause : bool = false

func _ready() -> void:
	SurvivorsManager.in_game_survivor_queuefree.connect(_queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		game_on_pause = true
		SignalManager.emit_signal("game_paused",game_on_pause)
		SurvivorsManager.emit_signal("picked_up_survivor",survivor)
		new_survivor.show()
		#pick_up.grab_focus()

func _queue_free()-> void : 
	self.queue_free()
