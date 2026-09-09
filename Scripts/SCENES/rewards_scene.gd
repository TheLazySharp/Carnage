extends Control

@onready var rewards_container: GridContainer = $RewardsContainer

var reward : ItemData
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var boosts_rewards : Array[BoostData] = []
var charms_rewards : Array[CharmData] = []
var reward_rarity : BoostData.Rarities
var box_rarity : BoostData.Rarities
var nb : int = 0

@export var boost_scene : PackedScene
@export var charm_scene : PackedScene
@onready var open_button: Button = $VBoxContainer/Open
@onready var continue_button : Button = $VBoxContainer/Continue

var rewards_ready : bool = false


var rewards_rarity_weights : Dictionary = {
	BoostData.Rarities.EPIC: 7,
	BoostData.Rarities.LEGENDARY: 3
}

var reward_box_rarity_weights : Dictionary = {
	BoostData.Rarities.COMMON: 500,
	BoostData.Rarities.RARE: 100,
	BoostData.Rarities.EPIC: 20,
	BoostData.Rarities.LEGENDARY: 3
}


var nb_rewards : Dictionary = {
	BoostData.Rarities.COMMON: 1,
	BoostData.Rarities.RARE: 2,
	BoostData.Rarities.EPIC: 3,
	BoostData.Rarities.LEGENDARY: 5
}

func _ready() -> void:
	print( "reward screen : inventory has reward ", InventoryManager.has_reward)
	continue_button.hide()
	SignalManager.reward_chosen.connect(_on_reward_chosen)
	box_rarity = set_box_rarity()
	nb = nb_rewards[box_rarity]
	if InventoryManager.rewards.is_empty():
		return
	reward = InventoryManager.rewards[0]
	open_button.grab_focus()
	
	

func _on_open_pressed() -> void:
	reward_rarity = set_reward_rarity()
	#print(rarity)
	pick_rewards()
	

func set_reward_rarity() -> BoostData.Rarities:
	var weighted_sum : int = 0
	for rarity : BoostData.Rarities  in rewards_rarity_weights:
		weighted_sum += rewards_rarity_weights[rarity]
	
	var pick_weight : int = rng.randi_range(0,weighted_sum -1)
	for rarity : BoostData.Rarities in rewards_rarity_weights:
		pick_weight -= rewards_rarity_weights[rarity]
		if pick_weight < 0:
			return rarity
	return BoostData.Rarities.EPIC


func set_box_rarity() -> BoostData.Rarities:
	var weighted_sum : int = 0
	for rarity : BoostData.Rarities  in reward_box_rarity_weights:
		weighted_sum += reward_box_rarity_weights[rarity]
	
	var box_weight : int = rng.randi_range(0,weighted_sum -1)
	
	for rarity : BoostData.Rarities in reward_box_rarity_weights:
		box_weight -= reward_box_rarity_weights[rarity]
		if box_weight < 0:
			return rarity
	return BoostData.Rarities.COMMON


func pick_rewards() -> void : 
	match reward.reward_type:
		ItemData.REWARD_TYPES.CAR_UPGRADE:
			for i in nb:
				var boost : BoostData = generate_boost(boosts_rewards, ShopManager.all_car_boosts,reward_rarity)
				boosts_rewards.append(boost)
				
				var boost_card := boost_scene.instantiate()
				rewards_container.add_child(boost_card)
				boost_card.setup(boost,false)
			
			rewards_ready = true

		ItemData.REWARD_TYPES.WEAPON_UPGRADE:
			for i in nb:
				var boost : BoostData = generate_boost(boosts_rewards, ShopManager.all_weapon_boosts,reward_rarity)
				boosts_rewards.append(boost)
				
				var boost_card := boost_scene.instantiate()
				rewards_container.add_child(boost_card)
				boost_card.setup(boost,false)
			
			rewards_ready = true
			
		ItemData.REWARD_TYPES.AMMO_UPGRADE:
			for i in nb:
				var boost : BoostData = generate_boost(boosts_rewards, ShopManager.all_ammo_boosts,reward_rarity)
				boosts_rewards.append(boost)
				
				var boost_card := boost_scene.instantiate()
				rewards_container.add_child(boost_card)
				boost_card.setup(boost,false)
			
			rewards_ready = true
			
		ItemData.REWARD_TYPES.CHARM:
			for i in nb:
				var charm : CharmData = generate_charm(charms_rewards, ShopManager.all_charms,reward_rarity)
				charms_rewards.append(charm)
				
				var charm_card := charm_scene.instantiate()
				rewards_container.add_child(charm_card)
				charm_card.setup(charm,false)
			
			rewards_ready = true
			
	if rewards_ready:
		rewards_container.get_child(0).get_child(0).grab_focus()
	print( "reward open : inventory has reward ", InventoryManager.has_reward)



func generate_boost(proposed_rewards : Array[BoostData], pick_list : Array[BoostData], rarity : BoostData.Rarities) -> BoostData:
	var attempts : int = 0
	while attempts <1000:
		attempts += 1
		var boost : BoostData = ShopManager.pick_boost(pick_list, rarity)
		
		if proposed_rewards.has(boost):
			continue
		if boost.target_weapon != null and !WeaponsManager.weapons.has(boost.target_weapon):
			continue
		if boost.target_weapon != null and proposed_rewards.any(
				func(check : BoostData) -> bool: return InventoryManager.get_boost_name(check) == InventoryManager.get_boost_name(boost)):
			continue
		
		return boost
	push_warning("rewards.tscn : no valid charm found after 1000 attempts")
	return null
	
func generate_charm(proposed_rewards : Array[CharmData], pick_list : Array[CharmData], p_rarity : BoostData.Rarities) -> CharmData:
	var attempts : int = 0
	while attempts <1000:
		attempts += 1
		var charm : CharmData = ShopManager.pick_charm()
		
		if proposed_rewards.has(charm):
			continue
		if CharmsManager.holder.has(charm):
			continue
		
		return charm
	push_warning("rewards.tscn : no valid charm found after 1000 attempts")
	return null

func _on_reward_chosen() -> void : 
	open_button.hide()
	continue_button.show()
	for i in rewards_container.get_child_count():
		rewards_container.get_child(i).queue_free()
	boosts_rewards.clear()
	charms_rewards.clear()
	rewards_ready = false
	InventoryManager.has_reward = false
	continue_button.grab_focus()
	
	

func _on_continue_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.CAR_LEVELUP)
