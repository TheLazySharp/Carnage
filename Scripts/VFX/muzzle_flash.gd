extends Node2D
class_name MuzzleFlashVFX

@onready var muzzle_animation: AnimatedSprite2D = $MuzzleAnimation
@onready var flash_particles: CPUParticles2D = $MuzzleAnimation/FlashParticles

var animation_finished : bool = false
var particles_finished : bool = false
var animation_names : PackedStringArray = []


func _ready() -> void:
	# Every animation of the SpriteFrames is a variant (MuzzleFlash01..04)
	animation_names = muzzle_animation.sprite_frames.get_animation_names()
	deactivate()


func activate(from_pos : Vector2, angle : float) -> void : 
	global_position = from_pos
	global_rotation = angle
	animation_finished = false
	particles_finished = false
	show()
	muzzle_animation.stop()
	muzzle_animation.play(animation_names[randi() % animation_names.size()])
	flash_particles.restart()


func deactivate() -> void : 
	hide()
	muzzle_animation.stop()
	flash_particles.emitting = false


func _on_flash_particles_finished() -> void:
	particles_finished = true
	if animation_finished:
		deactivate()


func _on_muzzle_animation_animation_finished() -> void:
	animation_finished = true
	if particles_finished:
		deactivate()
