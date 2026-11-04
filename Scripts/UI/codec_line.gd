extends Control
class_name RescueCodec


const JUICE = preload("uid://dbohpdgym7v6q")
const GENERIC_LINES : Array[String] = ["RESCUE_LINE_1", "RESCUE_LINE_2", "RESCUE_LINE_3", "RESCUE_LINE_4"]

@export var portrait : TextureRect
@export var name_label : Label
@export var line_label : Label
@export var rescue_sfx : AudioStreamPlayer

var hide_at : float = 0.0  # real time (seconds)


func _ready() -> void:
	hide()
	set_process(false)
	SignalManager.survivor_rescued.connect(_on_survivor_rescued)


func _process(_delta : float) -> void:
	if Time.get_ticks_msec() / 1000.0 >= hide_at:
		hide()
		set_process(false)


func _on_survivor_rescued(survivor : SurvivorData) -> void:
	portrait.texture = survivor.icon
	name_label.text = survivor.name
	var lines : Array[String] = GENERIC_LINES if survivor.rescue_lines.is_empty() else survivor.rescue_lines
	line_label.text = tr(lines.pick_random())
	if rescue_sfx != null:
		rescue_sfx.play()
	show()
	hide_at = Time.get_ticks_msec() / 1000.0 + JUICE.rescue_codec_time
	set_process(true)
	JuiceManager.hit_stop(JUICE.rescue_slowmo_duration, JUICE.rescue_slowmo_time_scale)
