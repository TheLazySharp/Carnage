extends Node

var item_levels : Dictionary = {
	InventoryManager.Rarities.COMMON: 500,
	InventoryManager.Rarities.RARE: 100,
	InventoryManager.Rarities.EPIC: 20,
	InventoryManager.Rarities.LEGENDARY: 1
}

var boosts_price_levels : Dictionary = {
	InventoryManager.Rarities.COMMON: 40,
	InventoryManager.Rarities.RARE: 60,
	InventoryManager.Rarities.EPIC: 100,
	InventoryManager.Rarities.LEGENDARY: 200
}

var charms_price_levels : Dictionary = {
	InventoryManager.Rarities.COMMON: 40,
	InventoryManager.Rarities.RARE: 60,
	InventoryManager.Rarities.EPIC: 100,
	InventoryManager.Rarities.LEGENDARY: 200
}

var item_colors : Dictionary = {
	InventoryManager.Rarities.COMMON : Color.WHITE,
	InventoryManager.Rarities.RARE : Color.RED,
	InventoryManager.Rarities.EPIC : Color.YELLOW,
	InventoryManager.Rarities.LEGENDARY : Color.PURPLE
}

# Resource UIDs are loaded at runtime in load_pools().
# Do NOT use preload here: ShopManager is referenced as a type by resource scripts
# (ShopManager.CONST_REFS), so preloading resources creates an unsupported load cycle.

const CAR_BOOSTS_UIDS : Array[String] = [
	# --------- CAR BOOSTS ---------------------
	"uid://dpd83dad37goh", #bumper common
	"uid://dtqdcc0f16p4f", #bumper epic
	"uid://5n8emckrs5pv", #bumper rare
	"uid://cboeim8dshmtm", #carbon common
	"uid://c6e0cxngso5cp", #carbon epic 
	"uid://bn08he2nupmi4", #carbon rare
	"uid://y5muklkvmup", #engine common
	"uid://bowrkjeknqqru", #engine epic
	"uid://vydcpyr47y13", #engine rare
	#"uid://djtfdsqw457gd", #nitro common
	#"uid://d1kxt1otl2rfy", #nitro epic
	#"uid://8k6vcoyxekru", #nitro rare
	"uid://bs1v1nyhpxmer", #shield common
	"uid://cqhcq4c1upd25", #shield epic
	"uid://o6d75wr36o5d", #shield rare
	"uid://cytvsdd41rvyd", #tank common
	"uid://denneeu83vykp", #tank epic
	"uid://dpar3wem8fljc", #tank rare
	"uid://cfu8gxkhor7a5", #turbo common
	"uid://c3gx0tkshh2qw", #turbo epic
	"uid://bd0gfid5eh63h", #turbo rare
	#"uid://doj7a2p4rio26", #wheels common
	#"uid://bjyo2yyblhs07", #wheels epic
	#"uid://bkpcv00gc0jjf", #wheels rare
]
const WEAPONS_BOOSTS_UIDS : Array[String] = [
	# --------------- WEAPONS BOOSTS -------------
	"uid://bcdbbiu70qly7", #flamer common
	"uid://cxqsub50sexw8", #flamer epic
	"uid://dmlcx71vi7myu", #flamer rare
	"uid://dk0j2xe4yfde5", #mine launcher common
	"uid://cpuyc8iar81bw", #mine launcher epic
	"uid://d0lnee5x6ogum", #mine launcher rare
	"uid://2fuut1o3nnjr", #minigun common
	"uid://cfbdbewym78ve", #minigun epic
	"uid://ddf6g3363n0hw", #minigun rare
	"uid://jfjjptcvei6w", #revolver common
	"uid://cua1s4tfr51cr", #revolver epic
	"uid://dl2rqj0xu1lys", #revolver rare
	"uid://cn5h4lnvg26kh", #bat handler common
	"uid://bj7i14tscgwbc", #bat handler epic
	"uid://pgpxgphkp3ip", #bat handler rare
	"uid://h744goe4ilrb", #grenade belt common
	"uid://bdhgxb1b5yj6d", #grenade belt epic
	"uid://b1by71i5nlmq1", #grenade belt rare
]
const AMMO_BOOSTS_UIDS : Array[String] = [
	# --------------- AMMOS BOOSTS -------------
	"uid://jgbp675avpvv", #landmine common
	"uid://fr6ejq1bgd4x", #landmine epic
	"uid://cw8mxwa1jeupm", #landmine rare
	"uid://bikf0bhaxbup8", #baseballbat common
	"uid://bg4c6fmuy7m1y", #baseballbat epic
	"uid://bip4fb5it036h", #baseballbat rare
	"uid://csc4lrpt806dt", #revolver ammo common
	"uid://ctvgrdr6ul7u0", #revolver ammo epic
	"uid://ckixj3qnt3s4v", #revolver ammo rare
	"uid://cwc2xso207336", #minigun ammo common
	"uid://cm42x2i8ysvxy", #minigun ammo epic
	"uid://db7ji7qvilci0", #minigun ammo rare
	"uid://bqcyrkmw7dgtg", #flame common
	"uid://r78bgiis3pkw", #flame epic
	"uid://mevmn0algbg4", #flame rare
	"uid://cj610qkhuaoyu", #grenade common
	"uid://jjwpn4drfl2f", #grenade epic
	"uid://ckf34b0eo613m", #grenade rare
]
const ALL_CHARMS_UIDS : Array[String] = [
	"uid://cycv6edr3ie0h", #invincibility common
	"uid://dkm27p4j8u1jj", #shop discount
	"uid://dig2dq8y0nvfs", #add 1 projectile on all weapons (COMMON)
	"uid://b82jil28njo77", #add 3 projectiles (EPIC)
	"uid://1jcxa8pvy8yh", #invincibility EPIC
]


enum CONST_REFS {
	N_A,
	Revolver,
	Minigun,
	Bat_Handler,
	Flame_Launcher,
	Mine_Launcher,
	Bullet,
	MG_Bullet,
	Landmine,
	Flame,
	Baseball_Bat,
	Invincibility,
	Add_Projectile,
	Shop_Discount,
	Bumper,
	Carbon,
	Engine,
	Nitro_Lenght,
	Shield,
	Gas_Tank,
	Turbo,
	Wheels,
	Nitro_Tank,
	Grenade,
	Grenade_Belt
}


var all_car_boosts : Array[BoostData] = []
var all_weapon_boosts : Array[BoostData] = []
var all_ammo_boosts : Array[BoostData] = []
var all_charms : Array[CharmData] = []
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var available_boosts : int = 1
var boost_shopped : int = 0
var reroll_count : int = 0

var apply_discount : bool = false
var discount : Statistic
var base_discount : float = 1.0

func _ready() -> void:
	rng.randomize()
	discount = Statistic.new(base_discount)
	
func load_pools() -> void : 

	for uid : String in CAR_BOOSTS_UIDS:
		all_car_boosts.append(load(uid) as BoostData)
		
	for uid : String in WEAPONS_BOOSTS_UIDS:
		all_weapon_boosts.append(load(uid) as BoostData)
	
	for uid : String in AMMO_BOOSTS_UIDS:
		all_ammo_boosts.append(load(uid) as BoostData)
		
	for uid : String in ALL_CHARMS_UIDS:
		all_charms.append(load(uid) as CharmData)

func pick_boost_rarity() -> InventoryManager.Rarities:
	var weighted_sum : int = 0
	for rarity : InventoryManager.Rarities  in item_levels:
		weighted_sum += item_levels[rarity]
	
	var shop_item_weight : int = rng.randi_range(0,weighted_sum -1)
	
	for rarity : InventoryManager.Rarities in item_levels:
		shop_item_weight -= item_levels[rarity]
		if shop_item_weight < 0:
			return rarity
	return InventoryManager.Rarities.COMMON
  
func pick_boost(boost_list : Array[BoostData], p_rarity : InventoryManager.Rarities = InventoryManager.Rarities.COMMON)-> BoostData:
	var rarity : InventoryManager.Rarities 
	if p_rarity != InventoryManager.Rarities.COMMON:
		rarity = p_rarity
	else :
		rarity = pick_boost_rarity()
	var pool : Array[BoostData] = boost_list.filter(
		func(boost : BoostData) -> bool:
		return boost.rarity == rarity)
	
	if pool.is_empty():
		push_warning("shop manager : no car boost with rarity "+ str(rarity))
		pool = boost_list
		
	return pool[rng.randi_range(0,pool.size() -1)]


func pick_charm_rarity() -> InventoryManager.Rarities:
	var weighted_sum : int = 0
	for rarity : InventoryManager.Rarities  in item_levels:
		weighted_sum += item_levels[rarity]
	
	var shop_item_weight : int = rng.randi_range(0,weighted_sum -1)
	
	for rarity : InventoryManager.Rarities in item_levels:
		shop_item_weight -= item_levels[rarity]
		if shop_item_weight < 0:
			return rarity
	return InventoryManager.Rarities.COMMON

func pick_charm(p_rarity : InventoryManager.Rarities = InventoryManager.Rarities.COMMON)-> CharmData:
	var rarity : InventoryManager.Rarities
	if p_rarity != InventoryManager.Rarities.COMMON:
		rarity = p_rarity
	else :
		rarity = pick_charm_rarity()

	var pool : Array = all_charms.filter(
		func(charm : CharmData) -> bool:
		return charm.rarity == rarity)
	
	if pool.is_empty():
		push_warning("shop manager : no charm with rarity "+ str(rarity))
		pool = all_charms
	
	return pool[rng.randi_range(0,pool.size() -1)]

func pick_weapon()-> WeaponData:
	var pool : Array = WeaponsManager.unequipped_weapons
	if pool.is_empty():
		push_warning("shop manager : no weapon available")
	return pool[rng.randi_range(0,pool.size() -1)]



func get_reroll_cost() -> int :
	var reroll_cost : int
	reroll_cost = 5 + reroll_count * 3 if SceneManager.race_mode else 100 + reroll_count * 25
	return reroll_cost

func unload() -> void : 
	all_car_boosts.clear()
	all_weapon_boosts.clear()
	all_ammo_boosts.clear()
	all_charms.clear()
