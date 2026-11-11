extends JobEffect
## Thief: p_value blood in the shop bank, once, when the job starts. Never taken back

var paid : bool = false


func activate() -> void:
	if paid:
		return
	paid = true
	InventoryManager.blood_tank_q += roundi(job.p_value)
	BloodBars.update_blood_tank()


func deactivate() -> void:
	pass
