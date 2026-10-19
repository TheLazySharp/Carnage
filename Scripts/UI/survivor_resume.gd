extends Control
class_name SurvivorResume

@onready var icon: TextureRect = $SurvivorBio/Portrait/Icon
@onready var survivor_name: Label = $SurvivorName
@onready var pnj_age: Label = $SurvivorBio/PNJAge
@onready var pnj_job_name: Label = $SurvivorBio/PNJJobName
@onready var pnj_job_descr: Label = $SurvivorBio/PNJJobDescr
@onready var pnj_bio: Label = $SurvivorBio/PNJBio
@onready var weapon_icon: TextureRect = $Weapon/ColorRect/WeaponIcon
@onready var weapon_descr: Label = $Weapon/WeaponDescr
@onready var pnj_weapon: Label = $Weapon/PNJWeapon

var hidden_by_player : bool = false


func refresh(survivor : SurvivorData) -> void : 
	icon.texture = survivor.icon
	survivor_name.text = survivor.name
	pnj_age.text = str(survivor.age) + " years old"
	pnj_job_name.text = survivor.job_ressource.name
	pnj_job_descr.text = survivor.job_ressource.description
	pnj_bio.text = survivor.bio
	weapon_icon.texture = survivor.weapon.weapon_icon
	weapon_descr.text = survivor.weapon.description
	pnj_weapon.text = survivor.weapon.weapon_name


func display(survivor : SurvivorData) -> void:
	if survivor == null:
		hide()
		return
	refresh(survivor)
	visible = !hidden_by_player


func toggle() -> void:
	hidden_by_player = !hidden_by_player
	visible = !hidden_by_player
