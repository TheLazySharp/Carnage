extends CharmEffect
## Rabbit foot: if survivor life < p_value, all weapons are boosted by 20%

var dmg_boost : float = 0.2
var skull_modifier : Modifier
const charm_skull_source : String = "CHARM_SKULL_MOD"


func activate(p_charm : CharmData) -> void:
	SignalManager.charm_skull_triggered.connect(_on_charm_skull_triggered)
	CharmsManager.charm_skull_life_floor = p_charm.p_value
	skull_modifier = Modifier.new(dmg_boost,Modifier.Type.PERCENT_ADD,charm_skull_source)

func deactivate() -> void:
	CharmsManager.charm_skull_life_floor = 0.0

func _on_charm_skull_triggered(skull_triggered : bool) -> void : 
	if skull_triggered:
		apply_skull_mod()
	else : 
		remove_skull_mod()
		
func apply_skull_mod() -> void : 
	for i in WeaponsManager.weapons.size():
		WeaponsManager.weapons[i].weapon_ammo_res.dmg.add_modifier(skull_modifier)

func remove_skull_mod() -> void : 
	for i in WeaponsManager.weapons.size():
		WeaponsManager.weapons[i].weapon_ammo_res.dmg.remove_modifier(skull_modifier)
