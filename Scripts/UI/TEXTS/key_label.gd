@tool
class_name KeyLabel
extends Label
# Label whose text is a translation key picked from the TextKeys registry





@export var text_key: StringName = &"":
	set(value):
		text_key = value
		text = text_key
		update_configuration_warnings()

@export var font_type: FontManager.types = FontManager.types.TEXT

func _ready() -> void:
	# FontManager is an autoload: it only exists at runtime, not in the editor
	if Engine.is_editor_hint():
		return
	apply_font_type(font_type)

func apply_font_type(new_type: FontManager.types) -> void:
	font_type = new_type
	var font_settings: Array = FontManager.FONTS.get(new_type, [])
	# DEFAUT has no entry: keep the theme's default style
	if font_settings.is_empty():
		return
	add_theme_font_override("font", font_settings[0])
	add_theme_font_size_override("font_size", font_settings[1])
	add_theme_color_override("font_color", font_settings[2])

	if new_type == FontManager.types.UX or new_type == FontManager.types.UX_M \
			or new_type == FontManager.types.UX_S or new_type == FontManager.types.UX_XS:
		add_theme_constant_override("outline_size", FontManager.UX_outline)
		add_theme_color_override("font_outline_color", FontManager.UX_color)

func _validate_property(property: Dictionary) -> void:
	if property.name == "text_key":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = TextKeys.KEY_LIST

func _get_configuration_warnings() -> PackedStringArray:
	if text_key.is_empty() or TextKeys.KEY_LIST.split(",").has(String(text_key)):
		return PackedStringArray()
	return PackedStringArray(["Unknown text key: " + text_key])
