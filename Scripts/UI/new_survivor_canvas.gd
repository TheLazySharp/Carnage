extends Control

@onready var pnj_name_icon: Label = $MarginContainer/BoxContainer/PNJ0/PNJName
@onready var color_rect: ColorRect = $MarginContainer/BoxContainer/PNJ0/ColorRect
@onready var portrait: TextureRect = $MarginContainer/BoxContainer/PNJ0/Portrait
@onready var pick_up: Button = $YesNo/PickUp

@onready var pnj_name: Label = $SurvivorBio/PNJName
@onready var pnj_age: Label = $SurvivorBio/PNJAge
@onready var pnj_job: Label = $SurvivorBio/PNJJob
@onready var pnj_bio: Label = $SurvivorBio/PNJBio

@onready var weapon_icon: TextureRect = $SurvivorBio/WeaponIcon
@onready var pnj_weapon: Label = $SurvivorBio/WeaponIcon/PNJWeapon
@onready var weapon_descr: Label = $SurvivorBio/WeaponIcon/WeaponDescr

var game_on_pause : bool = false
var survivor : SurvivorData

func _ready() -> void:
	SurvivorsManager.picked_up_survivor.connect(_on_survivor_picked_up)
	hide() 


func _process(_delta: float) -> void:
	pass

func _on_survivor_picked_up(new_survivor : SurvivorData) -> void : 
	survivor = new_survivor
	portrait.texture = new_survivor.icon
	pnj_name.text = new_survivor.name
	pnj_name_icon.text = new_survivor.name
	pnj_age.text = str(new_survivor.age)
	pnj_job.text = new_survivor.job_ressource.name
	pnj_bio.text = new_survivor.job_ressource.description
	weapon_icon.texture = new_survivor.weapon.weapon_icon
	pnj_weapon.text = InventoryManager.get_weapon_name(new_survivor.weapon)
	weapon_descr.text = new_survivor.weapon.description
	pick_up.grab_focus()


func _on_pick_up_pressed() -> void:
	SurvivorsManager.pick_up_survivor(survivor)
	var job : JobData = survivor.job_ressource
	var effect : JobEffect = job.effect_script.new()
	effect.activate()
	jobs_manager.register(job, effect)
	
	SurvivorsManager.emit_signal("in_game_survivor_queuefree")
	self.hide()
	SignalManager.emit_signal("game_paused",game_on_pause)
	


func _on_leave_pressed() -> void:
	self.hide()
	SignalManager.emit_signal("game_paused",game_on_pause)
