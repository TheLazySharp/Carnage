extends Node

var states : Dictionary = {}
var current_state : State
@export var initial_state : State

# FLOKING STAGGER
var sm_skip_timer: float = 0.0
const SM_SKIP_STEPS: float = 0.032

func _ready() -> void:
	sm_skip_timer = randf_range(0.0, SM_SKIP_STEPS)
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_changed.connect(_on_child_state_change)
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	sm_skip_timer += delta
	if sm_skip_timer < SM_SKIP_STEPS:
		return
	sm_skip_timer -= SM_SKIP_STEPS
	if current_state:
		current_state.physics_update(SM_SKIP_STEPS)

func state_transition_to(state_name : String) -> void:
	if current_state.name.to_lower() == state_name.to_lower():
		return
	_on_child_state_change(current_state,state_name.to_lower())

func _on_child_state_change(state : State, new_state_name : String) -> void:
	if state != current_state:
		return
	
	var new_state : State = states.get(new_state_name.to_lower())
	if !new_state:
		return
	
	if current_state:
		current_state.exit()
	new_state.enter()
	current_state = new_state

func get_current_state_name() -> String:
	return current_state.name
	
func is_in_state(state_name : String) -> bool:
	return current_state.name.to_lower() == state_name.to_lower()
