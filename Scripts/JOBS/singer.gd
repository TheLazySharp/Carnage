extends JobEffect
## Singer: +p_value combo max

var singer_mod : Modifier = null
var applied_stat : Statistic = null


func activate() -> void:
	if applied_stat != null:
		return
	singer_mod = Modifier.new(job.p_value, Modifier.Type.FLAT, "singer job")
	applied_stat = CarManager.selected_car.combo_max
	applied_stat.add_modifier(singer_mod)


func deactivate() -> void:
	if applied_stat == null:
		return
	applied_stat.remove_modifier(singer_mod)
	applied_stat = null
