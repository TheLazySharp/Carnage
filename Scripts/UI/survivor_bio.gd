extends Control

@onready var survivor_name: Label = $PNJName
@onready var survivor_age: Label = $PNJAge
@onready var survivor_job: Label = $PNJJob
@onready var survivor_weapon: Label = $WeaponIcon/PNJWeapon
@onready var survivor_job_descr: Label = $PNJJobDescr
@onready var weapon_icon: TextureRect = $WeaponIcon
@onready var weapon_descr: Label = $WeaponIcon/WeaponDescr

var survivor_index : int = 0


func _ready() -> void:
	SurvivorsManager.portrait_hovered.connect(_on_portrait_hovered)



func _process(_delta: float) -> void:
	survivor_name.text = SurvivorsManager.known_survivors[survivor_index].name
	survivor_age.text = str(SurvivorsManager.known_survivors[survivor_index].age)
	survivor_job.text = SurvivorsManager.known_survivors[survivor_index].job_ressource.name
	survivor_weapon.text = InventoryManager.get_weapon_name(SurvivorsManager.known_survivors[survivor_index].weapon)
	survivor_job_descr.text = SurvivorsManager.known_survivors[survivor_index].job_ressource.description
	weapon_icon.texture = SurvivorsManager.known_survivors[survivor_index].weapon.weapon_icon
	weapon_descr.text = SurvivorsManager.known_survivors[survivor_index].weapon.description


func _on_portrait_hovered(new_index : int) -> void : 
	survivor_index = new_index
