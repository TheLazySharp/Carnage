extends Resource

class_name WeaponData

@export var weapon_name : String
@export var weapon_icon: Texture2D
@export var weapon_scene_uid : String
@export var weapon_ammo_scene : PackedScene
@export var weapon_ammo_res : WeaponData
@export var max_level : int
@export var dmg:= 5
@export var dmg_on_resources := 1
@export var healing_power: int
@export var atk_range : float
@export var radius := 100
@export var speed : float
@export var speed_rotation:= 15
@export var fire_rate: float
@export var cool_down: float
@export var nb_ammo: int = 1
var is_equiped: = false
@export var levelup_text : String

var current_level: int = 0
var crafted:=false

var bonus:= false
