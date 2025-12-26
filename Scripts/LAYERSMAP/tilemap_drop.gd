extends TileMapLayer

@onready var player: RigidBody2D = $"/root/World/Car"

@onready var drop_item_to_world: Control = $/root/World/CanvasLayer/DropItemToWorld
@onready var main_layer : TileMapLayer = $"/root/World/Land_layers/Main"

#@export var item_manager: Node
var items: Array
var item: ItemData

@onready var selection_wheel: Control = $"/root/World/CanvasLayer/SelectionWheel"
var selection:int = -1


func _ready() -> void:
	items = InventoryManager.copy_items()
	selection_wheel.item_selected.connect(update_selection)
	item = items[selection]
	
func _physics_process(_delta: float) -> void:
	item = items[selection]
	drop_item()
	#------------ WORKING UPDATE OF THE NAVLAYER ON TILEMAP --------------------##
	
	
	#if Input.is_action_just_released("drop_item") and item.quantity > 0 and selection >= 0:
		#print("begin drop on item : ",selection)
		#var tile_on_map = local_to_map(player.global_position + Vector2(0,-32))
		#var tile_z_index = get_cell_tile_data(tile_on_map).get_z_index()
		#if tile_z_index == 100:
			#set_cell(tile_on_map,item.tileset_ID,item.tile_atlas_pos)
			#main_layer.notify_runtime_tile_data_update()
			#item.quantity -=1
		#else : return
	

func drop_item()-> void:
	if Input.is_action_just_released("drop_item") and item.quantity > 0 and selection >= 0:
		var obstacle := item.item_scene.instantiate()
		obstacle.global_position = player.global_position + Vector2(0,-32)
		get_node("/root/World/ItemsOnMap").add_child(obstacle)
		item.quantity -=1



func update_selection(item_selected) -> void:
	selection = item_selected
	print("tilemap received i : ",selection)
