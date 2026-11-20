extends Control
## Launch splash: every child of %Cards fades in, holds, then fades out, in tree order.
## Same fade as the biome title card. ui_accept skips the current card.

@export var fade_in_time : float = 0.6
@export var hold_time : float = 1.6
@export var fade_out_time : float = 0.6
## Black pause between two cards
@export var gap_time : float = 0.2

@onready var cards_root : Control = %Cards

var cards : Array[CanvasItem] = []
var card_index : int = -1
var card_tween : Tween = null
var leaving : bool = false


func _ready() -> void:
	# Only the cards fade: the black background stays, no flash of the clear color
	for child : Node in cards_root.get_children():
		var card : CanvasItem = child as CanvasItem
		if card != null:
			card.modulate.a = 0.0
			cards.append(card)
	_next_card()


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_next_card()


func _next_card() -> void:
	if leaving:
		return
	if card_tween != null and card_tween.is_valid():
		card_tween.kill()  # skipped: its finished signal never fires
	if card_index >= 0:
		cards[card_index].modulate.a = 0.0  # a skipped card disappears at once
	card_index += 1
	if card_index >= cards.size():
		_go_to_menu()
		return
	var card : CanvasItem = cards[card_index]
	card_tween = create_tween()
	card_tween.tween_property(card, "modulate:a", 1.0, fade_in_time)
	card_tween.tween_interval(hold_time)
	card_tween.tween_property(card, "modulate:a", 0.0, fade_out_time)
	card_tween.tween_interval(gap_time)
	card_tween.finished.connect(_next_card)


func _go_to_menu() -> void:
	leaving = true
	SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)
