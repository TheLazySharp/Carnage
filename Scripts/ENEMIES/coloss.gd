extends CharacterBody2D

var dmg : int = 50


func _on_damage_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var player : CharacterBody2D = area.get_parent()
		if "get_damages" in player:
			player.get_damages(dmg)
	
	if area.is_in_group("ennemies"):
		if "on_coloss_death" in area:
			area.on_coloss_death()
