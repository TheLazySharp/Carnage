extends Resource

class_name DollarData

enum Rarities {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
}


@export var item_name: String
@export var icon: Texture2D
@export var value: int
@export var rarity : Rarities
