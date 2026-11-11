extends Node

var active_jobs: Dictionary = {}
var holder : Array[JobData] = []

@warning_ignore("unused_signal")
signal mechanic_job

func register(job: JobData, effect: JobEffect) -> void:
	active_jobs[job] = effect
	holder.append(job)


func activate_job(job : JobData) -> void:
	if job == null or job.effect_script == null or active_jobs.has(job):
		return
	var effect : JobEffect = job.effect_script.new()
	effect.job = job
	effect.activate()
	register(job, effect)

func deactivate_all() -> void:
	for effect : JobEffect in active_jobs.values():
		effect.deactivate()
	active_jobs.clear()
	
func unload() -> void : 
	for effect : JobEffect in active_jobs.values():
		effect.deactivate()
	active_jobs.clear()
	holder.clear()
