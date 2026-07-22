extends Area2D
class_name MapDistrict


@export var survivor_node : PackedScene
@onready var survivor_pos: Marker2D = $SurvivorPos
@onready var survivors: Node = $/root/Roadmap/MapBackground/ControlMap/Visuals/Survivors


@onready var icon: Sprite2D = $Visuals/Icon
@onready var line_2d_back: Line2D = $Visuals/Line2DBack
@onready var line_2d_front: Line2D = $Visuals/Line2DFront

var available: bool = false : set = set_available
var district : DistrictsData : set = set_district
@onready var animation_player: AnimationPlayer = $Visuals/AnimationPlayer
@onready var button: Button = $Button
@onready var pin: Sprite2D = $Visuals/Pin

const ICONS :  Dictionary = {
	DistrictsData.types.N_A: [null, Vector2.ONE],
	DistrictsData.types.ARENA: [preload("uid://bebfr5dvt68mc"), Vector2.ONE],
	DistrictsData.types.SURVIVOR: [preload("uid://ers5f6abq1k"), Vector2.ONE],
	DistrictsData.types.GARAGE: [preload("uid://cti4mltaqkgeo"), Vector2(1.25,1.25)],
	DistrictsData.types.FINAL: [preload("uid://hi7u0rqjoil8"), Vector2(2,2)],
	DistrictsData.types.SHOP: [preload("uid://brs2kf8dgvstm"), Vector2.ONE],
	DistrictsData.types.HIGHWAY: [preload("uid://b0qia31ffr14m"), Vector2.ONE],
	DistrictsData.types.BANK: [preload("uid://crpyeaolqv4r7"), Vector2.ONE],
	DistrictsData.types.GUNSHOP: [preload("uid://bx0g56iujhr01"), Vector2.ONE],
	DistrictsData.types.CARDEALER: [preload("uid://bn3oteja0m4nn"), Vector2.ONE],
	DistrictsData.types.EVENT: [preload("uid://dv0dbia1l7x8h"), Vector2.ONE]
}

func _ready() -> void:
	button.hide()
	pin.hide()


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
		button.show()
		button.grab_focus()
		animation_player.play("disctrict_available")
	elif !district.selected:
		pass #UI Ex : modulate a
	if !available:
		button.hide()

func set_district(new_data : DistrictsData) -> void : 
	district = new_data
	position = district.position
	icon.texture = ICONS[district.type][0]
	icon.scale = ICONS[district.type][1]
	
	if district.type == DistrictsData.types.SURVIVOR:
		var survivor : Node2D = survivor_node.instantiate()
		survivors.add_child(survivor)
		survivor.global_position = survivor_pos.global_position

	if RoadMapManager.selected_districts.has(district):
		pin.show()

func show_selected() -> void : 
	line_2d_back.modulate = Color.DIM_GRAY
	line_2d_front.modulate = Color.DIM_GRAY

func on_map_district_selected() -> void :
	emit_signal("selected",district)

func _on_button_pressed() -> void:
	#print("button pressed on disctrict : ",district, " / row : ",district.row)
	SceneManager.load_district(district)
	SignalManager.emit_signal("selected_district",district)
