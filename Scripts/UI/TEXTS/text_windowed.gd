class_name TextWindow
extends Control
# Modal text window: a KeyLabel message and a KeyButton to close, keys chosen per game event

@onready var message_label: KeyLabel = $CenterContainer/WindowBkg/Label
@onready var close_button: KeyButton = $CenterContainer/WindowBkg/Button

# Messages waiting while the window is already open (same index in both arrays)
var pending_message_keys: Array[StringName] = []
var pending_button_keys: Array[StringName] = []
# Messages flagged show_once already displayed this session
var shown_once_keys: Dictionary[StringName, bool] = {}
var current_message_key: StringName = &""


func _ready() -> void:
	# Must keep working while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	close_button.pressed.connect(_on_close_pressed)
	
	
	# --- Game events that open the window: one connection per event ---
	SignalManager.lap_completed.connect(_on_lap_completed)
	SignalManager.loading_screen_closed.connect(_on_race_start)


# Queues a message; shows it right away if the window is free
func open(message_key: StringName, button_key: StringName, show_once: bool = false) -> void:
	if show_once:
		if shown_once_keys.has(message_key):
			return
		shown_once_keys[message_key] = true
	pending_message_keys.append(message_key)
	pending_button_keys.append(button_key)
	if visible:
		return
	SignalManager.emit_signal("game_paused",true)
	_show_next()

func _show_next() -> void:
	current_message_key = pending_message_keys.pop_front()
	message_label.text_key = current_message_key
	close_button.text_key = pending_button_keys.pop_front()
	show()
	# Gamepad navigation (Steam Deck)
	close_button.grab_focus()

func _on_close_pressed() -> void:
	SignalManager.text_window_closed.emit(current_message_key)
	if not pending_message_keys.is_empty():
		_show_next()
		return
	hide()
	SignalManager.emit_signal("game_paused",false)


# --- Event handlers: pick the keys for each event here ---

func _on_lap_completed(_lap_count: int) -> void:
	pass
	#if lap_count == 1:
		#open(TextKeys.WINDOW_FIRST_LAP, TextKeys.UI_CONTINUE, true)

func _on_race_start() -> void : 
	open(TextKeys.CAR_VOICE_WELCOME_0, TextKeys.BUTTON_CONTINUE,false)
	open(TextKeys.CAR_VOICE_WELCOME_1, TextKeys.BUTTON_CONTINUE,false)
	open(TextKeys.CAR_VOICE_WELCOME_2, TextKeys.BUTTON_CONTINUE,false)
	open(TextKeys.CAR_VOICE_WELCOME_3, TextKeys.BUTTON_CONTINUE,false)
	open(TextKeys.CAR_VOICE_WELCOME_4, TextKeys.BUTTON_CONTINUE,false)
	open(TextKeys.CAR_VOICE_WELCOME_5, TextKeys.BUTTON_CONTINUE,false)
	open(TextKeys.CAR_VOICE_WELCOME_6, TextKeys.BUTTON_WTF,false)
	
