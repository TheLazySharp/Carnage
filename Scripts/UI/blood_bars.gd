extends CanvasLayer

var player : SurvivorData
var car : CarData

@onready var car_blood: ProgressBar = $CarBlood
@onready var car_blood_label: Label = $CarBlood/CarBloodLabel
@onready var car_sprite: Sprite2D = $CarBlood/CarSprite
@onready var survivor_blood: ProgressBar = $SurvivorBlood
@onready var survivor_blood_label: Label = $SurvivorBlood/SurvivorBloodLabel
@onready var survivor_sprite: Sprite2D = $SurvivorBlood/SurvivorSprite
@onready var blood_q: Label = $BloodTank/BloodQ

var bars_inited: bool = false

func _ready() -> void:
	SignalManager.update_fortune.connect(_on_fortune_updated)
	SignalManager.game_is_over.connect(_on_game_over)
	SignalManager.loading_screen_closed.connect(_on_loading_ended)
	hide()


func init() -> void : 
	bars_inited = true
	player = SurvivorsManager.on_board_survivors[0]
	car = CarManager.selected_car
	update_blood_tank()
	update_car_blood()
	update_survivor_blood()
	car_sprite.texture = car.car_sprite
	survivor_sprite.texture = player.icon
	show()
	
func update_car_blood() -> void : 
	if !bars_inited:
		init()
	var max_life : float = car.max_life.get_value()
	car_blood.max_value = max_life
	car_blood.value = car.current_life
	car_blood_label.text = "%d / %d" % [car.current_life, max_life]

func update_survivor_blood() -> void : 
	if !bars_inited:
		init()
	survivor_blood.max_value = player.max_life
	survivor_blood.value = player.current_life
	survivor_blood_label.text = "%d / %d" % [player.current_life, player.max_life]

func update_blood_tank() -> void:
	if !bars_inited:
		init()
	if InventoryManager.blood_tank_q < 0:
		InventoryManager.blood_tank_q = 0

	blood_q.text = str(InventoryManager.blood_tank_q)


func _on_fortune_updated() -> void : 
	update_blood_tank()
	
#func _on_map_generated() -> void : 
	#init()

func _on_game_over(game_is_over : bool) -> void : 
	if game_is_over:
		bars_inited = false
		self.hide()

func _on_loading_ended() -> void : 
	if !bars_inited:
		init()
	if !visible:
		show()

func unload() -> void : 
	bars_inited = false
	hide()
