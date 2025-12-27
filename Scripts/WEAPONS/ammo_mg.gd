class_name  AmmoMG
extends Area2D

@export var bullet_data: WeaponData

var speed
var max_range
var damages
var current_lvl
var max_lvl
#@onready var trail: CPUParticles2D = $VFX

var velocity : Vector2
var start_position : Vector2

@onready var parent_weapon: Node2D = $/root/World/Car/Weapons/Minigun

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:= false

var is_active:= false

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	speed = bullet_data.speed
	max_range = bullet_data.atk_range
	max_lvl = bullet_data.max_level

func _process(_delta: float) -> void:
	current_lvl = clampi(bullet_data.current_level,0,max_lvl)
	damages = bullet_data.dmg + (current_lvl * .1 * 28) #améliorer la formule d'augmentation des dégats
	


func fire(from_position: Vector2, direction: Vector2, angle: float) -> void:
	global_position = from_position
	start_position = from_position
	#if trail: trail.global_position = global_position
	velocity = direction.normalized() * speed
	self.show()
	is_active = true
	set_physics_process(true)
	#if trail:
		#trail.restart()
		#trail.show()
	rotation = angle
	#print("stone shot")


func _physics_process(delta: float) -> void:
	if not game_paused:
		var next_position = global_position + velocity * delta
		global_position = next_position
		
	
	if abs(self.global_position - start_position).length() > max_range:
		if not game_paused:
			#if trail: trail.emit_signal("finished")
			desactivate()


func _on_area_hit(_area: Area2D) -> void:
	pass
	#trail.emit_signal("finished")
	#hitbox.set_deferred("disabled", true)
	#reset_bullet()


func _on_body_hit(body: Node2D) -> void:
	if "get_damages" in body and body.is_in_group("ennemies") and is_active:
		body.get_damages(damages)
		#if trail: trail.emit_signal("finished")
		desactivate()
	else:
		#if trail: trail.emit_signal("finished")
		desactivate()

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause


func desactivate()-> void:
	hide()
	is_active = false
	set_process(false)
	set_physics_process(false)
	global_position = Vector2(-10,-10)
	if parent_weapon: parent_weapon.add_bullet_to_pool(self)



func activate()->void:
	if !is_active:
		is_active = true
		visible = true
		set_process(true)
		set_physics_process(true)
