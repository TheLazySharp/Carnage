extends Resource

class_name WeaponData

@export_group("GLOBAL INFO")
@export var weapon_name : String
@export var weapon_icon: Texture2D
@export var weapon_is_active:=true
@export var max_level : int
@export var description : String

@export_group("UID AND SCENES")
@export var weapon_scene_uid : String
@export var weapon_ammo_scene : PackedScene
@export var weapon_ammo_res : WeaponData

@export_group("BASE STATS")

@export var base_dmg : = 5
@export var base_atk_range : float
@export var base_radius := 100
@export var base_speed_rotation:= 15
@export var base_fire_rate: float
@export var base_cool_down: float
@export var base_nb_ammo: int = 1

@export_group("COEFF STATS (0 or 1)")
@export var coeff_dmg : int
@export var coeff_atk_range : int
@export var coeff_radius : int
@export var coeff_speed_rotation : int
@export var coeff_fire_rate : int
@export var coeff_cool_down : int
@export var coeff_nb_ammo : int


@export_group("OTHERS")
@export var dmg_on_resources := 1
@export var healing_power: int
@export var speed : float

var current_level: int = 0
var dmg : int 
var dmg_upgrade : int

var fire_rate : float
var fire_rate_upgrade : float

var cool_down : float
var cool_down_upgrade : float

var radius : float
var radius_upgrade : float

var nb_ammo : int
var nb_ammo_upgrade : int

var is_equiped: = false
var crafted : bool = false
var bonus : bool = false
