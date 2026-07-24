class_name Modifier
extends RefCounted

enum Type {
	FLAT,
	PERCENT_ADD,
	PERCENT_MULT,
	N_A
}


#policy applied if modifier of same source already exists
enum StackPolicy {
	STACK,
	REFRESH,
	IGNORE
}


var value: float
var type: Type
var source: String
var duration : float # if == 0 = permanent


func _init(p_value: float, p_type: Type, p_source: String, p_duration : float = 0) -> void:
	value = p_value
	type = p_type
	source = p_source
	duration = p_duration
	
func clone() -> Modifier:
	return Modifier.new(value, type, source, duration)
