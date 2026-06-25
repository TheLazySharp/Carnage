extends Label

# --- POSITION ---
@export var bubble_offset : Vector2 = Vector2(0, -48)
@export var bob_amplitude : float = 6.0
@export var bob_duration : float = 0.6

# --- GONFLEMENT ---
@export var pulse_scale : float = 1.15
@export var pulse_duration : float = 0.45

var base_position : Vector2
var idle_tween : Tween = null

func _ready() -> void:
	text = "Save me !"
	pivot_offset = size * 0.5
	base_position = bubble_offset
	position = base_position
	start_idle()

func start_idle() -> void:
	if idle_tween:
		idle_tween.kill()
	idle_tween = create_tween().set_loops()
	idle_tween.set_parallel(true)

	# GONFLE -> DEGONFLE
	idle_tween.tween_property(self, "scale", Vector2.ONE * pulse_scale, pulse_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.chain().tween_property(self, "scale", Vector2.ONE, pulse_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# BOBBING vertical (en parallèle de la respiration)
	idle_tween.tween_property(self, "position:y", base_position.y - bob_amplitude, bob_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.chain().tween_property(self, "position:y", base_position.y, bob_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
