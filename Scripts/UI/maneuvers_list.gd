extends Control
## Maneuver menu: every maneuver of the catalog, demo clip + name + description.
## L1 / R1 browse (wraps around). Maneuvers not owned during a run are greyed out

@export var demo_video : VideoStreamPlayer
@export var maneuver_name : Label
@export var maneuver_desc : Label
@export var previous : Label
@export var next : Label

@export_group("Inputs")
@export var previous_action : StringName = &"go_previous"  # L2
@export var next_action : StringName = &"go_next"          # R2

@export_group("Look")
@export var locked_color : Color = Color(0.55, 0.55, 0.55)
@export var close_button: Button
@export var blocked_menu : Control

var maneuvers : Array[ManeuverData] = []
var current_index : int = 0
var focus_before_open : Control = null

func _ready() -> void:
	# Enum order: stable, and the same order as everywhere else in the game
	for maneuver_type : ManeuverManager.Type in ManeuverManager.Type.values():
		var data : ManeuverData = LoadoutManager.get_maneuver_data(maneuver_type)
		if data != null:
			maneuvers.append(data)
	if maneuvers.is_empty():
		push_warning("[ManeuverMenu] the maneuver catalog is empty")
		return
	visibility_changed.connect(_on_visibility_changed)
	_show_current()


func _unhandled_input(event : InputEvent) -> void:
	if !is_visible_in_tree() or maneuvers.is_empty():
		return
	if event.is_action_pressed(next_action):
		_browse(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(previous_action):
		_browse(-1)
		get_viewport().set_input_as_handled()


## Opens the menu on a given maneuver (e.g. from the loadout panel or the shop)
func show_maneuver(maneuver_type : ManeuverManager.Type) -> void:
	for i : int in maneuvers.size():
		if maneuvers[i].maneuver_type == maneuver_type:
			current_index = i
			_show_current()
			return


func _browse(step : int) -> void:
	current_index = wrapi(current_index + step, 0, maneuvers.size())
	_show_current()


func _show_current() -> void:
	var data : ManeuverData = maneuvers[current_index]
	maneuver_name.text = tr(data.name_key)
	maneuver_desc.text = tr(data.description_key)
	# Greyed out only during a run (no ownership outside of it)
	var locked : bool = LoadoutManager.car != null and !LoadoutManager.owns(data.maneuver_type)
	maneuver_name.self_modulate = locked_color if locked else Color.WHITE
	# Neighbours: what L2 / R2 lead to
	var previous_data : ManeuverData = maneuvers[wrapi(current_index - 1, 0, maneuvers.size())]
	var next_data : ManeuverData = maneuvers[wrapi(current_index + 1, 0, maneuvers.size())]
	previous.text = "< L1 %s" % tr(previous_data.name_key)
	next.text = "%s R1 >" % tr(next_data.name_key)
	_play_video(data.demo_video)


func _play_video(video : VideoStream) -> void:
	if demo_video == null:
		return
	if video == null:
		demo_video.stop()
		demo_video.hide()
		return
	demo_video.stream = video
	demo_video.show()
	demo_video.play()


## Shown: the menu behind is locked, the close button takes the focus.
## Hidden: the clip stops, the menu behind is unlocked and gets its focus back
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		BloodBars.hide()
		focus_before_open = get_viewport().gui_get_focus_owner()
		if blocked_menu != null:
			blocked_menu.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
			blocked_menu.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		if close_button != null:
			close_button.grab_focus()
		if !maneuvers.is_empty():
			_show_current()
		return
	if demo_video != null:
		demo_video.stop()
	if blocked_menu != null:
		blocked_menu.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		blocked_menu.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if is_instance_valid(focus_before_open) and focus_before_open.is_visible_in_tree():
		focus_before_open.grab_focus()
	focus_before_open = null


func _on_close_pressed() -> void:
	self.hide()
	BloodBars.show()
