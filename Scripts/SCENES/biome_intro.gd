extends Control
## Biome title card, shown once per biome right before its roadmap.
## Same scene for every biome: the name comes from the current BiomeData.
## Skippable with ui_accept.

@export var fade_in_time : float = 0.6
@export var hold_time : float = 1.6
@export var fade_out_time : float = 0.6

@onready var biome_name_label : Label = %BiomeName

var _tween : Tween = null
var _leaving : bool = false


func _ready() -> void:
	BiomesManager.intro_pending = false
	var key : String = BiomesManager.current_data.display_name_key if BiomesManager.current_data != null else ""
	biome_name_label.text = tr(key)
	# Only the title fades: the black background stays, no flash of the clear color
	biome_name_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(biome_name_label, "modulate:a", 1.0, fade_in_time)
	_tween.tween_interval(hold_time)
	_tween.tween_property(biome_name_label, "modulate:a", 0.0, fade_out_time)
	_tween.finished.connect(_go_to_roadmap)


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_go_to_roadmap()


func _go_to_roadmap() -> void:
	if _leaving:
		return
	_leaving = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	SceneManager.load_level(SceneManager.SCENES.ROADMAP)
