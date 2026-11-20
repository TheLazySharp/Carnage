extends Control

enum Phase { MESSAGE, LINES, DONE }

@export_group("SFX (optional)")
@export var message_sfx : AudioStream
@export var line_sfx : AudioStream
@export var total_sfx : AudioStream

@export_group("TIMING")
@export var message_fade_time : float = 0.8
@export var message_hold_time : float = 1.5
@export var step_delay : float = 0.3          # seconds between two lines

@onready var title_label : Label = %Title
@onready var stats_list : VBoxContainer = %StatsList
@onready var stat_template : HBoxContainer = %StatTemplate
@onready var total_row : HBoxContainer = %TotalRow
@onready var ok_button : Button = %OkButton

var phase : Phase = Phase.MESSAGE
var line_rows : Array[HBoxContainer] = []
var line_index : int = 0
var wait_left : float = 0.0
var line_player : AudioStreamPlayer
var total_player : AudioStreamPlayer
var message_tween : Tween = null


func _ready() -> void:
	BloodBars.hide()
	stat_template.hide()
	stats_list.hide()
	total_row.hide()
	ok_button.hide()
	ok_button.pressed.connect(_on_ok_pressed)
	line_player = _make_player(line_sfx)
	total_player = _make_player(total_sfx)
	_build_lines(StatsManager.get_run_stats())

	# Phase 1: the victory message alone
	title_label.text = tr("VICTORY_TITLE")
	title_label.modulate.a = 0.0
	var message_player : AudioStreamPlayer = _make_player(message_sfx)
	if message_player.stream != null:
		message_player.play()
	message_tween = create_tween()
	message_tween.tween_property(title_label, "modulate:a", 1.0, message_fade_time)
	message_tween.tween_interval(message_hold_time)
	message_tween.finished.connect(_start_lines)


func _make_player(stream : AudioStream) -> AudioStreamPlayer:
	var player : AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	return player


# ---------------- INPUT ----------------

func _input(event : InputEvent) -> void:
	if !event.is_action_pressed("ui_accept"):
		return
	if phase == Phase.MESSAGE:
		_start_lines()
		get_viewport().set_input_as_handled()
	elif phase == Phase.LINES:
		# Every remaining line at once, then the total
		for row : HBoxContainer in line_rows:
			row.show()
		line_index = line_rows.size()
		_show_total()
		get_viewport().set_input_as_handled()


func _on_ok_pressed() -> void:
	SceneManager.unload_game()
	SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)


# ---------------- SEQUENCE ----------------

func _start_lines() -> void:
	if phase != Phase.MESSAGE:
		return
	phase = Phase.LINES
	if message_tween != null and message_tween.is_valid():
		message_tween.kill()
	title_label.modulate.a = 1.0  # the message stays as the screen title
	stats_list.show()
	wait_left = step_delay


func _process(delta : float) -> void:
	if phase != Phase.LINES:
		return
	wait_left -= delta
	if wait_left > 0.0:
		return
	if line_index >= line_rows.size():
		_show_total()
		return
	line_rows[line_index].show()
	if line_player.stream != null:
		line_player.play()
	line_index += 1
	wait_left = step_delay


func _show_total() -> void:
	phase = Phase.DONE
	_label(total_row, "Key").text = "%s :" % tr("VICTORY_TOTAL_SCORE")
	_label(total_row, "Value").text = str(StatsManager.run_score)
	total_row.show()
	if total_player.stream != null:
		total_player.play()
	ok_button.show()
	ok_button.grab_focus()


# ---------------- DISPLAY ----------------

func _build_lines(lines : Array[Dictionary]) -> void:
	for line : Dictionary in lines:
		var row : HBoxContainer = stat_template.duplicate() as HBoxContainer
		stats_list.add_child(row)
		_label(row, "Key").text = "%s :" % tr(line["key"])
		_label(row, "Value").text = line["value"]
		row.hide()  # revealed one by one
		line_rows.append(row)


func _label(row : HBoxContainer, label_name : String) -> Label:
	return row.get_node(label_name) as Label
