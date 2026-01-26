extends Area2D

@export var axe_data : WeaponData

var speed_rotation : float
var speed : float
var d := 0.0
var radius : float
var offset_position: Vector2
var dmg : int
var dmg_on_resources : int
var current_lvl : int
var max_lvl: int

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:= false

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	speed_rotation = axe_data.speed_rotation
	speed = axe_data.speed
	radius = axe_data.radius
	dmg_on_resources = axe_data.dmg_on_resources
	max_lvl = axe_data.max_level

func _process(_delta: float) -> void:
	current_lvl = clampi(axe_data.current_level,0,max_lvl)
	dmg = roundi(axe_data.dmg + (current_lvl * .1 * 45)) #améliorer la formule d'augmentation des dégats

func _physics_process(delta: float) -> void:
	offset_position = get_parent().global_position
	rotation += speed_rotation * delta
	d += delta
	if !game_paused:
		global_position = Vector2(sin(d * speed) * radius, cos(d * speed) * radius) + offset_position


func _on_body_entered(body: Node2D) -> void:
		if body.is_in_group("ennemies") and "get_damages" in body:
			body.get_damages(dmg)
		else : return

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("ressources") and "take_damages" in area.get_parent():
		print("ressources hit")
		area.get_parent().take_damages(dmg_on_resources)
	else : return
