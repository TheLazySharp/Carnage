extends Node

var active_jobs: Dictionary = {}
var holder : Array[JobData] = []


@warning_ignore("unused_signal")
signal mechanic_job

func register(job: JobData, effect: JobEffect) -> void:
	active_jobs[job] = effect
	holder.append(job)

func deactivate_all() -> void:
	for effect : JobEffect in active_jobs.values():
		effect.deactivate()
	active_jobs.clear()
	
func unload() -> void : 
	for effect : JobEffect in active_jobs.values():
		effect.deactivate()
	active_jobs.clear()
	holder.clear()
