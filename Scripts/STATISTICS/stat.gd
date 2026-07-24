class_name Statistic
extends RefCounted

var base_value: float
var modifiers: Array[Modifier] = []
var dirty: bool = true
var final_value: float

signal stat_adjusted(new_value : float)

func _init(p_base : float = 0.0) -> void:
	base_value = p_base


func get_value() -> float:
	if dirty:
		recalculate()
	return final_value

func add_modifier(mod: Modifier) -> void:
	modifiers.append(mod)
	dirty = true
	recalculate()

func add_temp_modifier(template: Modifier, policy: Modifier.StackPolicy = Modifier.StackPolicy.REFRESH) -> void:
	TempStatManager.apply(self, template, policy)

func remove_modifier(mod: Modifier) -> void:
	drop_modifier(mod)
	TempStatManager.forget(mod)
 
func remove_modifiers_from(source: String) -> void:
	for mod : Modifier in modifiers.duplicate():
		if mod.source == source:
			remove_modifier(mod)

func drop_modifier(mod: Modifier) -> void:
	modifiers.erase(mod)
	dirty = true
	recalculate()


func compute(mods: Array) -> float:
	var flat: float = base_value
	var percent_add: float = 0.0
	var percent_mult: float = 1.0
 
	for mod: Modifier in mods:
		match mod.type:
			Modifier.Type.FLAT:
				flat += mod.value
			Modifier.Type.PERCENT_ADD:
				percent_add += mod.value
			Modifier.Type.PERCENT_MULT:
				percent_mult *= (1.0 + mod.value)
 
	return (flat * (1.0 + percent_add)) * percent_mult


func recalculate() -> void:
	final_value = compute(modifiers)
	dirty = false
	stat_adjusted.emit(final_value)


func preview_value(extra_mod: Modifier) -> float:
	return compute(modifiers + [extra_mod])

func _on_modifier_over(mod: Modifier) -> void:
	mod.modifier_over.disconnect(_on_modifier_over)
	remove_modifier(mod)
	TempStatManager.temp_modifiers.erase(mod)
