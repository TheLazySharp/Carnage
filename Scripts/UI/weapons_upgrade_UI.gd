extends HBoxContainer

@onready var leveling: Control = $"../.."

@onready var dmg_label: Label = $Levels/Dmg_Q
@onready var fire_rate_label: Label = $Levels/FireRate_Q
@onready var cool_down_label: Label = $Levels/CoolDown_Q
@onready var radius_label: Label = $Levels/Radius_Q
@onready var nb_ammo_label: Label = $Levels/NbAmmo_Q

@onready var dmg_upgrade_label: Label = $Upgrade/Dmg_upgrade
@onready var fire_rate_upgrade_label: Label = $Upgrade/FireRate_upgrade
@onready var cool_down_upgrade_label: Label = $Upgrade/CoolDown_upgrade
@onready var radius_upgrade_label: Label = $Upgrade/Radius_upgrade
@onready var nb_ammo_upgrade_label: Label = $Upgrade/NbAmmo_upgrade

var current_dmg : int
var current_fire_rate : float
var current_cool_down : float
var current_radius : float
var current_nb_ammo : int

var upgrade_dmg : int
var upgrade_fire_rate : float
var upgrade_cool_down : float
var upgrade_radius : float
var upgrade_nb_ammo : int

func _ready() -> void:
	pass
	#StatsManager.stats_updated.connect(_on_stats_updated)
	#_on_stats_updated()
	
func _process(_delta: float) -> void:
	if !leveling.visible:
		return
	
	_on_stats_updated()


func _on_stats_updated() -> void : 
	current_dmg = int(dmg_label.text)
	current_fire_rate = float(fire_rate_label.text)
	current_cool_down = float(cool_down_label.text)
	current_radius = float(radius_label.text)
	current_nb_ammo = int(nb_ammo_label.text)

	upgrade_dmg = int(dmg_upgrade_label.text)
	upgrade_fire_rate = float(fire_rate_upgrade_label.text)
	upgrade_cool_down = float(cool_down_upgrade_label.text)
	upgrade_radius = float(radius_upgrade_label.text)
	upgrade_nb_ammo = int(nb_ammo_upgrade_label.text)
	
	if current_dmg < upgrade_dmg:
		dmg_upgrade_label.add_theme_color_override("font_color",Color.GREEN)
	
	else : add_theme_color_override("font_color",Color.WHITE)
	
	if current_fire_rate > upgrade_fire_rate:
		fire_rate_upgrade_label.add_theme_color_override("font_color",Color.GREEN)
	
	else : add_theme_color_override("font_color",Color.WHITE)
	
	if current_cool_down > upgrade_cool_down:
		cool_down_upgrade_label.add_theme_color_override("font_color",Color.GREEN)
	
	else : add_theme_color_override("font_color",Color.WHITE)
	
	if current_radius < upgrade_radius:
		radius_upgrade_label.add_theme_color_override("font_color",Color.GREEN)
	
	else : add_theme_color_override("font_color",Color.WHITE)

	if current_nb_ammo < upgrade_nb_ammo:
		nb_ammo_upgrade_label.add_theme_color_override("font_color",Color.GREEN)
	
	else : add_theme_color_override("font_color",Color.WHITE)
