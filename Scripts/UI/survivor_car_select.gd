extends Control


var survivor : SurvivorData
@onready var pnj_name: Label = $PNJName
@onready var portrait: TextureRect = $Portrait
@onready var weapon_icon: TextureRect = $"../WeaponIcon"
@onready var pnj_weapon: Label = $"../WeaponIcon/PNJWeapon"



func _ready() -> void:
	survivor = SurvivorsManager.on_board_survivors[0]
	pnj_name.text = survivor.name
	portrait.texture = survivor.icon
	weapon_icon.texture = survivor.weapon.weapon_icon
	pnj_weapon.text = survivor.weapon.weapon_name
