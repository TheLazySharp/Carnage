class_name  Bullet
extends Area2D

@export var arrow_data: WeaponData

var speed
var max_range
var damages
var current_lvl
var max_lvl
@onready var trail: CPUParticles2D = $VFX

var velocity : Vector2
var start_position : Vector2

@onready var bow: Node2D = $/root/World/BeaverSr/Weapons/Bow

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:= false

var is_active:= false

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	speed = arrow_data.speed
	max_range = arrow_data.atk_range
	max_lvl = arrow_data.max_level

func _process(_delta: float) -> void:
	pass
	
	


func fire(from_position: Vector2, direction: Vector2, angle: float) -> void:
	self.activate()
	#self.show()
	#set_physics_process(true)
	#is_active = true
	start_position = from_position
	global_position = start_position
	trail.global_position = global_position
	velocity = direction.normalized() * speed
	trail.restart()
	trail.show()
	rotation = angle


func _physics_process(delta: float) -> void:
	if not game_paused:
		var next_position = global_position + velocity * delta
		global_position = next_position
		#if self.global_position.y <= (self.start_position.y - 50) :
			#trail.global_position = global_position
			##print("y ; ",global_position.y, " / start y : ", str(start_position.y - 50))
			#trail.show()
		
	
	if start_position.distance_to(global_position) > max_range:
		if not game_paused:
			trail.emit_signal("finished")
			desactivate()


func _on_area_hit(_area: Area2D) -> void:
	pass
	#trail.emit_signal("finished")
	#hitbox.set_deferred("disabled", true)
	#reset_bullet()


func _on_body_hit(body: Node2D) -> void:
	if "get_damages" in body and body.is_in_group("ennemies") and is_active and body.visible:
		current_lvl = clampi(arrow_data.current_level,0,max_lvl)
		damages = arrow_data.dmg + (current_lvl * .1 * 28) #améliorer la formule d'augmentation des dégats
		body.get_damages(damages)
		trail.emit_signal("finished")
		desactivate()
		#else : print("damagaes bug : ", damages)
	else:
		trail.emit_signal("finished")
		desactivate()

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause


func desactivate()-> void:
	hide()
	is_active = false
	set_process(false)
	set_physics_process(false)
	global_position = Vector2(-10,-10)
	if bow: bow.add_bullet_to_pool(self)



func activate()->void:
	if !is_active:
		is_active = true
		visible = true
		set_process(true)
		set_physics_process(true)
