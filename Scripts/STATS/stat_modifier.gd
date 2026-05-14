class_name Modifier
extends RefCounted

enum Type {
	FLAT,
	PERCENT_ADD,
	PERCENT_MULT,
}

var value: float
var type: Type
var source: String
var duration : float

signal modifier_over(modifier : Modifier)


func _init(p_value: float, p_type: Type, p_source: String, p_duration : float = 0) -> void:
	value = p_value
	type = p_type
	source = p_source
	duration = p_duration
	
func tick(delta: float) -> void:
	if duration <= 0:
		return
	duration -= delta
	if duration <= 0:
		duration = 0
		modifier_over.emit(self)
