extends Node

var temp_modifiers: Array[Modifier] = []

func register(mod: Modifier) -> void:
	if mod.duration > 0:
		#mod.modifier_over.connect(_on_modifier_over)
		temp_modifiers.append(mod)
	else:
		push_error("TempStatManager : modificateur sans durée ajouté par erreur (source: " + mod.source + ")")

func _process(delta: float) -> void:
	if temp_modifiers.is_empty():
		return
	for mod : Modifier in temp_modifiers.duplicate():
		mod.tick(delta)

#func _on_modifier_over(mod: Modifier) -> void:
	#temp_modifiers.erase(mod)
