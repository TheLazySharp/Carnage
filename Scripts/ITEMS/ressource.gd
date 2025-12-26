extends CharacterBody2D

@export var farmable: FarmableData
@export var loot: ItemData

@onready var gm_scene: Node = $"/root/World/game_manager"

var game_paused:=false

var max_life: int
var current_life: int

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	max_life = farmable.life
	current_life = max_life

func _process(_delta: float) -> void:
	if current_life < 0:
		current_life = 0
		loot.quantity += farmable.loot_quantity
		#changer de sprite --> en mettre un daans le farmable data
		queue_free()

func take_damages(damages: int) -> void:
	if not game_paused:
		current_life -=damages
		print("tree life = ", current_life)
		#VFX

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
