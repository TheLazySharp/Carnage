extends Node


var active_charms: Dictionary = {}           # equipped CharmData -> its CharmEffect
var holder : Array[CharmData] = []            # equipped charms
var owned : Array[CharmData] = []             # every charm bought (inventory)
var sfx_player : AudioStreamPlayer

# ----- charm Values ------
var charm_skull_life_floor : float = 0.0
var charm_skull_dmg_boost : float = 0.2

func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	SignalManager.charm_triggered.connect(_on_charm_triggered)


func buy(charm: CharmData) -> void:
	if owned.has(charm):
		return
	owned.append(charm)
	equip(charm)


func equip(charm: CharmData) -> bool:
	if holder.has(charm) or is_full():
		return false
	var effect : CharmEffect = charm.effect_script.new()
	effect.activate(charm)
	register(charm, effect)
	return true


func unequip(charm: CharmData) -> void:
	var effect : CharmEffect = active_charms.get(charm) as CharmEffect
	if effect != null:
		effect.deactivate()
	active_charms.erase(charm)
	holder.erase(charm)


func register(charm: CharmData, effect: CharmEffect) -> void:
	active_charms[charm] = effect
	holder.append(charm)


func get_slot_count() -> int:
	return roundi(CarManager.selected_car.charm_slots.get_value())


func is_full() -> bool:
	return holder.size() >= get_slot_count()


func has_charm(charm : CharmData) -> bool:
	return owned.has(charm)


func is_equipped(charm : CharmData) -> bool:
	return holder.has(charm)


func get_charm(ref : int) -> CharmData:
	for charm : CharmData in holder:
		if charm.ref == ref:
			return charm
	return null

## Loadout swap: 'new_charm' (inventory) takes the exact slot of 'old_charm' (null = empty slot)
func swap(old_charm: CharmData, new_charm: CharmData) -> void:
	var slot_index : int = holder.find(old_charm) if old_charm != null else holder.size()
	if old_charm != null:
		unequip(old_charm)
	if equip(new_charm):
		# equip() appends: move it back to the slot it replaces
		holder.erase(new_charm)
		holder.insert(mini(slot_index, holder.size()), new_charm)

func deactivate_all() -> void:
	for effect : CharmEffect in active_charms.values():
		effect.deactivate()
	active_charms.clear()


func unload() -> void : 
	for effect : CharmEffect in active_charms.values():
		effect.deactivate()
	active_charms.clear()
	holder.clear()
	owned.clear()

func _on_charm_triggered(ref : int) -> void:
	var charm : CharmData = get_charm(ref)
	if charm == null:
		return
	if charm.trigger_sfx != null:
		sfx_player.stream = charm.trigger_sfx
		sfx_player.play()
	_play_trigger_visual(charm)

## Slots lowered (job lost...): the last equipped charms go back to the inventory
func fit_to_slots() -> void:
	while holder.size() > get_slot_count():
		unequip(holder.back())

func _play_trigger_visual(_charm : CharmData) -> void:
	pass
