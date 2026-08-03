extends Node

class Entry:
	var stat_ref: WeakRef
	var mod: Modifier
	func _init(p_stat: Statistic, p_mod: Modifier) -> void:
		stat_ref = weakref(p_stat)
		mod = p_mod

var entries: Array[Entry] = []
var all_stats: Array[WeakRef] = []

func apply(stat: Statistic, template: Modifier, policy: Modifier.StackPolicy = Modifier.StackPolicy.REFRESH) -> void:
	if template.duration <= 0.0:
		push_error("TempStatManager.apply : durée invalide, ignoré (source: %s)" % template.source)
		return

	if policy != Modifier.StackPolicy.STACK:
		for entry in entries:
			if entry.stat_ref.get_ref() == stat and entry.mod.source == template.source:
				if policy == Modifier.StackPolicy.REFRESH:
					entry.mod.duration = maxf(entry.mod.duration, template.duration)
				return

	var mod: Modifier = template.clone()
	entries.append(Entry.new(stat, mod))
	stat.add_modifier(mod)


func forget(mod: Modifier) -> void:
	for i in range(entries.size() - 1, -1, -1):
		if entries[i].mod == mod:
			entries.remove_at(i)

func _process(delta: float) -> void:
	if entries.is_empty():
		return

	var remaining_entries: Array[Entry] = []
	for entry in entries:
		var stat: Statistic = entry.stat_ref.get_ref() as Statistic
		if stat == null:
			continue
		entry.mod.duration -= delta
		if entry.mod.duration <= 0.0:
			entry.mod.duration = 0.0
			stat.drop_modifier(entry.mod)
		else:
			remaining_entries.append(entry)
	entries = remaining_entries

func register_stat(stat: Statistic) -> void:
	all_stats.append(weakref(stat))

func clear_all_modifiers() -> void:
	entries.clear()
	var alive: Array[WeakRef] = []
	for weak_ref : WeakRef in all_stats:
		var stat: Statistic = weak_ref.get_ref() as Statistic
		if stat != null:
			stat.clear_modifiers()
			alive.append(weak_ref)
	all_stats = alive
