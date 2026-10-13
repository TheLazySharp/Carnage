extends Node
class_name TutorialManager
## Phase 1: maneuver steps (each one N times). Then message pages (combo, dash, zombies)
## and phase 2: free play against hordes, with a weapon on every maneuver.
## No save. Start = quit confirmation

@export var steps: Array[TutorialStepData] = []
@export var step_transition_delay: float = 1.5

@export_group("Pages")
## One key per page: the key is the title, key + "_BODY" is the text
@export var intro_page_keys: PackedStringArray = ["TUTO_INTRO_MANEUVERS", "TUTO_INTRO_BLOOD"]
@export var phase2_page_keys: PackedStringArray = ["TUTO_PHASE2_COMBO", "TUTO_PHASE2_DASH", "TUTO_PHASE2_ZOMBIES"]

@export_group("Phase 2")
@export var horde_spawner: Spawner        # inactive in the scene: spawned once when phase 2 starts
@export var tutorial_weapon: WeaponData   # placed on every maneuver in phase 2

@export_group("HUD")
@export var title_label: Label
@export var hint_label: Label
@export var counter_label: Label
@export var skip_label: Label

@export_group("Quit popup")
@export var quit_popup: Control
@export var yes_button: Button
@export var no_button: Button
@export var pause_menu: Control  # optional: the regular pause menu, hidden when Start is pressed in the tutorial

@export_group("Page popup")
@export var page_popup: Control
@export var page_title: Label
@export var page_body: Label
@export var page_next_button: Button

var step_index: int = 0
var progress: int = 0
var transition_left: float = 0.0  # > 0 while "step done" is displayed
var leaving: bool = false
var game_paused: bool = false

var page_open: bool = false
var page_keys: PackedStringArray = []
var page_index: int = 0
var page_done: Callable          # called when the last page is closed

var free_play: bool = false
var frags_at_start: int = 0
var shown_kills: int = -1


func _ready() -> void:
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.game_paused.connect(_on_game_paused)
	skip_label.text = tr("TUTO_SKIP")
	yes_button.text = tr("TUTO_YES")
	no_button.text = tr("TUTO_NO")
	yes_button.pressed.connect(_on_quit_yes_pressed)
	no_button.pressed.connect(_on_quit_no_pressed)
	page_next_button.pressed.connect(_on_page_next_pressed)
	quit_popup.hide()
	page_popup.hide()
	set_process(false)
	set_physics_process(false)
	# Deferred: the car sets its CarData in its own _ready()
	_begin.call_deferred()


## Entry point from the main menu: prepares what a run usually prepares, then loads the tutorial
static func launch(tutorial_car: CarData) -> void:
	SceneManager.unload_game()
	GameMaster.tutorial_active = true
	WeaponsManager.load_weapons()  # phase 2 equips a weapon
	CarManager.selected_car = tutorial_car
	tutorial_car.init_stats()
	# A driver is required (blood, dash): the first known survivor, without equipping his weapon
	SurvivorsManager.select_survivor(SurvivorsManager.known_survivors[0])
	SceneManager.load_level(SceneManager.SCENES.TUTORIAL)


func _begin() -> void:
	_setup_car()
	if steps.is_empty():
		push_warning("[Tutorial] no step configured")
		return
	# The game principles first, then the first step
	_open_pages(intro_page_keys, _start_step.bind(0))


func _setup_car() -> void:
	var car: Node = get_tree().get_first_node_in_group("player")
	if car == null:
		push_warning("[Tutorial] no car in the 'player' group")
		return
	# No death in the tutorial: no damage taken, and the driver keeps a drop of blood
	car.player.invincible = true
	car.bloody_engine.can_die = false
	LoadoutManager.start_run(car.player)
	# Every maneuver is available in the tutorial: nothing LOCKED
	for maneuver_type: ManeuverManager.Type in ManeuverManager.Type.values():
		LoadoutManager.unlock(maneuver_type)


# ---------------- PHASE 1: STEPS ----------------

func _process(delta: float) -> void:
	if game_paused:
		return
	transition_left -= delta
	if transition_left > 0.0:
		return
	set_process(false)
	if step_index + 1 < steps.size():
		_start_step(step_index + 1)
	else:
		# Phase 1 done: combo, dash and zombies pages, then free play
		_open_pages(phase2_page_keys, _start_free_play)


func _start_step(index: int) -> void:
	step_index = index
	progress = 0
	var step: TutorialStepData = steps[step_index]
	title_label.text = tr(step.title_key)
	hint_label.text = tr(step.hint_key)
	_update_counter()


func _update_counter() -> void:
	counter_label.text = "%d / %d" % [progress, steps[step_index].required_count]


func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, _intensity: float, _drift_level: int, _is_amplified: bool, _attack_angle: float) -> void:
	# Other maneuvers still show their popup, only the target one counts
	if _is_counting() and maneuver_type == steps[step_index].maneuver_type:
		_add_progress()


func _is_counting() -> bool:
	return !leaving and !free_play and !page_open and transition_left <= 0.0 and step_index < steps.size()


func _add_progress() -> void:
	var required: int = steps[step_index].required_count
	progress = mini(progress + 1, required)
	_update_counter()
	if progress >= required:
		title_label.text = tr("TUTO_STEP_DONE")
		transition_left = step_transition_delay
		set_process(true)


# ---------------- PHASE 2: FREE PLAY ----------------

func _start_free_play() -> void:
	free_play = true
	title_label.text = tr("TUTO_FREE_PLAY")
	hint_label.text = tr("TUTO_FREE_PLAY_HINT")
	frags_at_start = StatsManager.frags
	shown_kills = -1
	_equip_tutorial_weapon()
	_spawn_hordes()
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if game_paused:
		return
	# Kill counter, refreshed only when it changes
	var kills: int = StatsManager.frags - frags_at_start
	if kills != shown_kills:
		shown_kills = kills
		counter_label.text = "%s %d" % [tr("TUTO_KILLS"), kills]


func _equip_tutorial_weapon() -> void:
	if tutorial_weapon == null:
		push_warning("[Tutorial] no tutorial_weapon set")
		return
	WeaponsManager.equip_weapon(tutorial_weapon)  # ignored if already equipped
	LoadoutManager.assign_everywhere(tutorial_weapon)


func _spawn_hordes() -> void:
	if horde_spawner == null:
		push_warning("[Tutorial] no horde_spawner set")
		return
	horde_spawner.is_active = true
	horde_spawner.setup_trigger()


# ---------------- PAGES ----------------

func _open_pages(keys: PackedStringArray, on_done: Callable) -> void:
	if keys.is_empty():
		on_done.call()
		return
	page_keys = keys
	page_index = 0
	page_done = on_done
	page_open = true
	# The game stays frozen while the player reads
	SignalManager.game_paused.emit(true)
	_show_page()
	page_popup.show()
	page_next_button.grab_focus()


func _show_page() -> void:
	var key: String = page_keys[page_index]
	page_title.text = tr(key)
	page_body.text = tr(key + "_BODY")
	var is_last_page: bool = page_index == page_keys.size() - 1
	page_next_button.text = tr("TUTO_INTRO_START") if is_last_page else tr("TUTO_INTRO_NEXT")


func _on_page_next_pressed() -> void:
	page_index += 1
	if page_index < page_keys.size():
		_show_page()
		return
	page_popup.hide()
	page_open = false
	SignalManager.game_paused.emit(false)
	page_done.call()


# ---------------- QUIT ----------------

func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause
	# The pages pause the game themselves: not a Start press
	if leaving or page_open:
		return
	if game_on_pause:
		# Deferred: the pause owner shows its menu (and grabs focus) after emitting the signal
		_show_quit_popup.call_deferred()
	else:
		quit_popup.hide()


## Start in the tutorial: a quit confirmation instead of the regular pause menu
func _show_quit_popup() -> void:
	if !game_paused or leaving:
		return
	if pause_menu != null:
		pause_menu.hide()
	quit_popup.show()
	no_button.grab_focus()  # safest default: staying


func _on_quit_yes_pressed() -> void:
	quit_popup.hide()
	_leave()


func _on_quit_no_pressed() -> void:
	quit_popup.hide()
	# Unpausing = emitting game_paused(false), like the rest of the game
	SignalManager.game_paused.emit(false)


func _leave() -> void:
	if leaving:
		return
	leaving = true
	# unload_game() also resets GameMaster.tutorial_active
	SceneManager.unload_game()
	SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)
