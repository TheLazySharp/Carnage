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
signal player_located(horde: Array)

@warning_ignore("unused_signal")
signal game_is_over(game_over: bool)
