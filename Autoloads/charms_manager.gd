extends Node

var active_charms: Dictionary = {}
var holder : Array[CharmData] = []
var sfx_player : AudioStreamPlayer

func register(charm: CharmData, effect: CharmEffect) -> void:
	active_charms[charm] = effect
	holder.append(charm)

func deactivate_all() -> void:
	for effect : CharmEffect in active_charms.values():
		effect.deactivate()
	active_charms.clear()
	
func unload() -> void : 
	for effect : CharmEffect in active_charms.values():
		effect.deactivate()
	active_charms.clear()
	holder.clear()

func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	SignalManager.charm_triggered.connect(_on_charm_triggered)


func get_charm(ref : int) -> CharmData:
	for charm : CharmData in holder:
		if charm.ref == ref:
			return charm
	return null

func has_charm(charm : CharmData) -> bool:
	return holder.has(charm)

func _on_charm_triggered(ref : int) -> void:
	var charm : CharmData = get_charm(ref)
	if charm == null:
		return
	if charm.trigger_sfx != null:
		sfx_player.stream = charm.trigger_sfx
		sfx_player.play()
	_play_trigger_visual(charm)

## Visual feedback when a charm triggers: to be done later
func _play_trigger_visual(_charm : CharmData) -> void:
	pass
