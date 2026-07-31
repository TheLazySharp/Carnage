extends Control

@onready var boost_container: GridContainer = $BoostContainer

@onready var upgrades_tag: Label = $Background/Upgrades/UpgradesTag
@export var boost_scene : PackedScene
@onready var garage_drill: AudioStreamPlayer = $Sfx/GarageDrill
@onready var icon: TextureRect = $Background/Upgrades/Icon

var nb_boost : int = 3

func _ready() -> void:
	if XPManager.available_upgrades <1:
		SceneManager.load_level(SceneManager.SCENES.HOME)
		return
	SignalManager.car_level_up_upgrade.connect(_on_car_level_up)
	upgrades_tag.text = str(maxi(0,XPManager.available_upgrades))
	icon.texture = CarManager.selected_car.car_sprite
	

	var proposed_boosts : Array[BoostData] = []
	
	for i : int in nb_boost:
		var boost : BoostData = pick_boost(proposed_boosts)
		proposed_boosts.append(boost)
		
		var boost_card := boost_scene.instantiate()
		boost_container.add_child(boost_card)
		boost_card.setup(boost,false)
		
	proposed_boosts.clear()
	boost_container.get_child(0).get_child(0).grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		pass

func pick_boost(proposed_boosts : Array[BoostData]) -> BoostData:
	var attempts : int = 0
	while attempts <100:
		var boost : BoostData = ShopManager.pick_boost(ShopManager.all_car_boosts)
		if proposed_boosts.has(boost) or boost.target_ressource != boost.Target_Ressources.CAR :
			attempts += 1
			#print("boost already proposed")
			continue
		
		return boost
	push_warning("shop manager : no valid car boost found after 100 attempts")
	return ShopManager.pick_boost(ShopManager.all_car_boosts)

func _on_car_level_up() -> void:
	XPManager.available_upgrades -= 1
	upgrades_tag.text = str(XPManager.available_upgrades)
	if self.visible:
		garage_drill.play()
	if XPManager.available_upgrades > 0 :
		reroll()
	else :
		SceneManager.load_level(SceneManager.SCENES.HOME)

func _on_visibility_changed() -> void:
	if self.visible : 
		#boost_container.get_child(0).get_child(0).grab_focus()
		pass

func reroll() -> void : 
	for i in range(boost_container.get_child_count() -1,-1,-1) :
		boost_container.get_child(i).queue_free()
	
	var proposed_boosts : Array[BoostData] = []
	
	for i : int in nb_boost:
		var boost : BoostData = pick_boost(proposed_boosts)
		proposed_boosts.append(boost)
		
		var boost_card := boost_scene.instantiate()
		boost_container.add_child(boost_card)
		boost_card.setup(boost,false)
		if i == 0 : 
			boost_card.get_child(0).grab_focus()
	
	proposed_boosts.clear()

func _on_ignore_pressed() -> void:
	if XPManager.available_upgrades > 0 :
		XPManager.available_upgrades -= 1
		upgrades_tag.text = str(XPManager.available_upgrades)
		reroll()
	else : 
		SceneManager.load_level(SceneManager.SCENES.HOME)
