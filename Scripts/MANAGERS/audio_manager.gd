extends Node

var current_biome: String
#var music_volume: int
var sfx_volume: int
var game_paused:=false



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
	XPManager.update_xp.connect(_on_update_xp)
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

func _on_update_xp(_xp : int) -> void:
	play_sfx(pickup_xp_sfx)

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
