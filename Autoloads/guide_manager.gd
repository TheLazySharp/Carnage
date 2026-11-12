extends Node


const SEQUENCE_IDS : Array[StringName] = [&"loadout", &"score", &"car_levelup", &"shop", &"rescue"]
## GuidePanel scene, loaded at runtime
const PANEL_UID : String = "uid://dhtar4ojgk64y"

var first_game : bool = true
var seen : Array[StringName] = []
var panel : GuidePanel = null
var queue : Array[Array] = []
var was_paused : bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(id : StringName, steps : Array[Dictionary]) -> void:
	if !first_game or seen.has(id) or steps.is_empty():
		return
	if GameMaster.tutorial_active or LoadoutManager.sandbox_active:
		return
	seen.append(id)
	if panel != null and panel.visible:
		queue.append(steps)
		return
	if panel == null:
		panel = (load(PANEL_UID) as PackedScene).instantiate() as GuidePanel
		add_child(panel)
		panel.sequence_finished.connect(_on_sequence_finished)
	was_paused = get_tree().paused
	get_tree().paused = true
	panel.show_sequence(steps)

func _on_sequence_finished() -> void:
	if !queue.is_empty():
		var next_steps : Array[Dictionary] = []
		next_steps.assign(queue.pop_front())
		panel.show_sequence(next_steps)
		return
	get_tree().paused = was_paused
	if seen.size() >= SEQUENCE_IDS.size():
		first_game = false
