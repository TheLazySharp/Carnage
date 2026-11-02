extends Control

var player : SurvivorData

@onready var boost_container: GridContainer = $BoostContainer
@onready var charm_container: GridContainer = $CharmContainer
@onready var maneuver_container : GridContainer = $ManeuverContainer

@export var boost_scene : PackedScene
@export var charm_scene : PackedScene
@export var maneuver_scene : PackedScene
@onready var cash_register: AudioStreamPlayer = $Sfx/CashRegister
@onready var back: Button = $VBoxContainer/Back
@onready var shop: Control = $"."
@onready var reroll_button : Button = $Buttons/Reroll
@onready var reroll_cost_label: Label = $Buttons/Reroll/Cost
@onready var reroll_label: Label = $Buttons/Reroll/Reroll
@onready var repair_button: Button = $Buttons/RepairButton

#var nb_boost : int
var nb_ammo : int = 2
var nb_weapon : int = 2
var nb_charm : int = 3
var nb_maneuver : int = 2

var font_button : Array = FontManager.FONTS[FontManager.types.BUTTON]
var font_button_focus : Array = FontManager.FONTS[FontManager.types.BUTTON_FOCUS]
var font_button_pressed : Array = FontManager.FONTS[FontManager.types.BUTTON_PRESSED]
var font_button_hover : Array = FontManager.FONTS[FontManager.types.BUTTON_HOVER]

var items_ready : bool = false

func _ready() -> void:
	player = SurvivorsManager.on_board_survivors[0]

	SignalManager.update_fortune.connect(_on_item_baught)
	reroll_cost_label.text = str(ShopManager.get_reroll_cost())
	
	#REROLL BUTTON
	reroll_button.add_theme_font_override("font",font_button[0])
	reroll_button.add_theme_font_size_override("font_size",font_button[1])
	reroll_button.add_theme_color_override("font_color",font_button[2])
	reroll_button.add_theme_color_override("font_focus_color",font_button_focus[2])
	reroll_button.add_theme_color_override("font_pressed_color",font_button_pressed[2])
	reroll_button.add_theme_color_override("font_hover_color",font_button_hover[2])
	
	var new_stylebox : StyleBox = reroll_button.get_theme_stylebox("focus")
	new_stylebox.border_color = FontManager.dark_yellow
	reroll_button.add_theme_stylebox_override("focus",new_stylebox)

	if ShopManager.offer_ready:
		_build_offer()
	else:
		reroll()
	update_reroll_button()
	
	repair_button.grab_focus()

	SignalManager.emit_signal("shop_entered")
	BloodBars.show()



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		back.grab_focus()


func pick_boost(proposed_boosts : Array[BoostData], pick_list : Array[BoostData]) -> BoostData:
	var attempts : int = 0
	while attempts <1000:
		attempts += 1
		var boost : BoostData = ShopManager.pick_boost(pick_list)
		
		if proposed_boosts.has(boost):
			continue
		if boost.target_weapon != null and !WeaponsManager.weapons.has(boost.target_weapon):
			continue
		if boost.target_weapon != null and proposed_boosts.any(
				func(check : BoostData) -> bool: return InventoryManager.get_boost_name(check) == InventoryManager.get_boost_name(boost)):
			continue
		
		return boost
	# No valid boost left (e.g. an equipped weapon has no matching boost): caller shows fewer cards
	push_warning("shop : no valid boost found after 1000 attempts")
	return null


func _on_item_baught() -> void:
	if self.visible:
		cash_register.play()
		update_reroll_button()

func _on_back_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.ROADMAP)
	


func _on_visibility_changed() -> void:
	if self.visible and items_ready : 
		boost_container.get_child(0).get_child(0).grab_focus()
		SignalManager.charm_triggered.emit(ShopManager.CONST_REFS.Charm_Discount)

## New offer (first visit after a raid, or the paid reroll button): stored until the next raid
func reroll() -> void : 
	ShopManager.current_charms = ShopManager.pick_charms(nb_charm)
	ShopManager.current_maneuvers = ShopManager.pick_maneuvers(nb_maneuver)
	ShopManager.current_charm_prices.clear()
	ShopManager.offer_ready = true
	_build_offer()


## Cards of the stored offer
func _build_offer() -> void:
	# Charms: one bought during an earlier visit shows as sold (see the charm card setup)
	for charm : CharmData in ShopManager.current_charms:
		var charm_card : Control = charm_scene.instantiate()
		charm_container.add_child(charm_card)
		charm_card.setup(charm, true)
	
	# Maneuvers: one bought during an earlier visit is no longer offered
	for maneuver : ManeuverData in ShopManager.current_maneuvers:
		if LoadoutManager.owns(maneuver.maneuver_type):
			continue
		var maneuver_card : Control = maneuver_scene.instantiate()
		maneuver_container.add_child(maneuver_card)
		maneuver_card.setup(maneuver)

	items_ready = true

func _on_reroll_pressed() -> void:
	if ShopManager.get_reroll_cost() > InventoryManager.blood_tank_q:
		return
	for i in range(boost_container.get_child_count() -1,-1,-1) :
		boost_container.get_child(i).queue_free()
		
	for i in range(charm_container.get_child_count() -1,-1,-1) :
		charm_container.get_child(i).queue_free()

	for i in range(maneuver_container.get_child_count() -1,-1,-1) :
		maneuver_container.get_child(i).queue_free()
	
	reroll()
	
	InventoryManager.blood_tank_q -= ShopManager.get_reroll_cost()
	BloodBars.update_blood_tank()
	SignalManager.emit_signal("update_fortune")
	
	ShopManager.reroll_count += 1
	reroll_cost_label.text = str(ShopManager.get_reroll_cost())
	reroll_button.grab_focus()
	
func update_reroll_button()-> void : 
	if ShopManager.get_reroll_cost() <= InventoryManager.blood_tank_q:
		reroll_label.add_theme_color_override("font_color",Color.BLACK)
		reroll_cost_label.add_theme_color_override("font_color",Color.BLACK)
	else :
		reroll_label.add_theme_color_override("font_color",Color.RED)
		reroll_cost_label.add_theme_color_override("font_color",Color.RED)
