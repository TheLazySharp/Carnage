extends Node2D

var survivor : SurvivorData

@onready var survivor_icon: TextureRect = $Survivor/SurvivorIcon
@onready var weapon_icon: TextureRect = $Weapon/WeaponIcon



func _ready() -> void:
	survivor = SurvivorsManager.on_the_road_survivors[0]
	survivor_icon.texture = survivor.icon
	weapon_icon.texture = survivor.weapon.weapon_icon
