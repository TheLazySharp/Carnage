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

var nb_boost : int = 6
var nb_charm : int = 2
var end_of_day_scene : String = "uid://dkpvtoel7hhai"

func _ready() -> void:
	SignalManager.update_fortune.connect(_on_item_baught)
	
	fortune_tag.text = str(InventoryManager.fortune)
	
	var proposed_boosts : Array[BoostData] = []
	var proposed_charms : Array[CharmData] = []
	
	for i : int in nb_boost:
		var boost : BoostData = pick_boost(proposed_boosts)
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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		back.grab_focus()

func pick_boost(proposed_boosts : Array[BoostData]) -> BoostData:
	var attempts : int = 0
	while attempts <100:
		var boost : BoostData = ShopManager.pick_boost()
		if proposed_boosts.has(boost):
			attempts += 1
			#print("boost already proposed")
			continue
		
		if boost.target_weapon != null and !WeaponsManager.weapons.has(boost.target_weapon):
			attempts += 1
			#print("boost weapon not equipped")
			continue
		
		return boost
	push_warning("shop manager : no valid boost found after 100 attempts")
	return ShopManager.pick_boost()

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
	#SceneManager.load_level(end_of_day_scene)
	self.hide()
	entrance.show()
	back_entrance.grab_focus()

func _on_visibility_changed() -> void:
	if self.visible : 
		boost_container.get_child(0).get_child(0).grab_focus()
