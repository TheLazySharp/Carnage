extends Control

@onready var boost_container: VBoxContainer = $BoostContainer

var nb_boost : int = 4
@export var boost_scene : PackedScene

func _ready() -> void:
	var proposed_boosts : Array[BoostData] = []
	
	for i : int in nb_boost:
		var boost : BoostData = pick_boost(proposed_boosts)
		proposed_boosts.append(boost)
		
		var boost_card := boost_scene.instantiate()
		boost_container.add_child(boost_card)
		boost_card.setup(boost, false)
	
	boost_container.get_child(0).get_child(0).grab_focus()

func pick_boost(proposed_boosts : Array[BoostData]) -> BoostData:
	var attempts : int = 0
	while attempts <100:
		var boost : BoostData = ShopManager.pick_boost()
		if proposed_boosts.has(boost):
			attempts += 1
			print("boost already proposed")
			continue
		
		if boost.target_weapon != null and !WeaponsManager.weapons.has(boost.target_weapon):
			attempts += 1
			print("boost weapon not equipped")
			continue
		
		return boost
	push_warning("shop manager : no valid boost found after 100 attempts")
	return ShopManager.pick_boost()
