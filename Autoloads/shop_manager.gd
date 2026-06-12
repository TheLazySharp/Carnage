extends Node

var item_levels : Dictionary = {
	BoostData.Rarities.COMMON: 500,
	BoostData.Rarities.RARE: 100,
	BoostData.Rarities.EPIC: 20,
	BoostData.Rarities.LEGENDARY: 1
}

var price_levels : Dictionary = {
	BoostData.Rarities.COMMON: 10,
	BoostData.Rarities.RARE: 20,
	BoostData.Rarities.EPIC: 100,
	BoostData.Rarities.LEGENDARY: 300
}

var item_colors : Dictionary = {
	BoostData.Rarities.COMMON : Color.WHITE,
	BoostData.Rarities.RARE : Color.RED,
	BoostData.Rarities.EPIC : Color.YELLOW,
	BoostData.Rarities.LEGENDARY : Color.PURPLE
}

const ALL_BOOSTS : Array = [
	preload("uid://dpd83dad37goh"),
	preload("uid://dtqdcc0f16p4f"),
	preload("uid://5n8emckrs5pv"),
	preload("uid://cboeim8dshmtm"),
	preload("uid://c6e0cxngso5cp"),
	preload("uid://bn08he2nupmi4"),
	preload("uid://y5muklkvmup"),
	preload("uid://bowrkjeknqqru"),
	preload("uid://vydcpyr47y13"),
	preload("uid://djtfdsqw457gd"),
	preload("uid://d1kxt1otl2rfy"),
	preload("uid://8k6vcoyxekru"),
	preload("uid://bs1v1nyhpxmer"),
	preload("uid://cqhcq4c1upd25"),
	preload("uid://o6d75wr36o5d"),
	preload("uid://cytvsdd41rvyd"),
	preload("uid://denneeu83vykp"),
	preload("uid://dpar3wem8fljc"),
	preload("uid://c3gx0tkshh2qw"),
	preload("uid://bd0gfid5eh63h"),
	preload("uid://doj7a2p4rio26"),
	preload("uid://bjyo2yyblhs07"),
	preload("uid://bkpcv00gc0jjf"),


	preload("uid://bcdbbiu70qly7"),
	preload("uid://cxqsub50sexw8"),
	preload("uid://dmlcx71vi7myu"),
	preload("uid://jgbp675avpvv"),
	preload("uid://fr6ejq1bgd4x"),
	preload("uid://cw8mxwa1jeupm"),
	preload("uid://dk0j2xe4yfde5"),
	preload("uid://cpuyc8iar81bw"),
	preload("uid://d0lnee5x6ogum"),
	preload("uid://cwc2xso207336"),
	preload("uid://cm42x2i8ysvxy"),
	preload("uid://db7ji7qvilci0"),
	preload("uid://2fuut1o3nnjr"),
	preload("uid://cfbdbewym78ve"),
	preload("uid://ddf6g3363n0hw"),
	preload("uid://ctvgrdr6ul7u0"),
	preload("uid://ckixj3qnt3s4v"),
	preload("uid://jfjjptcvei6w"),
	preload("uid://cua1s4tfr51cr"),
	preload("uid://dl2rqj0xu1lys")
]

const ALL_CHARMS : Array = [
	preload("uid://cycv6edr3ie0h"),		#invincibility
	preload("uid://dkm27p4j8u1jj"),		#drift fire
	preload("uid://dig2dq8y0nvfs")		#add projectil on all weapons
	
]

var all_boosts : Array[BoostData] = []
var all_charms : Array[CharmData] = []
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var available_boosts : int = 1
var boost_shopped : int = 0
var reroll_cost : int
var reroll_count : int = 0

var apply_discount : bool = false
var discount : Statistic
var base_discount : float = 1.0

func _ready() -> void:
	rng.randomize()
	discount = Statistic.new(base_discount)
	

func load_pools() -> void : 
	for boost : BoostData in ALL_BOOSTS:
		all_boosts.append(boost)
	
	for charm : CharmData in ALL_CHARMS:
		all_charms.append(charm)

func pick_boost_rarity() -> BoostData.Rarities:
	var weighted_sum : int = 0
	for rarity : BoostData.Rarities  in item_levels:
		weighted_sum += item_levels[rarity]
	
	var shop_item_weight : int = rng.randi_range(0,weighted_sum -1)
	
	for rarity : BoostData.Rarities in item_levels:
		shop_item_weight -= item_levels[rarity]
		if shop_item_weight < 0:
			return rarity
	return BoostData.Rarities.COMMON
  
func pick_boost()-> BoostData:
	var rarity : BoostData.Rarities = pick_boost_rarity()
	var pool : Array = all_boosts.filter(
		func(boost : BoostData) -> bool:
		return boost.rarity == rarity)
	
	if pool.is_empty():
		push_warning("shop manager : no boost with rarity "+ str(rarity))
		pool = all_boosts
	
	return pool[rng.randi_range(0,pool.size() -1)]

func pick_charm_rarity() -> CharmsManager.Rarities:
	var weighted_sum : int = 0
	for rarity : CharmsManager.Rarities  in item_levels:
		weighted_sum += item_levels[rarity]
	
	var shop_item_weight : int = rng.randi_range(0,weighted_sum -1)
	
	for rarity : CharmsManager.Rarities in item_levels:
		shop_item_weight -= item_levels[rarity]
		if shop_item_weight < 0:
			return rarity
	return CharmsManager.Rarities.COMMON

func pick_charm()-> CharmData:
	var rarity : CharmsManager.Rarities = pick_charm_rarity()
	var pool : Array = all_boosts.filter(
		func(charm : CharmData) -> bool:
		return charm.rarity == rarity)
	
	if pool.is_empty():
		push_warning("shop manager : no charm with rarity "+ str(rarity))
		pool = all_charms
	
	return pool[rng.randi_range(0,pool.size() -1)]

func get_reroll_cost() -> int : 
	return 100 + reroll_count * 25

func unload() -> void : 
	all_boosts.clear()
	all_charms.clear()
