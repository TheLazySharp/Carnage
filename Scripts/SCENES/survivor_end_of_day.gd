extends Control

@export var confirm_button : Button

@onready var icon: TextureRect = $Resume/SurvivorBio/Portrait/Icon
@onready var survivor_name: Label = $Resume/SurvivorName
@onready var pnj_age: Label = $Resume/SurvivorBio/PNJAge
@onready var pnj_job_name: Label = $Resume/SurvivorBio/PNJJobName
@onready var pnj_job_descr: Label = $Resume/SurvivorBio/PNJJobDescr
@onready var pnj_bio: Label = $Resume/SurvivorBio/PNJBio
@onready var weapon_icon: TextureRect = $Resume/Weapon/ColorRect/WeaponIcon
@onready var weapon_descr: Label = $Resume/Weapon/WeaponDescr
@onready var pnj_weapon: Label = $Resume/Weapon/PNJWeapon

func _ready() -> void:
	var survivor : SurvivorData = SurvivorsManager.rescued_survivor
	if survivor == null:
		SceneManager.load_post_raid()
		return
	BloodBars.hide()
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.grab_focus()
	icon.texture = survivor.icon
	survivor_name.text = survivor.name
	pnj_age.text = str(survivor.age) + " years old"
	pnj_job_name.text = tr(survivor.job_ressource.name)
	pnj_job_descr.text = tr(survivor.job_ressource.description)
	pnj_bio.text = survivor.bio
	weapon_icon.texture = survivor.weapon.weapon_icon
	weapon_descr.text = survivor.weapon.description
	pnj_weapon.text = survivor.weapon.weapon_name


func _on_confirm_pressed() -> void:
	confirm_button.disabled = true
	SurvivorsManager.confirm_rescue()
	SceneManager.load_post_raid()
