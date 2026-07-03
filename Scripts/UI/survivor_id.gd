extends Button

var i : int
var survivor : SurvivorData
@onready var survivor_name: Label = $PNJName
@onready var portrait: TextureRect = $Portrait
var button_hovered: bool = false
@onready var select: Button = $"../../../VBoxContainer/Select"


func _ready() -> void:
	i = int(self.name)
	if i < SurvivorsManager.known_survivors.size():
		survivor = SurvivorsManager.known_survivors[i]
		survivor_name.text = survivor.name
		portrait.texture = survivor.icon
	else : 
		self.hide()


func _process(_delta: float) -> void:
	if !self.button_hovered and has_focus():
		button_hovered = true
		SurvivorsManager.emit_signal("portrait_hovered",i)
	if button_hovered and !has_focus():
		button_hovered = false


func _on_pressed() -> void:
	select.grab_focus()
