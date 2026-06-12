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

func add_temp_modifier(mod: Modifier) -> void:
	mod.modifier_over.connect(_on_modifier_over)
	TempStatManager.register(mod)
	add_modifier(mod)

func remove_modifiers_from(source: String) -> void:
	modifiers = modifiers.filter(func(m : Modifier) -> bool: return m.source != source)
	dirty = true
	recalculate()

func remove_modifier(mod: Modifier) -> void:
	modifiers.erase(mod)
	dirty = true
	recalculate()

func recalculate() -> void:
	var flat_sum: float = base_value
	var percent_add_sum: float = 0.0
	var percent_mult: float = 1.0

	for mod in modifiers:
		match mod.type:
			Modifier.Type.FLAT:
				flat_sum += mod.value
			Modifier.Type.PERCENT_ADD:
				percent_add_sum += mod.value
			Modifier.Type.PERCENT_MULT:
				percent_mult *= (1.0 + mod.value)

	final_value = (flat_sum * (1.0 + percent_add_sum)) * percent_mult
	dirty = false
	emit_signal("stat_adjusted",final_value)


func preview_value(extra_mod: Modifier) -> float:
	var flat: float = base_value
	var percent_add: float = 0.0
	var percent_mult: float = 1.0

	var all_mods : Array = modifiers + [extra_mod]

	for mod :Modifier in all_mods:
		match mod.type:
			Modifier.Type.FLAT:
				flat += mod.value
			Modifier.Type.PERCENT_ADD:
				percent_add += mod.value
			Modifier.Type.PERCENT_MULT:
				percent_mult *= (1.0 + mod.value)

	return (flat * (1.0 + percent_add)) * percent_mult

func _on_modifier_over(mod: Modifier) -> void:
	mod.modifier_over.disconnect(_on_modifier_over)
	remove_modifier(mod)
	TempStatManager.temp_modifiers.erase(mod)
