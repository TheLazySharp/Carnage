extends Control

@onready var entrance: Control = $"/root/Home/Entrance"
@onready var back_entrance: Button = $"/root/Home/Entrance/EntranceButtons/Back"

@onready var boost_container: GridContainer = $BoostContainer
@onready var charm_container: GridContainer = $CharmContainer

@onready var fortune_tag: Label = $Background/MoneyBag/FortuneTag
@export var boost_scene : PackedScene
@export var charm_scene : PackedScene
@onready var cash_register: AudioStreamPlayer = $Sfx/CashRegister
@onready var back: Button = $VBoxContainer/Back
@onready var shop: Control = $"."
@onready var reroll_button : Button = $Background/Reroll
@onready var reroll_cost_label: Label = $Background/Reroll/HBoxContainer/Cost
@onready var reroll_label: Label = $Background/Reroll/HBoxContainer/Reroll

#var nb_boost : int
var nb_ammo : int = 2
var nb_weapon : int = 2
var nb_charm : int = 3

var font_button : Array = FontManager.FONTS[FontManager.types.BUTTON]
var font_button_focus : Array = FontManager.FONTS[FontManager.types.BUTTON_FOCUS]
var font_button_pressed : Array = FontManager.FONTS[FontManager.types.BUTTON_PRESSED]
var font_button_hover : Array = FontManager.FONTS[FontManager.types.BUTTON_HOVER]

var items_ready : bool = false

func _ready() -> void:
	SignalManager.update_fortune.connect(_on_item_baught)
	fortune_tag.text = str(InventoryManager.fortune)
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
		
	reroll()
	
	
func _process(_delta: float) -> void:
	if ShopManager.get_reroll_cost() <= InventoryManager.fortune:
		reroll_label.add_theme_color_override("font_color",Color.BLACK)
		reroll_cost_label.add_theme_color_override("font_color",Color.BLACK)
	else :
		reroll_label.add_theme_color_override("font_color",Color.RED)
		reroll_cost_label.add_theme_color_override("font_color",Color.RED)

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
		#if boost.target_weapon != null and proposed_boosts.any(
				#func(check : BoostData) -> bool: return check.name == boost.name):
			continue
		
		return boost
	push_warning("shop manager : no valid boost found after 1000 attempts")
	return null

func pick_charm(proposed_charms : Array[CharmData]) -> CharmData:
	var attempts : int = 0
	while attempts <100:
		var charm : CharmData = ShopManager.pick_charm()
		if proposed_charms.has(charm):
			attempts += 1
			#print("charm already proposed")
			continue
		
		return charm
	push_warning("shop manager : no valid charm found after 100 attempts")
	
	return ShopManager.pick_charm()

func _on_item_baught() -> void:
		fortune_tag.text = str(InventoryManager.fortune)
		if self.visible:
			cash_register.play()

func _on_back_pressed() -> void:
	if SceneManager.previous_scene == SceneManager.SCENES.ROADMAP:
		SceneManager.load_level(SceneManager.SCENES.ROADMAP)
		return
	self.hide()
	entrance.show()
	back_entrance.grab_focus()

func _on_visibility_changed() -> void:
	if self.visible and items_ready : 
		boost_container.get_child(0).get_child(0).grab_focus()

func reroll() -> void : 
	var proposed_boosts : Array[BoostData] = []
	var proposed_charms : Array[CharmData] = []
	
	var ammos : int = mini(nb_ammo,WeaponsManager.weapons.size())
	var weapons : int = mini(nb_weapon,WeaponsManager.weapons.size())
	
	for i : int in ammos:
		var boost : BoostData = pick_boost(proposed_boosts, ShopManager.all_ammo_boosts)
		proposed_boosts.append(boost)
		
		var boost_card := boost_scene.instantiate()
		boost_container.add_child(boost_card)
		boost_card.setup(boost,true)

	for i : int in weapons:
		var boost : BoostData = pick_boost(proposed_boosts, ShopManager.all_weapon_boosts)
		proposed_boosts.append(boost)
		
		var boost_card := boost_scene.instantiate()
		boost_container.add_child(boost_card)
		boost_card.setup(boost,true)


	for i : int in nb_charm:
		var charm : CharmData = pick_charm(proposed_charms)
		proposed_charms.append(charm)
		
		var charm_card := charm_scene.instantiate()
		charm_container.add_child(charm_card)
		charm_card.setup(charm,true)
		
	proposed_boosts.clear()
	proposed_charms.clear()
	
	items_ready = true
	boost_container.get_child(0).get_child(0).grab_focus()

func _on_reroll_pressed() -> void:
	if ShopManager.get_reroll_cost() >= InventoryManager.fortune:
		return
	for i in range(boost_container.get_child_count() -1,-1,-1) :
		boost_container.get_child(i).queue_free()
		
	for i in range(charm_container.get_child_count() -1,-1,-1) :
		charm_container.get_child(i).queue_free()
	reroll()
	InventoryManager.fortune -= ShopManager.get_reroll_cost()
	SignalManager.emit_signal("update_fortune")
	
	ShopManager.reroll_count += 1
	reroll_cost_label.text = str(ShopManager.get_reroll_cost())
	boost_container.get_child(0).get_child(0).grab_focus()
