extends Control

var car : CarData = CarManager.selected_car



@onready var entrance: Control = $Entrance

@onready var back: Button = $Entrance/EntranceButtons/Back


#-----------------ENTRANCE -------------------#
#CAR
@onready var car_name: Label = $Entrance/Repair/CarName
@onready var car_icon: TextureRect = $Entrance/Repair/CarIcon
@onready var repair_button: Button = $Entrance/RepairButton


func _ready() -> void:
	jobs_manager.emit_signal("mechanic_job")
	car_name.text = car.car_name
	car_icon.texture = car.car_sprite
	
	entrance.show()
	repair_button.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back"):
		back.grab_focus()

func _on_back_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.ROADMAP)
