extends CharmEffect

# ADD TO CHARMDATA TO CONST " ALL_CHARMS" IN SHOP_MANAGER.GD

var duration : float
var cool_down : float
var cool_down_timer : Timer = Timer.new()
var invincibility_timer : Timer = Timer.new()

func activate(p_charm : CharmData) -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.start_timer.connect(_on_game_timer_start)
	
	CharmsManager.add_child(cool_down_timer)
	cool_down = p_charm.p_value
	cool_down_timer.wait_time = cool_down
	cool_down_timer.autostart = false
	cool_down_timer.one_shot = true
	cool_down_timer.timeout.connect(_on_cool_down_timer_timeout)
	
	CharmsManager.add_child(invincibility_timer)
	duration = CharmsManager.invincibility_duration[p_charm.rarity]
	invincibility_timer.wait_time = duration
	invincibility_timer.autostart = false
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timer_timeout)


func deactivate() -> void:
	CarManager.selected_car.invincible = false
	SignalManager.emit_signal("player_invincible",CarManager.selected_car.invincible)

	
	cool_down_timer.stop()

func _on_game_paused(game_is_paused : bool) -> void : 
	cool_down_timer.paused = game_is_paused
	invincibility_timer.paused = game_is_paused
	
func _on_game_timer_start() -> void:
	cool_down_timer.start()
	CarManager.selected_car.invincible = false
	SignalManager.emit_signal("player_invincible",CarManager.selected_car.invincible)

	


func _on_cool_down_timer_timeout() -> void : 
	CarManager.selected_car.invincible = true
	SignalManager.emit_signal("player_invincible",CarManager.selected_car.invincible)

		
	cool_down_timer.stop()
	invincibility_timer.start()
		


func _on_invincibility_timer_timeout() -> void : 
	CarManager.selected_car.invincible = false
	SignalManager.emit_signal("player_invincible",CarManager.selected_car.invincible)

	
	cool_down_timer.start()
	invincibility_timer.stop()
