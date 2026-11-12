extends Control
## End of raid score screen: score lines shown one by one (odometer style), then the total fills the
## speedometer: needle from left to right, a full sweep = one level gained (gear change), and so on.
## Data from StatsManager.get_raid_score() and XPManager.add_raid_xp(). Every sfx is optional

enum Phase { LINES, TOTAL, NEEDLE, DONE }

@export_group("SFX (optional)")
@export var quantity_sfx : AudioStream
@export var score_sfx : AudioStream
@export var total_sfx : AudioStream
@export var speedometer_sfx : AudioStream

@export_group("TIMING")
@export var step_delay : float = 0.25         # min seconds between two displays (the only wait without sfx)
@export var needle_fill_speed : float = 0.6   # share of a level per second
@export var gear_change_pause : float = 0.25  # needle held at the left after a level up
@export var needle_drop_speed : float = 3.0   # share of a level per second when the needle falls back (gear change)

@export_group("SPEEDOMETER")
@export var needle_min_degrees : float = -120.0  # 0 % of a level
@export var needle_max_degrees : float = 120.0   # 100 % of a level

@onready var stat_template : HBoxContainer = $Stats/EndGameStats/Stat
@onready var total_row : HBoxContainer = $Stats/EndGameStats/Total
@onready var needle : Control = $Speedometer/Needle
@onready var level_nb: Label = $Speedometer/VBoxContainer/Levels/LevelNb
@onready var ok_button : Button = $VBoxContainer/Ok
@onready var upgrades_nb: Label = $Speedometer/VBoxContainer/Upgrades/UpgradesNb

var score : Dictionary = {}
var segments : Array[Dictionary] = []
var line_rows : Array[HBoxContainer] = []
var phase : Phase = Phase.LINES
var upgrades : int = 0

# ---- Lines ----
var line_index : int = 0
var line_step : int = 0                          # 0 = quantity to show, 1 = score to show
var wait_left : float = 0.0
var waiting_player : AudioStreamPlayer = null    # a step is done once this sound ended and wait_left is over

# ---- Needle ----
var segment_index : int = 0
var needle_ratio : float = 0.0
var consumed_xp : float = 0.0                    # XP of the segments already swept

var quantity_player : AudioStreamPlayer
var score_player : AudioStreamPlayer
var total_player : AudioStreamPlayer
var speedometer_player : AudioStreamPlayer
var needle_dropping : bool = false

func _ready() -> void:
	BloodBars.hide()
	stat_template.hide()
	ok_button.disabled = true
	quantity_player = _make_player(quantity_sfx)
	score_player = _make_player(score_sfx)
	total_player = _make_player(total_sfx)
	speedometer_player = _make_player(speedometer_sfx)
	upgrades = 0
	upgrades_nb.text = str(upgrades)

	score = StatsManager.get_raid_score()
	segments = XPManager.add_raid_xp(score["total"])

	_build_lines()
	_reset_total_row()
	needle_ratio = segments[0]["from"]
	_set_needle(needle_ratio)
	level_nb.text = str(segments[0]["level"])


func _make_player(stream : AudioStream) -> AudioStreamPlayer:
	var player : AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	return player


# ---------------- INPUT ----------------

func _input(event : InputEvent) -> void:
	if phase == Phase.LINES and event.is_action_pressed("ui_accept"):
		_skip_line()
		get_viewport().set_input_as_handled()


func _on_ok_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.CAR_LEVELUP)


# ---------------- SEQUENCE ----------------

func _process(delta : float) -> void:
	wait_left -= delta
	match phase:
		Phase.LINES:
			_process_lines()
		Phase.TOTAL:
			if _step_done():
				phase = Phase.NEEDLE
		Phase.NEEDLE:
			_process_needle(delta)


func _step_done() -> bool:
	return wait_left <= 0.0 and (waiting_player == null or !waiting_player.playing)


func _start_step(player : AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()
	waiting_player = player
	wait_left = step_delay


func _process_lines() -> void:
	if !_step_done():
		return
	if line_index >= line_rows.size():
		_show_total()
		return
	var row : HBoxContainer = line_rows[line_index]
	var line : Dictionary = score["lines"][line_index]
	if line_step == 0:
		_label(row, "Quantity").text = str(line["count"])
		_start_step(quantity_player)
		line_step = 1
	else:
		_label(row, "Score").text = str(line["subtotal"])
		_start_step(score_player)
		line_step = 0
		line_index += 1


func _skip_line() -> void:
	if line_index >= line_rows.size():
		return
	quantity_player.stop()
	score_player.stop()
	var row : HBoxContainer = line_rows[line_index]
	var line : Dictionary = score["lines"][line_index]
	_label(row, "Quantity").text = str(line["count"])
	_label(row, "Score").text = str(line["subtotal"])
	line_index += 1
	line_step = 0
	waiting_player = null
	wait_left = 0.0


func _show_total() -> void:
	phase = Phase.TOTAL
	var multiplier : float = score["combo_multiplier"] * score["extra_multiplier"]
	# subtotal x multiplier = total, only when there is a multiplier
	var has_multiplier : bool = !is_equal_approx(multiplier, 1.0)
	for label_name : String in ["Quantity", "Multiply", "Points", "Equal"]:
		_label(total_row, label_name).modulate.a = 1.0 if has_multiplier else 0.0
	_label(total_row, "Quantity").text = str(score["subtotal"])
	_label(total_row, "Points").text = String.num(multiplier, 2)
	_label(total_row, "Score").text = str(score["total"])
	_start_step(total_player)



func _process_needle(delta : float) -> void:
	if needle_dropping:
		needle_ratio = maxf(needle_ratio - needle_drop_speed * delta, 0.0)
		_set_needle(needle_ratio)
		if needle_ratio <= 0.0:
			needle_dropping = false
			wait_left = gear_change_pause
		return
	if wait_left > 0.0:
		return  # gear change pause
	var segment : Dictionary = segments[segment_index]
	var level_xp : float = XPManager.xp_levels[segment["level"]]
	needle_ratio = minf(needle_ratio + needle_fill_speed * delta, segment["to"])
	_set_needle(needle_ratio)
	_set_total_left(score["total"] - consumed_xp - (needle_ratio - segment["from"]) * level_xp)
	if speedometer_player.stream != null and !speedometer_player.playing:
		speedometer_player.play()
	if needle_ratio < segment["to"]:
		return
	consumed_xp += (segment["to"] - segment["from"]) * level_xp
	segment_index += 1
	if segment["level_up"]:
		level_nb.text = str(segment["level"] + 1)
		upgrades += 1
		upgrades_nb.text = str(upgrades)
		# The needle falls back to the left before the next level
		needle_dropping = true
		return
	if segment_index >= segments.size():
		_finish()


func _finish() -> void:
	phase = Phase.DONE
	speedometer_player.stop()
	_set_total_left(0.0)
	ok_button.disabled = false
	ok_button.grab_focus()
	GuideManager.play(&"score", [
		{"text": "GUIDE_SCORE_LEVELS", "target": $Speedometer},
	])

# ---------------- DISPLAY ----------------

func _build_lines() -> void:
	var rows_parent : Node = stat_template.get_parent()
	var lines : Array = score["lines"]
	for i : int in lines.size():
		var line : Dictionary = lines[i]
		var row : HBoxContainer = stat_template.duplicate() as HBoxContainer
		rows_parent.add_child(row)
		rows_parent.move_child(row, stat_template.get_index() + 1 + i)
		row.show()
		_label(row, "Key").text = "%s :" % tr(line["key"])
		_label(row, "Points").text = str(line["points"])
		_label(row, "Quantity").text = ""
		_label(row, "Score").text = ""
		line_rows.append(row)


func _reset_total_row() -> void:
	_label(total_row, "Key").text = "%s :" % tr("SCORE_TOTAL")
	for label_name : String in ["Quantity", "Multiply", "Points", "Equal"]:
		_label(total_row, label_name).modulate.a = 0.0
	_label(total_row, "Score").text = ""


func _set_total_left(xp_left : float) -> void:
	_label(total_row, "Score").text = str(maxi(roundi(xp_left), 0))


func _set_needle(ratio : float) -> void:
	needle.rotation_degrees = lerpf(needle_min_degrees, needle_max_degrees, ratio)


func _label(row : HBoxContainer, label_name : String) -> Label:
	return row.get_node(label_name) as Label
