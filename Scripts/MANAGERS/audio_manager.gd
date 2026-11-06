extends Node

var current_biome: String
#var music_volume: int
var sfx_volume: int
var game_paused:=false

@export_group("XP PICKUP")
@export var xp_player : AudioStreamPlayer     # stream = XP pickup sound, same bus as the other sfx
@export var xp_min_interval : float = 0.06    # seconds: pickups closer than this share one sound
@export var xp_chain_window : float = 0.4     # a pickup within this delay continues the chain (pitch goes up)
@export var xp_pitch_step : float = 0.04
@export var xp_max_pitch : float = 1.6

var xp_last_sound_ms : int = -100000
var xp_chain_pitch : float = 1.0

@onready var level_up_sfx_player: AudioStreamPlayer = $LevelUpSfx
@onready var items_sfx: AudioStreamPlayer = $ItemsSfx
@onready var items_sfx2: AudioStreamPlayer = $ItemsSfx2
@onready var items_sfx3: AudioStreamPlayer = $ItemsSfx3
@onready var coins_sfx: AudioStreamPlayer = $CoinsSfx

@onready var background_music_player: AudioStreamPlayer = $BackgroundMusicPlayer


var sfx_players : Array[AudioStreamPlayer]

var pickup_xp_sfx : AudioStreamMP3
var pickup_gears_sfx : AudioStreamMP3
var level_up_sfx : AudioStreamMP3
var buy_sfx : AudioStreamMP3


func _ready() -> void:
	sfx_players = [items_sfx,items_sfx2,items_sfx3]
	SignalManager.game_paused.connect(_on_game_paused)
	XPManager.xp_collected.connect(_on_xp_collected)
	XPManager.level_up_sfx.connect(_on_level_up)
	SignalManager.piston_picked_up.connect(_on_gears_picked_up)
	SignalManager.dollar_picked_up.connect(_on_dollar_picked_up)
	SignalManager.start_background_music.connect(_on_map_async_generation)
	pickup_xp_sfx = AudioMaster.PICK_UP_XP
	pickup_gears_sfx = AudioMaster.PICK_UP_GEARS
	level_up_sfx = AudioMaster.LEVEL_UP_ARCADE
	buy_sfx = AudioMaster.CASH_REGISTER

	level_up_sfx_player.stream = level_up_sfx

func play_sfx(sfx : AudioStreamMP3) -> void:
	if game_paused:
		return
	for player in sfx_players:
		if !player.playing:
			player.stream = sfx
			player.play()
			return

## One sound per burst of pickups, its pitch rising while the pickups keep coming
func _on_xp_collected() -> void:
	var now_ms : int = Time.get_ticks_msec()
	var elapsed : float = (now_ms - xp_last_sound_ms) / 1000.0
	if elapsed < xp_min_interval:
		return
	# Chain: higher pitch at each sound; after a pause, back to normal
	if elapsed < xp_chain_window:
		xp_chain_pitch = minf(xp_chain_pitch + xp_pitch_step, xp_max_pitch)
	else:
		xp_chain_pitch = 1.0
	xp_last_sound_ms = now_ms
	xp_player.pitch_scale = xp_chain_pitch
	xp_player.play()

func _on_gears_picked_up() -> void:
	play_sfx(pickup_gears_sfx)

func _on_dollar_picked_up() -> void:
	coins_sfx.play()

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	
func _on_level_up() -> void : 
	level_up_sfx_player.play()
	#print("levelup sound")

func _on_map_async_generation() -> void : 
	background_music_player.play()
