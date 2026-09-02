extends Node

@warning_ignore("unused_signal")
signal enemy_chasing(enemy : Enemy)

@warning_ignore("unused_signal")
signal enemy_is_dead(enemy : Enemy)

@warning_ignore("unused_signal")
signal enemy_exiting_chase(enemy : Enemy)

@warning_ignore("unused_signal")
signal tuto_arrow_dir(look_at_pos : Vector2)

@warning_ignore("unused_signal")
signal boost_gauge_is_full

@warning_ignore("unused_signal")
signal game_paused(game_on_pause: bool)

@warning_ignore("unused_signal")
signal piston_picked_up

@warning_ignore("unused_signal")
signal dollar_picked_up

@warning_ignore("unused_signal")
signal player_located(horde: Array)

@warning_ignore("unused_signal")
signal game_is_over(game_over: bool)

@warning_ignore("unused_signal")
signal day_ended

@warning_ignore("unused_signal")
signal selected_district(district : DistrictsData)

@warning_ignore("unused_signal")
signal selected_weapon(weapon : WeaponData, is_ammo : bool)

@warning_ignore("unused_signal")
signal instantiate_new_chunk(pos : Vector2)

@warning_ignore("unused_signal")
signal day_time_end(timer_stopped: bool)

@warning_ignore("unused_signal")
signal start_autopilot_transition

@warning_ignore("unused_signal")
signal end_autopilot_transition

@warning_ignore("unused_signal")
signal stats_updated

@warning_ignore("unused_signal")
signal upgrades_ok

@warning_ignore("unused_signal")
signal update_fortune

@warning_ignore("unused_signal")
signal wall_collision

@warning_ignore("unused_signal")
signal car_level_up_upgrade()

@warning_ignore("unused_signal")
signal enemy_stats_init(which : Enemy)

@warning_ignore("unused_signal")
signal coloss_incoming

@warning_ignore("unused_signal")
signal next_day

@warning_ignore("unused_signal")
signal half_time

@warning_ignore("unused_signal")
signal start_timer

@warning_ignore("unused_signal")
signal weapon_stats_initiated(weapon : WeaponData)

@warning_ignore("unused_signal")
signal player_invincible(invincible : bool)

@warning_ignore("unused_signal")
signal sandbox_mode

@warning_ignore("unused_signal")
signal district_survivor(survivor : SurvivorData)

@warning_ignore("unused_signal")
signal focused_entered(button : Button)

@warning_ignore("unused_signal")
signal player_life_changed(current_life : int, max_life : int)

@warning_ignore("unused_signal")
signal screen_shake_requested(intensity : float, duration : float)

@warning_ignore("unused_signal")
signal autopilot_zoom_completed

@warning_ignore("unused_signal")
signal nitro_changed(current_nitro : int)

@warning_ignore("unused_signal")
signal fuel_changed(current_fuel : int)

@warning_ignore("unused_signal")
signal map_generated(data : MapData)

@warning_ignore("unused_signal")
signal start_background_music
