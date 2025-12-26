extends Panel

#@export var item_manager: Node
var items: Array
var item: ItemData
@onready var icon: TextureRect = $Icon

var slot_name:=""
var i: int

signal dropped_item(item_dropped : ItemData)

@onready var selection_mask: ColorRect = $SelectionMask
@onready var no_item_mask: ColorRect = $NoItemMask

@onready var selection_wheel: Control = $"/root/World/CanvasLayer/SelectionWheel"
var selection:int = -1


func _ready() -> void:
	selection_mask.hide()
	selection_wheel.item_selected.connect(update_selection)
	update_UI()
	slot_name = self.name
	i = slot_name.to_int()
	items = InventoryManager.copy_items()
	if i<= items.size() -1:
		item = items[i]

func _process(_delta: float) -> void:
	if item:
		if selection == i and item.quantity == 0:
			icon.modulate = Color(modulate,0.5)
			selection_mask.hide()
			if Input.is_action_just_released("drop_item"):
				no_item_mask.show()
				await get_tree().create_timer(0.5).timeout
				no_item_mask.hide()
		else: icon.modulate = Color(modulate,1)
	if selection == i and item.quantity > 0:
		selection_mask.show()
	else: 
		selection_mask.hide()
		
	
		
func update_UI() -> void:
	if not item:
		icon.texture = null
		return
	icon.texture = item.icon
	tooltip_text = item.item_name

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null or item.quantity == 0:
		return
	
	var preview = duplicate()
	var c = Control.new()
	c.add_child(preview)
	preview.position -= Vector2(16,16) #half of the tile size
	preview.self_modulate = Color.TRANSPARENT
	c.modulate = Color(c.modulate,0.5)
	
	set_drag_preview(c)
	#icon.hide() transparent if quantity = 0
	emit_signal("dropped_item", item)
	return self

func update_selection(item_selected) -> void:
	selection = item_selected
	#print("icon received i : ",selection)
	

#=========== FOR MOVING ITEM INSIDE THE INVENTORY ==============================

#func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	#if item_quantity > 0:
		#return true
	#else: return false
	#
#func _drop_data(_at_position: Vector2, data: Variant) -> void:
	#var tmp = item 
	#item = data.item
	#data.item = tmp
	#icon.show()
	#data.show()
	#update_UI()
	#data.update_UI()
	#print("item dropped into inventory")
