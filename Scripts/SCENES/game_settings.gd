extends Node

@onready var language_option: OptionButton = %LanguageOption

func _ready() -> void:
	for language_index: int in range(GameSettings.LANGUAGE_NAMES.size()):
		language_option.add_item(GameSettings.LANGUAGE_NAMES[language_index], language_index)
	language_option.select(GameSettings.language)
	language_option.item_selected.connect(_on_language_selected)

func _on_language_selected(language_index: int) -> void:
	GameSettings.set_language(language_index)
