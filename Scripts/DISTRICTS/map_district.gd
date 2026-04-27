extends Area2D
class_name MapDistrict

signal selected(district : DistrictsData)

@onready var icon: Sprite2D = $Visuals/Icon
@onready var line_2d_back: Line2D = $Visuals/Line2DBack
@onready var line_2d_front: Line2D = $Visuals/Line2DFront

var available: bool = false : set = set_available
var district : DistrictsData : set = set_district
@onready var animation_player: AnimationPlayer = $Visuals/AnimationPlayer
@onready var button: Button = $Button

const ICONS :  Dictionary = {
	DistrictsData.types.N_A: [null, Vector2.ONE],
	DistrictsData.types.PARKING: [preload("uid://ers5f6abq1k"), Vector2.ONE],
	DistrictsData.types.MISSION: [preload("uid://cti4mltaqkgeo"), Vector2.ONE],
	DistrictsData.types.GARAGE: [preload("uid://c5r5wpwsuw4jn"), Vector2(1.25,1.25)],
	DistrictsData.types.BOSS: [preload("uid://hi7u0rqjoil8"), Vector2(2,2)],
	DistrictsData.types.SHOP: [preload("uid://dv0dbia1l7x8h"), Vector2.ONE]
}

func _ready() -> void:
	button.hide()


func _process(_delta: float) -> void:
	if button.has_focus():
		icon.self_modulate = Color.RED
	else :
		icon.self_modulate = Color.WHITE
		

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if !available or !event.is_action_pressed("select"):
		return
	district.selected = true
	
	
	
	# UI Ex SFX/DRAW.. 
	#and wait for the animation finished for emit the selected signal
	#CALL FROM THE ANIMATION PLAYER !!!
	#add track -> call method -> chose the node on with there is a script with the callable -> add key frame and chose the method
	#/!\ hard to track -> add print in the callable for debug tracking

func set_available(new_value : bool) -> void : 
	available = new_value
	if available:
		line_2d_back.show()
		line_2d_front.show()
		animation_player.play("disctrict_available")
	elif !district.selected:
		pass #UI Ex : modulate a


func set_district(new_data : DistrictsData) -> void : 
	district = new_data
	position = district.position
	icon.texture = ICONS[district.type][0]
	icon.scale = ICONS[district.type][1]


func show_selected() -> void : 
	line_2d_back.modulate = Color.DIM_GRAY
	line_2d_front.modulate = Color.DIM_GRAY

func on_map_district_selected() -> void : 
	emit_signal("selected",district)

func _on_button_pressed() -> void:
	print("button pressed on disctrict : ",district, " / column : ",district.column)
	SceneManager.load_district(district)
