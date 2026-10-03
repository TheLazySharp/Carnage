extends Control

var player : SurvivorData

@onready var boost_container: GridContainer = $BoostContainer
@onready var weapon_container: GridContainer = $WeaponContainer

@onready var fortune_tag: Label = $Background/MoneyBag/FortuneTag
@export var boost_scene : PackedScene
@export var weapon_scene : PackedScene
@onready var cash_register: AudioStreamPlayer = $Sfx/CashRegister
@onready var back: Button = $VBoxContainer/Back
@onready var reroll_button : Button = $Background/Reroll
@onready var reroll_cost_label: Label = $Background/Reroll/HBoxContainer/Cost
@onready var reroll_label: Label = $Background/Reroll/HBoxContainer/Reroll

#var nb_boost : int
var nb_ammo_boost : int = 2
var nb_weapon_boost : int = 2
var nb_weapon : int = 3

var font_button : Array = FontManager.FONTS[FontManager.types.BUTTON]
var font_button_focus : Array = FontManager.FONTS[FontManager.types.BUTTON_FOCUS]
var font_button_pressed : Array = FontManager.FONTS[FontManager.types.BUTTON_PRESSED]
var font_button_hover : Array = FontManager.FONTS[FontManager.types.BUTTON_HOVER]

var items_ready : bool = false
var game_paused : bool = false

func _ready() -> void:
	self.hide()
	SignalManager.pit_choice.connect(_on_pit_choice)
	SignalManager.pit_entered.connect(_on_pit_entered)
	
	player = SurvivorsManager.on_board_survivors[0]
	
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


func _process(_delta: float) -> void:
	if !game_paused:
		return
	if ShopManager.get_reroll_cost() <= player.current_life :
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
		if boost.target_weapon != null and proposed_boosts.any(
				func(check : BoostData) -> bool: return InventoryManager.get_boost_name(check) == InventoryManager.get_boost_name(boost)):
			continue
		
		return boost
	# No valid boost left (e.g. an equipped weapon has no matching boost): caller shows fewer cards
	push_warning("pit stop : no valid boost found after 1000 attempts")
	return null

func pick_weapon(proposed_weapons : Array[WeaponData]) -> WeaponData:
	var attempts : int = 0
	while attempts <100:
		var weapon : WeaponData = ShopManager.pick_weapon()
		if proposed_weapons.has(weapon):
			attempts += 1
			continue
		
		return weapon
	push_warning("shop manager : no valid weapon found after 100 attempts")
	
	return ShopManager.pick_weapon()

func _on_pit_choice() -> void:
		fortune_tag.text = str(player.current_life)
		if self.visible:
			cash_register.play()

func _on_back_pressed() -> void:
	if SceneManager.previous_scene == SceneManager.SCENES.ROADMAP:
		SceneManager.load_level(SceneManager.SCENES.ROADMAP)
		return
	self.hide()
	for i in range(boost_container.get_child_count() -1,-1,-1) :
		boost_container.get_child(i).queue_free()
		
	for i in range(weapon_container.get_child_count() -1,-1,-1) :
		weapon_container.get_child(i).queue_free()
	SignalManager.emit_signal("game_paused",false)
	game_paused = false


func _on_visibility_changed() -> void:
	if self.visible and items_ready : 
		# Boost container can be empty if no equipped weapon has a valid boost
		if boost_container.get_child_count() > 0:
			boost_container.get_child(0).get_child(0).grab_focus()
		elif weapon_container.get_child_count() > 0:
			weapon_container.get_child(0).get_child(0).grab_focus()

func reroll() -> void : 
	var proposed_boosts : Array[BoostData] = []
	var proposed_weapons : Array[WeaponData] = []
	
	var ammos : int = mini(nb_ammo_boost,WeaponsManager.weapons.size())
	var weapons : int = mini(nb_weapon_boost,WeaponsManager.weapons.size())
	
	for i : int in ammos:
		var boost : BoostData = pick_boost(proposed_boosts, ShopManager.all_ammo_boosts)
		# No valid ammo boost left: stop here instead of creating an empty card
		if boost == null:
			break
		proposed_boosts.append(boost)
		
		var boost_card := boost_scene.instantiate()
		boost_container.add_child(boost_card)
		boost_card.setup(boost,true)
		
	for i : int in weapons:
		var boost : BoostData = pick_boost(proposed_boosts, ShopManager.all_weapon_boosts)
		# No valid weapon boost left: stop here instead of creating an empty card
		if boost == null:
			break
		proposed_boosts.append(boost)
		
		var boost_card := boost_scene.instantiate()
		boost_container.add_child(boost_card)
		boost_card.setup(boost,true)


	for i : int in nb_weapon:
		var weapon : WeaponData = pick_weapon(proposed_weapons)
		proposed_weapons.append(weapon)
		
		var weapon_card := weapon_scene.instantiate()
		weapon_container.add_child(weapon_card)
		weapon_card.setup(weapon,true)
		
	proposed_boosts.clear()
	proposed_weapons.clear()
	
	items_ready = true

func _on_reroll_pressed() -> void:
	if ShopManager.get_reroll_cost() >= player.current_life:
		return
	for i in range(boost_container.get_child_count() -1,-1,-1) :
		boost_container.get_child(i).queue_free()
		
	for i in range(weapon_container.get_child_count() -1,-1,-1) :
		weapon_container.get_child(i).queue_free()
	reroll()
	SignalManager.emit_signal("survivor_blood_consummed",ShopManager.get_reroll_cost())
	SignalManager.emit_signal("blood_payment",ShopManager.get_reroll_cost())
	SignalManager.emit_signal("update_fortune")
	ShopManager.reroll_count += 1
	reroll_cost_label.text = str(ShopManager.get_reroll_cost())
	fortune_tag.text = str(player.current_life)
	reroll_button.grab_focus()
	
func _on_pit_entered() -> void : 
	SignalManager.emit_signal("game_paused",true)
	game_paused = true
	fortune_tag.text = str(player.current_life)
	reroll()
	self.show()
