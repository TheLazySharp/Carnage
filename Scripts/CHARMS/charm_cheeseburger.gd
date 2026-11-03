extends CharmEffect
# Cheeseburger: + p_value max blood for the player. The extra room comes empty:
# re-equipping it in the loadout must never heal for free

var player : SurvivorData = null  # the survivor who got the bonus (removed from him on deactivate)
var bonus : int = 0


func activate(p_charm : CharmData) -> void:
	if player != null or SurvivorsManager.on_board_survivors.is_empty():
		return
	player = SurvivorsManager.on_board_survivors[0]
	bonus = int(p_charm.p_value)
	player.max_life += bonus
	BloodBars.update_survivor_blood()


func deactivate() -> void:
	if player == null:
		return
	player.max_life -= bonus
	player.current_life = mini(player.current_life, player.max_life)
	BloodBars.update_survivor_blood()
	player = null
