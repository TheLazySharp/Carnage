extends JobEffect
## Reporter: the horn is unlocked when the job starts (already owned: +1 level instead). Kept on deactivate

var applied : bool = false


func activate() -> void:
	if applied:
		return
	applied = true
	var horn : ManeuverManager.Type = ManeuverManager.Type.HORN
	if LoadoutManager.owns(horn):
		LoadoutManager.upgrade(horn)
	else:
		LoadoutManager.unlock(horn)


func deactivate() -> void:
	pass
