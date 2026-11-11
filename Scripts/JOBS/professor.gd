extends JobEffect
## Professor: +p_value of end of raid score (0.2 = +20%), through the free score multiplier

func activate() -> void:
	StatsManager.score_extra_multiplier += job.p_value


func deactivate() -> void:
	StatsManager.score_extra_multiplier -= job.p_value
