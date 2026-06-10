extends HBoxContainer

@onready var weapon_label: Label = $Weapon
@onready var dmg_value_label: Label = $DmgValue
@onready var weapon_cont: HBoxContainer = $"."
@onready var dps: Label = $Dps

var i : int
var weapon : WeaponData

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)
	
	i = int(weapon_cont.name)
	if i < WeaponsManager.weapons.size():
		weapon = WeaponsManager.weapons[i]
		weapon_label.text = weapon.weapon_name
		dmg_value_label.text = str(WeaponsManager.get_weapon_total_dmg(weapon))
		dps.text = "( " + str(snappedf(WeaponsManager.get_weapon_dps(weapon),0.01)) + " dps )"
	else : 
		weapon_cont.hide()

func _on_game_paused(game_paused : bool) -> void : 
	if game_paused:
		i = int(weapon_cont.name)
		if i < WeaponsManager.weapons.size():
			weapon_cont.show()
			weapon = WeaponsManager.weapons[i]
			weapon_label.text = weapon.weapon_name
			dmg_value_label.text = str(WeaponsManager.get_weapon_total_dmg(weapon))
			dps.text = "( " + str(snappedf(WeaponsManager.get_weapon_dps(weapon),0.01)) + " dps )"
		else : 
			weapon_cont.hide()
		
func _on_game_over(game_is_over : bool) -> void : 
	if game_is_over:
		i = int(weapon_cont.name)
		if i < WeaponsManager.weapons.size():
			weapon_cont.show()
			weapon = WeaponsManager.weapons[i]
			weapon_label.text = weapon.weapon_name
			dmg_value_label.text = str(WeaponsManager.get_weapon_total_dmg(weapon))
			dps.text = "( " + str(snappedf(WeaponsManager.get_weapon_dps(weapon),0.01)) + " dps )"
		else : 
			weapon_cont.hide()
			
			
			
