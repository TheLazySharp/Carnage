extends Control

@onready var entrance: Control = $"/root/Home/Entrance"

@onready var boost_container: GridContainer = $BoostContainer
@onready var fortune_tag: Label = $Background/MoneyBag/FortuneTag
@export var boost_scene : PackedScene
@onready var cash_register: AudioStreamPlayer = $Sfx/CashRegister
@onready var back: Button = $VBoxContainer/Back
@onready var shop: Control = $"."

var nb_boost : int = 8
var end_of_day_scene : String = "uid://dkpvtoel7hhai"

func _ready() -> void:
	SignalManager.update_fortune.connect(_on_item_baught)
	
	fortune_tag.text = str(InventoryManager.fortune)
	
	var proposed_boosts : Array[BoostData] = []
	
	for i : int in nb_boost:
		var boost : BoostData = pick_boost(proposed_boosts)
		proposed_boosts.append(boost)
		
		var boost_card := boost_scene.instantiate()
		boost_container.add_child(boost_card)
		boost_card.setup(boost,true)
	
	

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

func _on_item_baught() -> void:
		fortune_tag.text = str(InventoryManager.fortune)
		if self.visible:
			cash_register.play()
		


func _on_back_pressed() -> void:
	#SceneManager.load_level(end_of_day_scene)
	self.hide()
	entrance.show()


func _on_visibility_changed() -> void:
	if self.visible : 
		boost_container.get_child(0).get_child(0).grab_focus()
