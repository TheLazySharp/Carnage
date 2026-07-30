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

const CAR_BOOSTS : Array = [
	# --------- CAR BOOSTS ---------------------
	preload("uid://dpd83dad37goh"), #bumper common
	preload("uid://dtqdcc0f16p4f"), #bumper epic
	preload("uid://5n8emckrs5pv"), #bumper rare
	preload("uid://cboeim8dshmtm"), #carbon common
	preload("uid://c6e0cxngso5cp"), #carbon epic 
	preload("uid://bn08he2nupmi4"), #carbon rare
	preload("uid://y5muklkvmup"), #engine common
	preload("uid://bowrkjeknqqru"), #engine epic
	preload("uid://vydcpyr47y13"), #engine rare
	preload("uid://djtfdsqw457gd"), #nitro common
	preload("uid://d1kxt1otl2rfy"), #nitro epic
	preload("uid://8k6vcoyxekru"), #nitro rare
	preload("uid://bs1v1nyhpxmer"), #shield common
	preload("uid://cqhcq4c1upd25"), #shield epic
	preload("uid://o6d75wr36o5d"), #shield rare
	preload("uid://cytvsdd41rvyd"), #tank common
	preload("uid://denneeu83vykp"), #tank epic
	preload("uid://dpar3wem8fljc"), #tank rare
	preload("uid://cfu8gxkhor7a5"), #turbo common
	preload("uid://c3gx0tkshh2qw"), #turbo epic
	preload("uid://bd0gfid5eh63h"), #turbo rare
	preload("uid://doj7a2p4rio26"), #wheels common
	preload("uid://bjyo2yyblhs07"), #wheels epic
	preload("uid://bkpcv00gc0jjf"), #wheels rare
]
const WEAPONS_BOOSTS : Array = [
	# --------------- WEAPONS BOOSTS -------------
	preload("uid://bcdbbiu70qly7"), #flamer common
	preload("uid://cxqsub50sexw8"), #flamer epic
	preload("uid://dmlcx71vi7myu"), #flamer rare
	preload("uid://dk0j2xe4yfde5"), #mine laucnher common
	preload("uid://cpuyc8iar81bw"), #mine laucnher epic
	preload("uid://d0lnee5x6ogum"), #mine laucnher rare
	preload("uid://2fuut1o3nnjr"), #minigun common
	preload("uid://cfbdbewym78ve"), #minigun epic
	preload("uid://ddf6g3363n0hw"), #minigun rare
	preload("uid://jfjjptcvei6w"), #revolver common
	preload("uid://cua1s4tfr51cr"), #revolver epic
	preload("uid://dl2rqj0xu1lys"), #revolver rare
	preload("uid://cn5h4lnvg26kh"), #bat handler common
	preload("uid://bj7i14tscgwbc"), #bat handler epic
	preload("uid://pgpxgphkp3ip"), #bat handler rare
]

const AMMO_BOOSTS : Array = [
	# --------------- AMMOS BOOSTS -------------
	preload("uid://jgbp675avpvv"), #landmine common
	preload("uid://fr6ejq1bgd4x"), #landmine epic
	preload("uid://cw8mxwa1jeupm"), #landmine rare
	preload("uid://bikf0bhaxbup8"), #baseballbat common
	preload("uid://bg4c6fmuy7m1y"), #baseballbat epic
	preload("uid://bip4fb5it036h"), #baseballbat rare
	preload("uid://csc4lrpt806dt"), #revolver ammo common
	preload("uid://ctvgrdr6ul7u0"), #revolver ammo epic
 	preload("uid://ckixj3qnt3s4v"), #revolver ammo rare
	preload("uid://cwc2xso207336"), #minigun ammo common
	preload("uid://cm42x2i8ysvxy"), #minigun ammo epic
	preload("uid://db7ji7qvilci0"), #minigun ammo rare

]

const ALL_CHARMS : Array = [
	preload("uid://cycv6edr3ie0h"), #invincibility
	preload("uid://dkm27p4j8u1jj"), #shop discount
	preload("uid://dig2dq8y0nvfs") #add projectil on all weapons
]

var all_car_boosts : Array[BoostData] = []
var all_weapon_boosts : Array[BoostData] = []
var all_ammo_boosts : Array[BoostData] = []
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
	for car_boost : BoostData in CAR_BOOSTS:
		all_car_boosts.append(car_boost)
		
	for weapon_boost : BoostData in WEAPONS_BOOSTS:
		all_weapon_boosts.append(weapon_boost)
	
	for ammo_boost : BoostData in AMMO_BOOSTS:
		all_ammo_boosts.append(ammo_boost)
		
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
  
func pick_boost(boost_list : Array[BoostData])-> BoostData:
	var rarity : BoostData.Rarities = pick_boost_rarity()
	var pool : Array = boost_list.filter(
		func(boost : BoostData) -> bool:
		return boost.rarity == rarity)
	
	if pool.is_empty():
		push_warning("shop manager : no car boost with rarity "+ str(rarity))
		pool = boost_list
	
	return pool[rng.randi_range(0,pool.size() -1)]


#func pick_car_boost()-> BoostData:
	#var rarity : BoostData.Rarities = pick_boost_rarity()
	#var pool : Array = all_car_boosts.filter(
		#func(boost : BoostData) -> bool:
		#return boost.rarity == rarity)
	#
	#if pool.is_empty():
		#push_warning("shop manager : no car boost with rarity "+ str(rarity))
		#pool = all_car_boosts
	#
	#return pool[rng.randi_range(0,pool.size() -1)]
#
#func pick_weapon_boost()-> BoostData:
	#var rarity : BoostData.Rarities = pick_boost_rarity()
	#var pool : Array = all_weapon_boosts.filter(
		#func(boost : BoostData) -> bool:
		#return boost.rarity == rarity)
	#
	#if pool.is_empty():
		#push_warning("shop manager : no weapon boost with rarity "+ str(rarity))
		#pool = all_weapon_boosts
	#
	#return pool[rng.randi_range(0,pool.size() -1)]
#
#func pick_ammo_boost()-> BoostData:
	#var rarity : BoostData.Rarities = pick_boost_rarity()
	#var pool : Array = all_ammo_boosts.filter(
		#func(boost : BoostData) -> bool:
		#return boost.rarity == rarity)
	#
	#if pool.is_empty():
		#push_warning("shop manager : no ammo boost with rarity "+ str(rarity))
		#pool = all_ammo_boosts
	#
	#return pool[rng.randi_range(0,pool.size() -1)]

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
	var pool : Array = all_charms.filter(
		func(charm : CharmData) -> bool:
		return charm.rarity == rarity)
	
	if pool.is_empty():
		push_warning("shop manager : no charm with rarity "+ str(rarity))
		pool = all_charms
	
	return pool[rng.randi_range(0,pool.size() -1)]

func get_reroll_cost() -> int : 
	return 100 + reroll_count * 25

func unload() -> void : 
	all_car_boosts.clear()
	all_weapon_boosts.clear()
	all_ammo_boosts.clear()
	all_charms.clear()
