extends TextureRect


var items: Array

var item: ItemData

var icon_name:=""
var i: int

func _ready() -> void:
	icon_name = get_parent().name
	i = icon_name.to_int()
	items = InventoryManager.copy_items()
	#print("icon : ",i)
	if i <= items.size() -1:
		item = items[i]
	if item:
		#print("icone type : ",item.item_name)
		self.texture = item.icon
	

func _draw():
	if item:
		draw_texture_rect(item.icon,Rect2(position+ Vector2((32-item.icon.get_size().x) * .5, (32-item.icon.get_size().y) * .5),item.icon.get_size()),false)
