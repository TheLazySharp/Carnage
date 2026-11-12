extends CanvasLayer
class_name GuidePanel

signal sequence_finished

@export var focus_margin : float = 8.0   # frame space around its target (px)
@export var input_delay : float = 0.5    # real seconds: a press already in progress cannot skip the message

@onready var focus_frame : Control = $Focus
@onready var text_label : Label = $Box/VBoxContainer/Text
@onready var hint_label: Label = $Box/VBoxContainer/Hint


var steps : Array[Dictionary] = []
var step_index : int = 0
var target : Control = null
var ready_time : float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	set_process(false)


## Steps: { "text": key, "target": Control (optional), "action": ui_accept / go_next, "on_done": Callable (optional) }
func show_sequence(p_steps : Array[Dictionary]) -> void:
	steps = p_steps
	step_index = 0
	show()
	_show_step()
	set_process(true)


func _show_step() -> void:
	var step : Dictionary = steps[step_index]
	text_label.text = tr(step.get("text", ""))
	var action : StringName = step.get("action", &"ui_accept")
	hint_label.text = tr("GUIDE_HINT_R1") if action == &"go_next" else tr("GUIDE_HINT_NEXT")
	target = step.get("target", null) as Control
	ready_time = Time.get_ticks_msec() / 1000.0 + input_delay
	_update_focus()

func _process(_delta : float) -> void:
	_update_focus()


func _update_focus() -> void:
	if target == null or !is_instance_valid(target) or !target.is_visible_in_tree():
		focus_frame.hide()
		return
	var rect : Rect2 = target.get_global_rect().grow(focus_margin)
	focus_frame.position = rect.position
	focus_frame.size = rect.size
	focus_frame.show()


func _input(event : InputEvent) -> void:
	if steps.is_empty():
		return
	# Every input stays here: the screen behind must not react
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() / 1000.0 < ready_time:
		return
	var action : StringName = steps[step_index].get("action", &"ui_accept")
	var mouse_button : InputEventMouseButton = event as InputEventMouseButton
	var clicked : bool = action == &"ui_accept" and mouse_button != null and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT
	if event.is_action_pressed(action) or clicked:
		_next_step()


func _next_step() -> void:
	var on_done : Callable = steps[step_index].get("on_done", Callable())
	if on_done.is_valid():
		on_done.call()
	step_index += 1
	if step_index < steps.size():
		_show_step()
		return
	steps = []
	target = null
	hide()
	set_process(false)
	sequence_finished.emit()
